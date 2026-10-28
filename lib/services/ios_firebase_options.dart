import 'package:firebase_core/firebase_core.dart';

/// Public Firebase client settings, supplied from the registered iOS app.
/// Never put Apple signing keys or Firebase service-account credentials here.
class IosFirebaseOptions {
  static const configured = {
    'ZULLO_IOS_FIREBASE_API_KEY':
        String.fromEnvironment('ZULLO_IOS_FIREBASE_API_KEY'),
    'ZULLO_IOS_FIREBASE_APP_ID':
        String.fromEnvironment('ZULLO_IOS_FIREBASE_APP_ID'),
    'ZULLO_IOS_FIREBASE_SENDER_ID':
        String.fromEnvironment('ZULLO_IOS_FIREBASE_SENDER_ID'),
    'ZULLO_IOS_FIREBASE_PROJECT_ID':
        String.fromEnvironment('ZULLO_IOS_FIREBASE_PROJECT_ID'),
    'ZULLO_IOS_BUNDLE_ID': String.fromEnvironment('ZULLO_IOS_BUNDLE_ID'),
  };

  static FirebaseOptions fromValues(Map<String, String> values) {
    final missing = configured.keys
        .where((key) => (values[key] ?? '').trim().isEmpty)
        .toList();
    if (missing.isNotEmpty) {
      throw StateError(
          'iPhone Firebase saknar inställningar: ${missing.join(', ')}. Se docs/ios-setup.md.');
    }
    final appId = values['ZULLO_IOS_FIREBASE_APP_ID']!.trim();
    final sender = values['ZULLO_IOS_FIREBASE_SENDER_ID']!.trim();
    final match = RegExp(r'^1:([0-9]+):ios:[a-fA-F0-9]+$').firstMatch(appId);
    if (match == null || match.group(1) != sender) {
      throw StateError(
          'Använd app-ID och avsändar-ID från samma registrerade iOS-app i Firebase.');
    }
    final bundle = values['ZULLO_IOS_BUNDLE_ID']!.trim();
    if (!RegExp(r'^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$').hasMatch(bundle)) {
      throw StateError('Ange iOS-appens registrerade bundle-ID.');
    }
    return FirebaseOptions(
      apiKey: values['ZULLO_IOS_FIREBASE_API_KEY']!.trim(),
      appId: appId,
      messagingSenderId: sender,
      projectId: values['ZULLO_IOS_FIREBASE_PROJECT_ID']!.trim(),
      iosBundleId: bundle,
    );
  }
}
