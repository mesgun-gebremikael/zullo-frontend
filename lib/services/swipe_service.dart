import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';


class SwipeService {
  static final String baseUrl = '$apiBaseUrl/swipe';

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
