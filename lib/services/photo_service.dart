import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'account_session.dart';
import 'auth_storage.dart';
import 'api_config.dart';
import 'session_http_client.dart';

class PhotoUploadException implements Exception {
  final String message;
  const PhotoUploadException(this.message);
  @override
  String toString() => message;
}

/// Uploads go only through the authenticated API. Provider keys and unsigned
/// presets are deliberately absent from the app.
class PhotoService {
  static final _transport = http.Client();
  final AuthStorage _storage;
  final int _generation = AccountSession.generation;
  final Future<void> Function(Duration) _delay;
  late final http.Client _client;
  PhotoService(
      {http.Client? client,
      AuthStorage? storage,
      Future<void> Function(Duration)? delay})
      : _storage = storage ?? AuthStorage(),
        _delay = delay ?? Future<void>.delayed {
    _client =
        SessionHttpClient(client ?? _transport, generation: () => _generation);
  }
  static String _id() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  Future<Map<String, String>> _headers() async {
    AccountSession.check(_generation);
    final token = await _storage.getToken();
    AccountSession.check(_generation);
    if (token == null) {
      throw const PhotoUploadException(
          'Logga in igen innan du laddar upp bilder.');
    }
    return {'Authorization': 'Bearer $token'};
  }

  Map<String, dynamic> _body(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        throw const PhotoUploadException(
            'Uppladdningen kunde inte bekräftas. Försök igen.');
      }
    }
    var message = response.statusCode == 413
        ? 'Bilden är för stor. Max 10 MB.'
        : 'Bilden kunde inte laddas upp just nu. Försök igen.';
    try {
      message =
          (jsonDecode(response.body) as Map)['message']?.toString() ?? message;
    } catch (_) {/* retain friendly message */}
    throw PhotoUploadException(message);
  }

  Future<bool> available() async {
    final response = await _client
        .get(Uri.parse('${ApiConfig.baseUrl}/me/photos/availability'),
            headers: await _headers())
        .timeout(const Duration(seconds: 15));
    return _body(response)['available'] == true;
  }

  Future<String> uploadFile(File file) async {
    if (!await available()) {
      throw const PhotoUploadException(
          'Bilduppladdning är inte tillgänglig just nu. Dina sparade bilder påverkas inte.');
    }
    if (await file.length() > 10 * 1024 * 1024) {
      throw const PhotoUploadException('Bilden är för stor. Max 10 MB.');
    }
    return uploadBytes(await file.readAsBytes());
  }

  Future<String> uploadBytes(List<int> bytes, {String? operationId}) async {
    if (bytes.length < 12 || bytes.length > 10 * 1024 * 1024) {
      throw const PhotoUploadException('Välj en bild på högst 10 MB.');
    }
    final id = operationId ?? _id();
    final url = Uri.parse('${ApiConfig.baseUrl}/me/photos/$id');
    Map<String, dynamic>? result;
    for (var attempt = 0; attempt < 2; attempt++) {
      AccountSession.check(_generation);
      try {
        final request = http.MultipartRequest('PUT', url)
          ..headers.addAll(await _headers());
        request.files.add(
            http.MultipartFile.fromBytes('file', bytes, filename: 'photo'));
        final response = await _client
            .send(request)
            .then(http.Response.fromStream)
            .timeout(const Duration(seconds: 75));
        result = _body(response);
        break;
      } on TimeoutException {
        if (attempt == 1) {
          throw const PhotoUploadException(
              'Uppladdningen kunde inte bekräftas. Kontrollera anslutningen och försök igen.');
        }
        await _delay(const Duration(seconds: 1));
      } on http.ClientException {
        if (attempt == 1) {
          throw const PhotoUploadException(
              'Kontrollera anslutningen och försök igen.');
        }
        await _delay(const Duration(seconds: 1));
      }
    }
    for (var poll = 0; poll < 15; poll++) {
      AccountSession.check(_generation);
      final state = result?['state'];
      if (state == 'ready' || state == 'attached') {
        final value = result?['url']?.toString() ?? '';
        final uri = Uri.tryParse(value);
        if (uri?.scheme != 'https' || uri?.host != 'res.cloudinary.com') {
          throw const PhotoUploadException(
              'Bildadressen kunde inte bekräftas. Försök igen.');
        }
        return value;
      }
      if (state != 'uploading') {
        throw const PhotoUploadException(
            'Uppladdningen har avslutats. Välj bilden igen.');
      }
      await _delay(const Duration(seconds: 2));
      result = _body(await _client
          .get(url, headers: await _headers())
          .timeout(const Duration(seconds: 15)));
    }
    throw const PhotoUploadException(
        'Bilden behandlas fortfarande. Försök igen om en stund.');
  }
}
