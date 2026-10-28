import 'package:flutter/foundation.dart';

class ApiConfig {
  static const _configured = String.fromEnvironment('ZULLO_API_URL');
  static String get _effectiveUrl => resolve(_configured,
      requireExplicit: !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS);

  static String resolve(String value, {required bool requireExplicit}) {
    if (value.isNotEmpty) return value;
    if (requireExplicit) {
      throw StateError(
          'Ange backendens HTTPS-adress med ZULLO_API_URL för iPhone.');
    }
    return 'http://10.0.2.2:5125';
  }

  static void validate() {
    normalize(_effectiveUrl, release: kReleaseMode);
  }

  static final String baseUrl = normalize(_effectiveUrl, release: kReleaseMode);

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
