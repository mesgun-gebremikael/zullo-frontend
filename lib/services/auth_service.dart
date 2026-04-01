import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_storage.dart';
import '../models/swipe_profile.dart';


class AuthService {
  //static const String baseAuthUrl = 'http://localhost:5125/api/auth';
  static const String baseAuthUrl = 'http://10.0.2.2:5125/api/auth';
  static const String baseApiUrl = 'http://10.0.2.2:5125';
 // static const String baseApiUrl = 'http://localhost:5125';

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

  Future<Map<String, dynamic>> getMyProfile() async {
  final token = await _storage.getToken();

  final res = await http.get(
    Uri.parse('$baseApiUrl/me/profile'),
    headers: {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    },
  );

  print("MY PROFILE status: ${res.statusCode}");
  print("MY PROFILE body: ${res.body}");

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

  final response = await http.get(
    Uri.parse(
      '$baseApiUrl/swipe/feed?minAge=$minAge&maxAge=$maxAge',
    ),
    headers: {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    },
  );
    print("Feed status: ${response.statusCode}");
    print("Feed body: ${response.body}");

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

if (res.statusCode == 429) {
  final decoded = jsonDecode(res.body);
  throw Exception(decoded['message'] ?? 'Like limit reached');
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
  required String bio,
  required List<String> photoUrls,
  required List<String> interests,
  required String intention,
  required String religion,
  required String workout,
  required String smoking,
  required String pets,

  int? heightCm,
  String relationshipHistory = "",
  String zodiacSign = "",
  String alcohol = "",
  String cannabis = "",
  String childrenCount = "",
  String wantChildren = "",
  String workStatus = "",
  String studyPlace = "",
  String studySubject = "",
  String workPlace = "",
  String jobTitle = "",
  String livePlace = "",
  String originPlace = "",
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
  'intention': intention ?? '',
  'religion': religion ?? '',
  'workout': workout ?? '',
  'smoking': smoking ?? '',
  'pets': pets ?? '',
  'heightCm': heightCm,
  'relationshipHistory': relationshipHistory ?? '',
  'zodiacSign': zodiacSign ?? '',
  'alcohol': alcohol ?? '',
  'cannabis': cannabis ?? '',
  'childrenCount': childrenCount ?? '',
  'wantChildren': wantChildren ?? '',
  'workStatus': workStatus ?? '',
  'studyPlace': studyPlace ?? '',
  'studySubject': studySubject ?? '',
  'workPlace': workPlace ?? '',
  'jobTitle': jobTitle ?? '',
  'livePlace': livePlace ?? '',
  'originPlace': originPlace ?? '',
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

 Future<int> updateRadius(int km) async {
  final token = await _storage.getToken();

  final res = await http.post(
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
}) async {
  final token = await _storage.getToken();

  final me = await getMyProfile();

  final body = {
    "displayName": me["displayName"] ?? "",
    "age": me["age"] ?? 18,
    "gender": me["gender"] ?? "",
    "bio": me["bio"] ?? "",
    "intention": intention,
    "religion": religion,
    "workout": me["workout"] ?? "Sometimes",
    "smoking": me["smoking"] ?? "No",
    "pets": me["pets"] ?? "Want",
    "interests": me["interests"] ?? [],
    "photoUrls": me["photoUrls"] ?? [],
    "lat": me["lat"] ?? 0,
    "lng": me["lng"] ?? 0,
    "countryCode": me["countryCode"] ?? ""
  };

  final res = await http.post(
    Uri.parse('$baseApiUrl/me/profile'),
    headers: {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    },
    body: jsonEncode(body),
  );

  if (res.statusCode != 200 && res.statusCode != 201) {
    throw Exception('Update filter profile failed: ${res.statusCode} ${res.body}');
  }
}

}