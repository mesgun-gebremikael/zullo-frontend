import 'dart:convert';
import 'package:http/http.dart' as http;

class SwipeService {
  static const String baseUrl = 'https://localhost:7015/swipe';

  Future<List<dynamic>> getFeed() async {
    final url = Uri.parse('$baseUrl/feed');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['profiles'];
    } else {
      throw Exception('Failed to load feed');
    }
  }
}
