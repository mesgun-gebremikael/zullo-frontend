import 'dart:convert';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// A device registration intent, persisted before it can reach the server.
/// Neither the installation identity nor its counter is an account credential.
class PushInstallationReservation {
  const PushInstallationReservation(this.installationId, this.version);
  final String installationId;
  final int version;
  Map<String, Object> toJson() => {
        'installationId': installationId,
        'version': version,
      };
}

abstract interface class PushInstallationRecordStore {
  Future<String?> read();
  Future<void> write(String record);
}

class _SecurePushInstallationStore implements PushInstallationRecordStore {
  static const key = 'zullo.push_installation.v1';
  static const storage = FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: false, migrateWithBackup: true),
    iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device),
  );
  @override
  Future<String?> read() => storage.read(key: key);
  @override
  Future<void> write(String record) => storage.write(key: key, value: record);
}

/// Device-wide ordering survives account switches and app restarts.
///
/// Queue reservation synchronously at the time of the user's intent, including
/// before logout's first await. A single encrypted record avoids torn ID/counter
/// writes. Storage failures never fall back to an unversioned token claim.
class PushInstallationBinding {
  PushInstallationBinding({PushInstallationRecordStore? store})
      : _store = store ?? _SecurePushInstallationStore();
  final PushInstallationRecordStore _store;
  static Future<void> _tail = Future.value();
  // Stay representable exactly on both native Dart and Flutter web.
  static const maxVersion = 9007199254740991;
  static final _uuid = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');

  Future<PushInstallationReservation> reserve() {
    final operation = _tail.then((_) async {
      final stored = await _store.read();
      String id;
      var version = 0;
      if (stored == null) {
        id = _newId();
      } else {
        final decoded = jsonDecode(stored);
        if (decoded is! Map<String, dynamic> ||
            decoded['installationId'] is! String ||
            !_uuid.hasMatch(decoded['installationId'] as String) ||
            decoded['version'] is! int ||
            (decoded['version'] as int) < 0 ||
            (decoded['version'] as int) >= maxVersion) {
          throw StateError('Push installation metadata is invalid.');
        }
        id = decoded['installationId'] as String;
        version = decoded['version'] as int;
      }
      final reservation = PushInstallationReservation(id, version + 1);
      await _store.write(jsonEncode(reservation.toJson()));
      return reservation;
    });
    _tail = operation.then<void>((_) {}, onError: (Object _) {});
    return operation;
  }

  static String _newId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
