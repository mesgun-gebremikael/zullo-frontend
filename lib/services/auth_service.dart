import 'api_config.dart';
import 'push_token_service.dart';
import 'matches_cache_service.dart';
import '../onboarding/onboarding_data.dart';
import 'dart:async';
import 'account_session.dart';
import 'session_http_client.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_storage.dart';
import '../models/swipe_profile.dart';

class ProfileSessionExpiredException implements Exception {
  @override
  String toString() => 'Din session har gått ut. Logga in igen.';
}

class AuthRateLimitException implements Exception {
  final int retryAfterSeconds;
  AuthRateLimitException(this.retryAfterSeconds);

  @override
  String toString() =>
      'För många försök. Vänta $retryAfterSeconds sekunder och försök igen.';
}

class AuthRequestException implements Exception {
  final String message;
  AuthRequestException(this.message);
  @override
  String toString() => message;
}

class AuthService {
  static final String baseApiUrl = ApiConfig.baseUrl;
  static final String baseAuthUrl = '$baseApiUrl/api/auth';

  final AuthStorage _storage = AuthStorage();
  static final http.Client _sharedTransport = http.Client();
  final http.Client _transport;
  int _generation = AccountSession.generation;
  late final http.Client _client =
      SessionHttpClient(_transport, generation: () => _generation);
  final Future<String?> Function() _pushTokenLoader;
  AuthService(
      {http.Client? client, Future<String?> Function()? pushTokenLoader})
      : _transport = client ?? _sharedTransport,
        _pushTokenLoader = pushTokenLoader ?? PushTokenService.currentToken;

  Future<void> _acceptAuth(http.Response response) async {
    final decoded = jsonDecode(response.body);
    final token = (decoded['token'] ?? '').toString();
    final userId = (decoded['userId'] ?? '').toString();
    if (token.isEmpty || userId.isEmpty) {
      throw StateError('Authentication response is missing token or userId');
    }
    await _storage.saveAuth(token: token, userId: userId);
    _generation = AccountSession.generation;
    unawaited(syncPushToken());
  }

  /// Best effort after both sign-in paths and resume. Never delays navigation.
  Future<void> syncPushToken() async {
    final generation = _generation;
    try {
      AccountSession.check(generation);
      final token =
          await _pushTokenLoader().timeout(const Duration(seconds: 5));
      AccountSession.check(generation);
      if (token != null && token.isNotEmpty) {
        await saveDeviceToken(token).timeout(const Duration(seconds: 5));
      }
    } catch (_) {
      // Token refresh and app resume retry without blocking authentication.
    }
  }

  void _checkRateLimit(http.Response response) {
    if (response.statusCode == 429) {
      final seconds = int.tryParse(response.headers['retry-after'] ?? '') ?? 60;
      throw AuthRateLimitException(seconds.clamp(1, 3600).toInt());
    }
  }

  // ---------- AUTH ----------

