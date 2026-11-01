import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:purchases_flutter/purchases_flutter.dart';
import 'account_session.dart';
import 'api_config.dart';
import 'auth_storage.dart';
import 'session_http_client.dart';

class CommerceState {
  final bool checkoutEnabled, premium, hideActivity, incognito;
  final int superLikes, boosts;
  final DateTime? boostUntil, premiumUntil;
  const CommerceState(
      {this.checkoutEnabled = false,
      this.premium = false,
      this.hideActivity = false,
      this.incognito = false,
      this.superLikes = 0,
      this.boosts = 0,
      this.boostUntil,
      this.premiumUntil});
  factory CommerceState.fromJson(Map<String, dynamic> json) => CommerceState(
        checkoutEnabled: json['checkoutEnabled'] == true,
        premium: json['premium'] == true,
        hideActivity: json['hideActivity'] == true,
        incognito: json['incognito'] == true,
        superLikes: (json['superLikes'] as num?)?.toInt() ?? 0,
        boosts: (json['boosts'] as num?)?.toInt() ?? 0,
        boostUntil: DateTime.tryParse(json['boostUntilUtc']?.toString() ?? ''),
        premiumUntil:
            DateTime.tryParse(json['premiumUntilUtc']?.toString() ?? ''),
      );
}

class CommerceException implements Exception {
  final int status;
  final String message;
  const CommerceException(this.status, this.message);
  @override
  String toString() => message;
}

