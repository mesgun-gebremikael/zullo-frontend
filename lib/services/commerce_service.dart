import 'pending_store_purchase.dart';
export 'pending_store_purchase.dart' show StorePurchase;
import 'billing_operation_queue.dart';
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
  final bool checkoutEnabled;
  final bool _premium, _activityPrivacy, hideActivity, incognito;
  bool get premium =>
      _premium &&
      (premiumUntil == null || premiumUntil!.isAfter(DateTime.now()));
  bool get activityPrivacy =>
      _activityPrivacy &&
      (activityPrivacyUntil == null ||
          activityPrivacyUntil!.isAfter(DateTime.now()));
  bool get canHideActivity => premium || activityPrivacy;
  final int _superLikes, _boosts;
  final int? includedSuperLikes,
      purchasedSuperLikes,
      includedBoosts,
      purchasedBoosts;
  int get superLikes => purchasedSuperLikes == null
      ? _superLikes
      : purchasedSuperLikes! + (premium ? includedSuperLikes ?? 0 : 0);
  int get boosts => purchasedBoosts == null
      ? _boosts
      : purchasedBoosts! + (premium ? includedBoosts ?? 0 : 0);
  final DateTime? boostUntil,
      premiumUntil,
      activityPrivacyUntil,
      nextSuperLikeRefresh,
      nextBoostRefresh;
  bool get boostActive => boostUntil?.isAfter(DateTime.now()) == true;
  String get boostRemaining {
    final remaining = boostUntil?.difference(DateTime.now()).inSeconds ?? 0;
    if (remaining <= 0) return '';
    return '${remaining ~/ 60}:${(remaining % 60).toString().padLeft(2, '0')}';
  }

  const CommerceState(
      {this.checkoutEnabled = false,
      bool premium = false,
      bool activityPrivacy = false,
      this.activityPrivacyUntil,
      this.hideActivity = false,
      this.incognito = false,
      int superLikes = 0,
      int boosts = 0,
      this.boostUntil,
      this.premiumUntil,
      this.includedSuperLikes,
      this.purchasedSuperLikes,
      this.includedBoosts,
      this.purchasedBoosts,
      this.nextSuperLikeRefresh,
      this.nextBoostRefresh})
      : _premium = premium,
        _activityPrivacy = activityPrivacy,
        _superLikes = superLikes,
        _boosts = boosts;
  factory CommerceState.fromJson(Map<String, dynamic> json) => CommerceState(
        checkoutEnabled: json['checkoutEnabled'] == true,
        premium: json['premium'] == true,
        activityPrivacy: (json['canHideActivity'] == true &&
                json['premium'] != true) ||
            DateTime.tryParse(json['activityPrivacyUntilUtc']?.toString() ?? '')
                    ?.isAfter(DateTime.now()) ==
                true,
        activityPrivacyUntil: DateTime.tryParse(
            json['activityPrivacyUntilUtc']?.toString() ?? ''),
        hideActivity: json['hideActivity'] == true,
        incognito: json['incognito'] == true,
        superLikes: (json['superLikes'] as num?)?.toInt() ?? 0,
        boosts: (json['boosts'] as num?)?.toInt() ?? 0,
        includedSuperLikes: (json['includedSuperLikes'] as num?)?.toInt(),
        purchasedSuperLikes: (json['purchasedSuperLikes'] as num?)?.toInt(),
        includedBoosts: (json['includedBoosts'] as num?)?.toInt(),
        purchasedBoosts: (json['purchasedBoosts'] as num?)?.toInt(),
        nextSuperLikeRefresh: DateTime.tryParse(
            json['nextSuperLikeRefreshUtc']?.toString() ?? ''),
        nextBoostRefresh:
            DateTime.tryParse(json['nextBoostRefreshUtc']?.toString() ?? ''),
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
  Future<({bool verified, bool refunded})> purchaseStatus(
      StorePurchase receipt) async {
    final body = await request('POST', '/commerce/purchase-status', {
      'store': receipt.store,
      'transactionId': receipt.transactionId,
      'productId': receipt.productId,
      'identifierKind': receipt.identifierKind
    });
    return (
      verified: body['verified'] == true,
      refunded: body['refunded'] == true
    );
  }

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

/// The adapter proves that the native purchase API was never invoked.
/// This must never describe an uncertain result after a store sheet opened.
class CheckoutNotStartedException implements Exception {
  final Object cause;
  const CheckoutNotStartedException(this.cause);
}

abstract class NativeBilling {
  bool get available;
  Future<List<StoreOffer>> offers(String userId);
  Future<StorePurchase> buy(StoreOffer offer, String userId);
  Future<List<StorePurchase>> recentPurchases(String userId) async => [];
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
      _key.startsWith(
          defaultTargetPlatform == TargetPlatform.iOS ? 'appl_' : 'goog_') &&
      _https(termsUrl) &&
      _https(privacyUrl);
  static bool _https(String value) {
    final uri = Uri.tryParse(value);
    return uri?.scheme == 'https' && uri!.host.isNotEmpty;
  }

  static final _operations = BillingOperationQueue();
  Future<void> _prepare(String userId) async {
    if (!available || userId.isEmpty) {
      throw StateError('Köp är inte tillgängliga just nu.');
    }
    if (!await Purchases.isConfigured) {
      await Purchases.configure(
          PurchasesConfiguration(_key)..appUserID = userId);
    } else if (await Purchases.appUserID != userId) {
      await Purchases.logIn(userId);
    }
  }

  static String? canonicalProduct(String identifier, String? period) {
    final product = identifier.split(':').first;
    if (product == 'zullo_premium') {
      return switch (period) {
        'P1M' => 'zullo_premium_monthly',
        'P1Y' => 'zullo_premium_annual',
        _ => null
      };
    }
    if (product == 'zullo_premium_monthly' && period == 'P1M') {
      return product;
    }
    if (product == 'zullo_premium_annual' && period == 'P1Y') {
      return product;
    }
    if (const {'zullo_superlikes_5', 'zullo_boost_1', 'zullo_boosts_5'}
            .contains(product) &&
        (period == null || period.isEmpty)) {
      return product;
    }
    return null;
  }

  @override
  Future<List<StoreOffer>> offers(String userId) => _operations.run(() async {
        final offering = (await Purchases.getOfferings()).current;
        return (offering?.availablePackages ?? [])
            .where((p) =>
                canonicalProduct(p.storeProduct.identifier,
                    p.storeProduct.subscriptionPeriod) !=
                null)
            .map((p) => StoreOffer(
                canonicalProduct(p.storeProduct.identifier,
                    p.storeProduct.subscriptionPeriod)!,
                p.storeProduct.title,
                p.storeProduct.priceString,
                p))
            .toList();
      }, prepare: () => _prepare(userId));

  @override
  Future<StorePurchase> buy(StoreOffer offer, String userId) async {
    var nativeInvoked = false;
    try {
      return await _operations.run(() async {
        final params = PurchaseParams.package(offer.handle as Package);
        nativeInvoked = true;
        final result = await Purchases.purchase(params);
        return StorePurchase(
            defaultTargetPlatform == TargetPlatform.iOS
                ? 'app_store'
                : 'play_store',
            result.storeTransaction.transactionIdentifier,
            offer.id,
            purchaseDate:
                DateTime.tryParse(result.storeTransaction.purchaseDate));
      },
          prepare: () => _prepare(userId),
          // The paywall persists this receipt to the original account's guard
          // before rejecting the obsolete session. Never discard known proof.
          preserveResultOnSessionChange: true);
    } catch (error, stack) {
      if (!nativeInvoked) {
        Error.throwWithStackTrace(CheckoutNotStartedException(error), stack);
      }
      rethrow;
    }
  }

  @override
  Future<List<StorePurchase>> recentPurchases(String userId) =>
      _operations.run(() async {
        final customer = await Purchases.getCustomerInfo();
        return customer.nonSubscriptionTransactions
            .map((transaction) => historyReceipt(transaction,
                store: defaultTargetPlatform == TargetPlatform.iOS
                    ? 'app_store'
                    : 'play_store'))
            .toList();
      }, prepare: () => _prepare(userId));

  /// CustomerInfo history reuses StoreTransaction's Dart shape, but its identity
  /// is RevenueCat's ID. It must never enter the store-receipt namespace.
  static StorePurchase historyReceipt(StoreTransaction transaction,
          {required String store}) =>
      StorePurchase(store, transaction.transactionIdentifier,
          transaction.productIdentifier.split(':').first,
          purchaseDate: DateTime.tryParse(transaction.purchaseDate),
          identifierKind: 'revenuecat');

  @override
  Future<void> restore(String userId) => _operations.run(() async {
        await Purchases.restorePurchases();
      }, prepare: () => _prepare(userId));
}

class CommerceEvents {
  static final _events = StreamController<void>.broadcast();
  static final _walletEvents = StreamController<void>.broadcast();
  static final _openDiscovery = StreamController<void>.broadcast();
  static Stream<void> get openDiscoveryStream => _openDiscovery.stream;
  static void openDiscovery() {
    _openDiscovery.add(null);
    refreshDiscovery();
  }

  static Stream<void> get stream => _events.stream;
  static Stream<void> get walletStream => _walletEvents.stream;
  static void walletChanged() => _walletEvents.add(null);
  static void refreshDiscovery() {
    _events.add(null);
    walletChanged();
  }
}
