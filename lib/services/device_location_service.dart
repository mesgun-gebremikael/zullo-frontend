import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'account_session.dart';
import 'auth_service.dart';

class LocationFailure implements Exception {
  final String message;
  const LocationFailure(this.message);
  @override
  String toString() => message;
}

class DevicePlace {
  final double lat, lng;
  final String name;
  const DevicePlace(this.lat, this.lng, this.name);
}

class DeviceLocationService {
  /// Permission is requested only from an explicit user action in settings.
  Future<DevicePlace?> locate({required bool requestPermission}) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (requestPermission) {
        throw const LocationFailure(
            'Slå på platstjänster på telefonen och försök igen.');
      }
      return null;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied && requestPermission) {
      permission = await Geolocator.requestPermission();
    }
    if (permission != LocationPermission.always &&
        permission != LocationPermission.whileInUse) {
      if (requestPermission) {
        throw const LocationFailure(
            'Tillåt platsåtkomst när appen används i telefonens inställningar.');
      }
      return null;
    }
    Position position;
    try {
      position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 15)));
    } on TimeoutException {
      throw const LocationFailure(
          'Platsen kunde inte hämtas i tid. Försök igen med bättre mottagning.');
    }
    if (position.accuracy > 20000) {
      throw const LocationFailure(
          'Platsen är för osäker. Försök igen där telefonen har bättre mottagning.');
    }
    var name = 'Nuvarande plats';
    try {
      final places = await Geocoding()
          .placemarkFromCoordinates(position.latitude, position.longitude)
          .timeout(const Duration(seconds: 8));
      if (places.isNotEmpty) {
        final p = places.first;
        final city = (p.locality?.isNotEmpty == true
                ? p.locality
                : p.subAdministrativeArea) ??
            '';
        final parts =
            [city, p.country ?? ''].where((s) => s.trim().isNotEmpty).toSet();
        if (parts.isNotEmpty) name = parts.join(', ');
      }
    } catch (_) {
      /* Coordinates remain usable when the device geocoder is offline. */
    }
    return DevicePlace(position.latitude, position.longitude, name);
  }
}

/// Foreground refresh only: no background tracking or repeated permission prompts.
class ForegroundLocationSync {
  final AuthService auth;
  final DeviceLocationService location;
  final bool Function()? isActive;
  final int generation = AccountSession.generation;
  DateTime? _checked;
  bool _busy = false;
  ForegroundLocationSync(this.auth,
      {DeviceLocationService? location, this.isActive})
      : location = location ?? DeviceLocationService();
  Future<bool> refresh() async {
    if (isActive?.call() == false) return false;
    if (_busy ||
        (_checked != null &&
            DateTime.now().difference(_checked!) <
                const Duration(minutes: 5))) {
      return false;
    }
    _busy = true;
    try {
      final settings = await auth.discoverySettings();
      AccountSession.check(generation);
      _checked = DateTime.now();
      if (settings['automaticLocation'] != true || isActive?.call() == false) {
        return false;
      }
      final place = await location.locate(requestPermission: false);
      AccountSession.check(generation);
      if (place == null || isActive?.call() == false) return false;
      final result = await auth.discoverySettings(update: {
        'lat': place.lat,
        'lng': place.lng,
        'locationName': place.name
      });
      AccountSession.check(generation);
      return result['locationChanged'] == true;
    } catch (_) {
      return false;
    } finally {
      _busy = false;
    }
  }
}
