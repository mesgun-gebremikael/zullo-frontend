import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'account_session.dart';
import 'auth_storage.dart';
import 'api_config.dart';
import 'session_http_client.dart';

class DraftException implements Exception {
  final String message;
  final String? code;
  final List<String>? validPhotos;
  const DraftException(this.message, {this.code, this.validPhotos});
  @override
  String toString() => message;
}

class DraftSnapshot {
  final int revision, step;
  final Map<String, dynamic> data;
  final bool photosExpired;
  const DraftSnapshot(this.revision, this.step, this.data,
      {this.photosExpired = false});
  factory DraftSnapshot.fromJson(Map<String, dynamic> value) => DraftSnapshot(
      (value['revision'] as num).toInt(),
      (value['step'] as num).toInt(),
      Map<String, dynamic>.from(value['data'] as Map),
      photosExpired: value['photosExpired'] == true);
}

/// Private, account-scoped encrypted outbox. Kept on logout for safe resume;
/// explicitly removed after profile completion or accepted account erasure.
class DraftCache {
  final FlutterSecureStorage storage;
  DraftCache({FlutterSecureStorage? storage})
      : storage = storage ??
            const FlutterSecureStorage(
                aOptions: AndroidOptions(encryptedSharedPreferences: true),
                iOptions: IOSOptions(
                    accessibility:
                        KeychainAccessibility.first_unlock_this_device));
  static final Map<String, Future<void>> _queues = {};
  Future<T> _serial<T>(String user, Future<T> Function() action) {
    final operation =
        (_queues[user] ?? Future<void>.value()).then((_) => action());
    final tail = operation.then<void>((_) {}, onError: (Object _) {});
    _queues[user] = tail;
    tail.whenComplete(() {
      if (identical(_queues[user], tail)) _queues.remove(user);
    });
    return operation;
  }

  Future<Map<String, dynamic>?> read(String user) => _serial(user, () async {
        final raw = await storage.read(key: 'onboarding_v1_$user');
        if (raw == null) return null;
        final value = jsonDecode(raw);
        if (value is! Map ||
            value['data'] is! Map ||
            value['step'] is! int ||
            value['revision'] is! int) {
          throw const FormatException('Invalid cached draft');
        }
        return Map<String, dynamic>.from(value);
      });
  Future<void> write(String user, Map<String, dynamic> value) => _serial(
      user,
      () =>
          storage.write(key: 'onboarding_v1_$user', value: jsonEncode(value)));
  Future<void> clear(String user) =>
      _serial(user, () => storage.delete(key: 'onboarding_v1_$user'));
}

class OnboardingDraftService {
  final AuthStorage storage;
  final DraftCache cache;
  final int generation;
  late final http.Client _client;
  final bool _ownsTransport;
  OnboardingDraftService(
      {http.Client? client, AuthStorage? storage, DraftCache? cache})
      : cache = cache ?? DraftCache(),
        storage = storage ?? AuthStorage(),
        generation = AccountSession.generation,
        _ownsTransport = client == null {
    _client = SessionHttpClient(client ?? http.Client(),
        generation: () => generation);
  }
  Future<Map<String, String>> _headers() async {
    AccountSession.check(generation);
    final token = await storage.getToken();
    AccountSession.check(generation);
    if (token == null || token.isEmpty) {
      throw const DraftException('Logga in igen.');
    }
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json'
    };
  }

  Uri get _url => Uri.parse('${ApiConfig.baseUrl}/me/onboarding');
  DraftSnapshot _parse(http.Response response) {
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const DraftException('Inloggningen har gått ut. Logga in igen.',
          code: 'session_expired');
    }
    if (response.statusCode == 200) {
      return DraftSnapshot.fromJson(
          Map<String, dynamic>.from(jsonDecode(response.body) as Map));
    }
    Map<String, dynamic> body = {};
    try {
      body = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    } catch (_) {/* generic error */}
    throw DraftException(
        body['message']?.toString() ??
            'Kunde inte spara profilutkastet. Dina val finns kvar på den här enheten.',
        code: body['code']?.toString(),
        validPhotos: body['validPhotoUrls'] is List
            ? (body['validPhotoUrls'] as List).whereType<String>().toList()
            : null);
  }

  Future<DraftSnapshot?> load() async {
    final response = await _client
        .get(_url, headers: await _headers())
        .timeout(const Duration(seconds: 20));
    return response.statusCode == 404 ? null : _parse(response);
  }

  Future<DraftSnapshot> save(
          int revision, int step, Map<String, dynamic> data) async =>
      _parse(await _client
          .put(_url,
              headers: await _headers(),
              body: jsonEncode(
                  {'revision': revision, 'step': step, 'data': data}))
          .timeout(const Duration(seconds: 20)));
  void close() {
    if (_ownsTransport) _client.close();
  }
}