  Future<void> login({
    required String email,
    required String password,
  }) async {
    final generation = AccountSession.generation;
    final url = Uri.parse('$baseAuthUrl/login');

    final response = await _transport
        .post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'password': password}),
        )
        .timeout(const Duration(seconds: 90));

    AccountSession.check(generation);
    _checkRateLimit(response);
    if (response.statusCode == 200) {
      await _acceptAuth(response);

      return;
    }

    throw Exception('Login failed: ${response.statusCode} ${response.body}');
  }

  Future<void> registerAndLogin(
      {required String name,
      required String email,
      required String password}) async {
    final response =
        await _register(name: name, email: email, password: password);
    await _acceptAuth(response);
  }

  Future<void> register(
      {required String name,
      required String email,
      required String password}) async {
    await _register(name: name, email: email, password: password);
  }

  Future<http.Response> _register({
    required String name,
    required String email,
    required String password,
  }) async {
    final url = Uri.parse('$baseAuthUrl/register');

    final response = await _client
        .post(
          url,
          headers: {'Content-Type': 'application/json'},
          body:
              jsonEncode({'name': name, 'email': email, 'password': password}),
        )
        .timeout(const Duration(seconds: 90));

    _checkRateLimit(response);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return response;
    }

    if (response.statusCode == 400 &&
        response.body.contains('User already exists')) {
      throw AuthRequestException(
          'E-postadressen används redan. Logga in i stället.');
    }
    throw AuthRequestException('Kunde inte skapa kontot. Försök igen senare.');
  }

  Future<void> logout() async {
    AccountSession.check(_generation);
    final generation = AccountSession.generation;
    final authToken = await _storage.getToken();
    AccountSession.check(generation);
    // Invalidate local work before waiting for the network. Only the old JWT is used.
    await _storage.clearAuth();
    if (authToken != null && authToken.isNotEmpty) {
      unawaited(_clearDeviceToken(authToken));
    }
  }

  Future<void> _clearDeviceToken(String oldToken) async {
    try {
      await _transport.post(
        Uri.parse('$baseApiUrl/me/device-token/clear'),
        headers: {'Authorization': 'Bearer $oldToken'},
      ).timeout(const Duration(seconds: 5));
    } catch (_) {
      // Local logout remains complete even when offline.
    }
  }

  // ---------- PROFILE CHECK ----------

  Future<bool> hasProfile() async {
    final token = await _storage.getToken();

    final res = await _client.get(
      Uri.parse('$baseApiUrl/me/profile'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (res.statusCode == 200) return true;
    if (res.statusCode == 404) return false;
    if (res.statusCode == 401) throw ProfileSessionExpiredException();
    throw Exception('Kunde inte kontrollera profilen. Försök igen.');
  }

  Future<Map<String, dynamic>> getMyProfile() async {
  final token = await _storage.getToken();

  final res = await _client.get(
    Uri.parse('$baseApiUrl/me/profile'),
    headers: {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    },
  );


  if (res.statusCode == 200) {
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    return decoded;
  }

  throw Exception('Get my profile failed: ${res.statusCode} ${res.body}');
}

  // ---------- SWIPE FEED ----------

Future<Map<String, dynamic>> getSwipeFeed({
  int minAge = 18,
  int maxAge = 99,
}) async {
  final token = await _storage.getToken();

  final response = await _client.get(
    Uri.parse(
      '$baseApiUrl/swipe/feed?minAge=$minAge&maxAge=$maxAge',
    ),
    headers: {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    },
  );

  if (response.statusCode == 200) {
    final decoded = jsonDecode(response.body);

    final radiusKm = (decoded['radiusKm'] ?? 50) as num;

    final List profilesJson = (decoded['profiles'] ?? []) as List;

    final profiles = profilesJson
        .map((j) => SwipeProfile.fromJson(j))
        .toList();

    return {
      'radiusKm': radiusKm.toDouble(),
      'profiles': profiles,
    };
  }

  if (response.statusCode == 204) {
    return {
      'radiusKm': 50.0,
      'profiles': <SwipeProfile>[],
    };
  }

  throw Exception(
      'Failed to load swipe feed: ${response.statusCode} ${response.body}');
}

  // ---------- LIKE / SKIP ----------

  Future<bool> like(String targetUserId) async {
    final token = await _storage.getToken();

    final res = await _client.post(
      Uri.parse('$baseApiUrl/swipe/like'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'targetUserId': targetUserId}),
    );

   if (res.statusCode == 200) {
  final decoded = jsonDecode(res.body);
  return decoded['matched'] == true;
}

if (res.statusCode == 429) {
  final decoded = jsonDecode(res.body);
  throw Exception(decoded['message'] ?? 'Like limit reached');
}

throw Exception('Like failed: ${res.statusCode} ${res.body}');
  }

  Future<void> skip(String targetUserId) async {
    final token = await _storage.getToken();

    final res = await _client.post(
      Uri.parse('$baseApiUrl/swipe/skip'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'targetUserId': targetUserId}),
    );

    if (res.statusCode != 200) {
      throw Exception('Skip failed: ${res.statusCode} ${res.body}');
    }
  }

  // ---------- MATCHES ----------

  Future<List<dynamic>> getMatches() async {
  AccountSession.check(_generation);
  return MatchesCacheService.loadMatches(_generation, () async {
  final url = Uri.parse('$baseApiUrl/matches');
  final token = await _storage.getToken();

  final res = await _client.get(
    url,
    headers: {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    },
  ).timeout(const Duration(seconds: 15));


  if (res.statusCode == 200) {
    final decoded = jsonDecode(res.body);
    return (decoded as List).cast<dynamic>();
  }

  throw Exception('Matches failed: ${res.statusCode}');
});
}
Future<List<dynamic>> getLikesReceived() async {
  AccountSession.check(_generation);
  return MatchesCacheService.loadLikes(_generation, () async {
  final url = Uri.parse('$baseApiUrl/likes/received');
  final token = await _storage.getToken();

  final res = await _client.get(
    url,
    headers: {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    },
  ).timeout(const Duration(seconds: 15));


  if (res.statusCode == 200) {
    final decoded = jsonDecode(res.body);
    return (decoded as List).cast<dynamic>();
  }

  throw Exception('Likes received failed: ${res.statusCode}');
});
}

