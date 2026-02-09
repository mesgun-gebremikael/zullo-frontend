import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthService {
static const String baseUrl = 'https://localhost:7015/api/auth';

  Future<void> login({
    required String email,
    required String password,
  }) async {
    final url = Uri.parse('$baseUrl/login');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      print('Login success');
      print(response.body);
    } else {
      print('Login failed');
      print(response.body);
      throw Exception('Login failed');
    }
  }

 Future<void> register({
  required String name,
  required String email,
  required String password,
}) async {
  try {
    final url = Uri.parse('$baseUrl/register');

    print('➡️ Register request skickas');
    print('URL: $url');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
      }),
    );

    print('⬅️ Status code: ${response.statusCode}');
    print('⬅️ Body: ${response.body}');

    if (response.statusCode == 200 || response.statusCode == 201) {
      print('✅ Register success');
    } else {
      throw Exception('Register failed');
    }
  } catch (e) {
    print('❌ Register error: $e');
    rethrow;
  }
}

}

