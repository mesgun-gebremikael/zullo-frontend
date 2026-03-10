import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_storage.dart';
import '../models/swipe_profile.dart';
import '../services/auth_service.dart';

class AuthService {
  static const String baseAuthUrl = 'http://localhost:5125/api/auth';
  static const String baseApiUrl = 'http://localhost:5125';

  final AuthStorage _storage = AuthStorage();

  // ---------- AUTH ----------

  Future<void> login({
  required String email,
  required String password,
}) async {
  final url = Uri.parse('$baseAuthUrl/login');

  final response = await http.post(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'email': email, 'password': password}),
  );

  if (response.statusCode == 200) {
    final decoded = jsonDecode(response.body);
    final token = (decoded['token'] ?? '').toString();
    final userId = (decoded['userId'] ?? '').toString();

    if (token.isNotEmpty && userId.isNotEmpty) {
      await _storage.saveAuth(token: token, userId: userId);
    } else if (token.isNotEmpty) {
      // fallback om backend någon gång inte skickar userId
      await _storage.saveToken(token);
    }

    return;
  }

  throw Exception('Login failed: ${response.statusCode} ${response.body}');
}

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final url = Uri.parse('$baseAuthUrl/register');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'email': email, 'password': password}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return;
    }

    throw Exception('Register failed: ${response.statusCode} ${response.body}');
  }

  Future<void> logout() async {
    await _storage.clearAuth();
  }

  // ---------- PROFILE CHECK ----------

  Future<bool> hasProfile() async {
    final token = await _storage.getToken();

    final res = await http.get(
      Uri.parse('$baseApiUrl/me/profile'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    return res.statusCode == 200;
  }

  // ---------- SWIPE FEED ----------

 Future<List<SwipeProfile>> getSwipeFeed() async {
  final token = await _storage.getToken();

  final response = await http.get(
    Uri.parse('$baseApiUrl/swipe/feed'),
    headers: {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    },
  );

  print("FEED status: ${response.statusCode}");
  print("FEED body: ${response.body}");

  if (response.statusCode == 200) {
    final decoded = jsonDecode(response.body);

    // ✅ Stöd både: {profiles:[...]} och: [...]
    final List profilesJson = (decoded is List)
        ? decoded
        : (decoded['profiles'] ?? []) as List;

    return profilesJson.map((j) => SwipeProfile.fromJson(j)).toList();
  }

  if (response.statusCode == 204) return [];

  throw Exception('Failed to load swipe feed: ${response.statusCode} ${response.body}');
}

  // ---------- LIKE / SKIP ----------

  Future<bool> like(String targetUserId) async {
    final token = await _storage.getToken();

    final res = await http.post(
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

    throw Exception('Like failed: ${res.statusCode} ${res.body}');
  }

  Future<void> skip(String targetUserId) async {
    final token = await _storage.getToken();

    final res = await http.post(
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
  final url = Uri.parse('$baseApiUrl/matches');
  final token = await _storage.getToken();

  final res = await http.get(
    url,
    headers: {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    },
  );

  print("MATCHES status: ${res.statusCode}");
  print("MATCHES body: ${res.body}");

  if (res.statusCode == 200) {
    final decoded = jsonDecode(res.body);
    return (decoded as List).cast<dynamic>();
  }

  throw Exception('Matches failed: ${res.statusCode} ${res.body}');
}
Future<List<dynamic>> getLikesReceived() async {
  final url = Uri.parse('$baseApiUrl/likes/received');
  final token = await _storage.getToken();

  final res = await http.get(
    url,
    headers: {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    },
  );

  print("LIKES status: ${res.statusCode}");
  print("LIKES body: ${res.body}");

  if (res.statusCode == 200) {
    final decoded = jsonDecode(res.body);
    return (decoded as List).cast<dynamic>();
  }

  throw Exception('Likes received failed: ${res.statusCode} ${res.body}');
}

//-------------------------------------------------
Future<void> saveProfile({
  required String displayName,
  required int age,
  required String gender,
  String? bio,
  List<String>? photoUrls,
  List<String>? interests,
}) async {
  final token = await _storage.getToken();
  if (token == null || token.isEmpty) {
    throw Exception('No token found. Please login again.');
  }

  final url = Uri.parse('$baseApiUrl/me/profile');

  final body = {
    'displayName': displayName,
    'age': age,
    'gender': gender,
    'bio': bio ?? '',
    'photoUrls': photoUrls ?? [],
    'interests': interests ?? [],
  };

  final res = await http.post(
    url,
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    },
    body: jsonEncode(body),
  );

  print('SAVE PROFILE status: ${res.statusCode}');
  print('SAVE PROFILE body: ${res.body}');

  if (res.statusCode == 200 || res.statusCode == 201) return;

  throw Exception('Save profile failed: ${res.statusCode} ${res.body}');
}


Future<void> reportUser({
  required String reportedUserId,
  required String reason,
}) async {
  final token = await _storage.getToken();

  final res = await http.post(
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

}