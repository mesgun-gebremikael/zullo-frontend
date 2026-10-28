import 'package:flutter/foundation.dart';

class ApiConfig {
  static const _configured = String.fromEnvironment('ZULLO_API_URL',
      defaultValue: 'http://10.0.2.2:5125');
  static void validate() {
    normalize(_configured, release: kReleaseMode);
  }

  static final String baseUrl = normalize(_configured, release: kReleaseMode);

  static String normalize(String value, {required bool release}) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.host.isEmpty ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (release && uri.scheme != 'https')) {
      throw StateError(
          'Ange en giltig HTTPS-adress för backend med ZULLO_API_URL.');
    }
    return value.replaceFirst(RegExp(r'/+$'), '');
  }
}