class CommerceClient {
  final int _generation = AccountSession.generation;
  final AuthStorage _storage;
  late final http.Client _client;
  static final http.Client _shared = http.Client();
  CommerceClient({http.Client? client, AuthStorage? storage})
      : _storage = storage ?? AuthStorage() {
    _client =
        SessionHttpClient(client ?? _shared, generation: () => _generation);
  }
  Future<Map<String, dynamic>> request(String method, String path,
      [Object? body]) async {
    AccountSession.check(_generation);
    final token = await _storage.getToken();
    AccountSession.check(_generation);
    final req = http.Request(method, Uri.parse('${ApiConfig.baseUrl}$path'));
    req.headers.addAll(
        {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'});
    if (body != null) req.body = jsonEncode(body);
    final response = await _client
        .send(req)
        .then(http.Response.fromStream)
        .timeout(const Duration(seconds: 20));
    AccountSession.check(_generation);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = 'Kunde inte uppdatera. Försök igen.';
      try {
        message = (jsonDecode(response.body)['message'] ?? message).toString();
      } catch (_) {}
      throw CommerceException(response.statusCode, message);
    }
    return response.body.isEmpty
        ? {}
        : Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  Future<CommerceState> state() async =>
      CommerceState.fromJson(await request('GET', '/commerce/state'));
  Future<CommerceState> sync() async =>
      CommerceState.fromJson(await request('POST', '/commerce/sync'));
  Future<CommerceState> boost() async =>
      CommerceState.fromJson(await request('POST', '/commerce/boost'));
  Future<CommerceState> privacy(
          {required bool hideActivity, required bool incognito}) async =>
      CommerceState.fromJson(await request('PATCH', '/commerce/privacy',
          {'hideActivity': hideActivity, 'incognito': incognito}));
  Future<void> heartbeat() async {
    await request('POST', '/presence');
  }

  Future<void> rewind() async {
    await request('POST', '/swipe/rewind');
  }
}

class StoreOffer {
  final String id, title, price;
  final Object handle;
  const StoreOffer(this.id, this.title, this.price, this.handle);
}

abstract class NativeBilling {
  bool get available;
  Future<List<StoreOffer>> offers(String userId);
  Future<void> buy(StoreOffer offer, String userId);
  Future<void> restore(String userId);
}

class RevenueCatBilling implements NativeBilling {
  static const termsUrl = String.fromEnvironment('ZULLO_TERMS_URL');
  static const privacyUrl = String.fromEnvironment('ZULLO_PRIVACY_URL');
  String get _key => defaultTargetPlatform == TargetPlatform.iOS
      ? const String.fromEnvironment('REVENUECAT_IOS_PUBLIC_KEY')
      : const String.fromEnvironment('REVENUECAT_ANDROID_PUBLIC_KEY');
  @override
  bool get available =>
      !kIsWeb &&
      [TargetPlatform.iOS, TargetPlatform.android]
          .contains(defaultTargetPlatform) &&
      _key.isNotEmpty &&
      Uri.tryParse(termsUrl)?.scheme == 'https' &&
      Uri.tryParse(privacyUrl)?.scheme == 'https';
  static Future<void> _identityQueue = Future.value();
  Future<void> _prepare(String userId) {
    final generation = AccountSession.generation;
    final operation = _identityQueue.then((_) async {
      AccountSession.check(generation);
      if (!available || userId.isEmpty) {
        throw StateError('Köp är inte tillgängliga just nu.');
      }
      if (!await Purchases.isConfigured) {
        await Purchases.configure(
            PurchasesConfiguration(_key)..appUserID = userId);
      } else if (await Purchases.appUserID != userId) {
        await Purchases.logIn(userId);
      }
      AccountSession.check(generation);
    });
    _identityQueue = operation.catchError((Object _) {});
    return operation;
  }

  @override
  Future<List<StoreOffer>> offers(String userId) async {
    await _prepare(userId);
    final offering = (await Purchases.getOfferings()).current;
    return (offering?.availablePackages ?? [])
        .where((p) => const {
              'zullo_premium_monthly',
              'zullo_superlikes_5',
              'zullo_boost_1',
              'zullo_boosts_5'
            }.contains(p.storeProduct.identifier.split(':').first))
        .map((p) => StoreOffer(
              p.storeProduct.identifier.split(':').first,
              p.storeProduct.title,
              p.storeProduct.priceString,
              p,
            ))
        .toList();
  }

  @override
  Future<void> buy(StoreOffer offer, String userId) async {
    final generation = AccountSession.generation;
    await _prepare(userId);
    AccountSession.check(generation);
    await Purchases.purchasePackage(offer.handle as Package);
    AccountSession.check(generation);
  }

  @override
  Future<void> restore(String userId) async {
    final generation = AccountSession.generation;
    await _prepare(userId);
    await Purchases.restorePurchases();
    AccountSession.check(generation);
  }
}

class CommerceEvents {
  static final _events = StreamController<void>.broadcast();
  static final _walletEvents = StreamController<void>.broadcast();
  static final _openDiscovery = StreamController<void>.broadcast();
  static Stream<void> get openDiscoveryStream => _openDiscovery.stream;
  static void openDiscovery() { _openDiscovery.add(null); refreshDiscovery(); }
  static Stream<void> get stream => _events.stream;
  static Stream<void> get walletStream => _walletEvents.stream;
  static void walletChanged() => _walletEvents.add(null);
  static void refreshDiscovery() {
    _events.add(null);
    walletChanged();
  }
}

class PresenceText {
  static String format(DateTime? last, {DateTime? now}) {
    if (last == null) return '';
    final elapsed = (now ?? DateTime.now()).toUtc().difference(last.toUtc());
    if (elapsed.inSeconds < 90) return 'Online nu';
    if (elapsed.inMinutes < 60) {
      return 'Senast aktiv för ${elapsed.inMinutes} ${elapsed.inMinutes == 1 ? 'minut' : 'minuter'} sedan';
    }
    if (elapsed.inHours < 24) {
      return 'Senast aktiv för ${elapsed.inHours} ${elapsed.inHours == 1 ? 'timme' : 'timmar'} sedan';
    }
    return 'Senast aktiv för ${elapsed.inDays} ${elapsed.inDays == 1 ? 'dag' : 'dagar'} sedan';
  }
}