//-------------------------------------------------
Future<void> saveProfile({
  required String displayName,
  required int age,
  required String gender,
  required String bio,
  required List<String> photoUrls,
  required List<String> interests,
  required String intention,
  required String religion,
  required String workout,
  required String smoking,
  required String pets,

  int? heightCm,
  bool clearHeight = false,
  double? lat,
  double? lng,
  String? countryCode,
  String? interestedIn,
  int? matchRadiusKm,
  String? relationshipHistory,
  String? zodiacSign,
  String? alcohol,
  String? cannabis,
  String? childrenCount,
  String? wantChildren,
  String? workStatus,
  String? studyPlace,
  String? studySubject,
  String? workPlace,
  String? jobTitle,
  String? livePlace,
  String? originPlace,
}) async {

final body = {
  'displayName': displayName,
  'age': age,
  'gender': gender,
  'bio': bio,
  'photoUrls': photoUrls,
  'interests': interests,
  'intention': intention,
  'religion': religion,
  'workout': workout,
  'smoking': smoking,
  'pets': pets,
  if (heightCm != null || clearHeight) 'heightCm': heightCm,
  if (lat != null) 'lat': lat,
  if (lng != null) 'lng': lng,
  if (countryCode != null) 'countryCode': countryCode,
  if (interestedIn != null) 'interestedIn': interestedIn,
  if (matchRadiusKm != null) 'matchRadiusKm': matchRadiusKm,
  if (relationshipHistory != null) 'relationshipHistory': relationshipHistory,
  if (zodiacSign != null) 'zodiacSign': zodiacSign,
  if (alcohol != null) 'alcohol': alcohol,
  if (cannabis != null) 'cannabis': cannabis,
  if (childrenCount != null) 'childrenCount': childrenCount,
  if (wantChildren != null) 'wantChildren': wantChildren,
  if (workStatus != null) 'workStatus': workStatus,
  if (studyPlace != null) 'studyPlace': studyPlace,
  if (studySubject != null) 'studySubject': studySubject,
  if (workPlace != null) 'workPlace': workPlace,
  if (jobTitle != null) 'jobTitle': jobTitle,
  if (livePlace != null) 'livePlace': livePlace,
  if (originPlace != null) 'originPlace': originPlace,
};


  await _saveProfileBody(body);
}

Future<void> saveOnboardingProfile(OnboardingData data, {DateTime? today}) =>
    _saveProfileBody(data.toProfileUpdate(today: today));

Future<void> _saveProfileBody(Map<String, dynamic> body) async {
  final token = await _storage.getToken();
  if (token == null || token.isEmpty) throw StateError('Logga in igen.');
  final url = Uri.parse('$baseApiUrl/me/profile');
  final res = await _client.post(
    url,
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    },
    body: jsonEncode(body),
  );



  if (res.statusCode == 200 || res.statusCode == 201) return;

  throw Exception('Save profile failed: ${res.statusCode} ${res.body}');
}

Future<void> reportUser({
  required String reportedUserId,
  required String reason,
}) async {
  final token = await _storage.getToken();

  final res = await _client.post(
    Uri.parse('$baseApiUrl/reports'),
    headers: {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    },
    body: jsonEncode({
      'reportedUserId': reportedUserId,
      'reason': reason,
    }),
  );

  if (res.statusCode != 200) {
    throw Exception('Report failed: ${res.statusCode} ${res.body}');
  }
}

 Future<int> updateRadius(int km) async {
  final token = await _storage.getToken();

  final res = await _client.post(
    Uri.parse('$baseApiUrl/me/radius'),
    headers: {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    },
    body: jsonEncode({
      'matchRadiusKm': km,
    }),
  );

  if (res.statusCode == 200) {
    final decoded = jsonDecode(res.body);
    return (decoded['matchRadiusKm'] ?? km) as int;
  }

  throw Exception('Update radius failed: ${res.statusCode} ${res.body}');
}

Future<void> updateFilterProfile({
  required String intention,
  required String religion,
  int? matchRadiusKm,
}) async {
  final token = await _storage.getToken();
  final res = await _client.patch(
    Uri.parse('$baseApiUrl/me/profile'),
    headers: {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    },
    body: jsonEncode({
      'intention': intention,
      'religion': religion,
      if (matchRadiusKm != null) 'matchRadiusKm': matchRadiusKm,
    }),
  );
  if (res.statusCode != 200) {
    throw Exception('Update filter profile failed: ${res.statusCode} ${res.body}');
  }
}

Future<bool> canOpenChat(String otherUserId) async {
  final token = await _storage.getToken();
  if (token == null || token.isEmpty) {
    return false;
  }

  final url = Uri.parse('$baseApiUrl/messages/thread-page?otherUserId=$otherUserId&take=1');

  try {
    final res = await _client.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    return res.statusCode == 200;
  } catch (_) {
    return false;
  }
}

Future<void> saveDeviceToken(String token) async {
  final authToken = await _storage.getToken();
  if (authToken == null || authToken.isEmpty) {
    throw Exception('No auth token found');
  }

  final trimmedToken = token.trim();
  if (trimmedToken.isEmpty) {
    throw Exception('Device token is empty');
  }

  final url = Uri.parse('$baseApiUrl/me/device-token');

  final res = await _client.post(
    url,
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $authToken',
    },
    body: jsonEncode({
      'token': trimmedToken,
    }),
  );

  if (res.statusCode != 200) {
    throw Exception('Save device token failed: ${res.statusCode} ${res.body}');
  }
}




}
