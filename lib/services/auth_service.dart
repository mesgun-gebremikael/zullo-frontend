import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_storage.dart';

class AuthService {
  static const String baseUrl = 'https://localhost:7015/api/auth';
  final AuthStorage _storage = AuthStorage();

  Future<void> login({
    required String email,
    required String password,
  }) async {
    final url = Uri.parse('$baseUrl/login');

    // DEBUG – bra att behålla nu
    print('➡️ LOGIN request skickas');
    print('Email: $email');
    print('Password: $password');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    print('⬅️ Status code: ${response.statusCode}');
    print('⬅️ Body: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await _storage.saveToken(data['token']);


      // 🔑 SPARA TOKEN (viktigt steg)
      await _storage.saveToken(data['token']);

      print('✅ Login success – token sparad');
    } else {
      throw Exception('Login failed');
    }
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final url = Uri.parse('$baseUrl/register');

    print('➡️ REGISTER request skickas');
    print('Name: $name');
    print('Email: $email');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
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
  }
}
