import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'account_session.dart';
import 'auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  bool get hasValidCoordinates =>
      lat.isFinite &&
      lng.isFinite &&
      lat >= -90 &&
      lat <= 90 &&
      lng >= -180 &&
      lng <= 180;
}

class DeviceLocationService {
  DeviceLocationService({
    bool Function()? isActive,
    Future<bool> Function()? servicesEnabled,
    Future<LocationPermission> Function()? readPermission,
    Future<LocationPermission> Function()? requestNativePermission,
    Future<Position> Function()? readPosition,
    Future<List<Placemark>> Function(double lat, double lng)? readPlacemark,
  })  : _isActive = isActive,
        _servicesEnabled =
            servicesEnabled ?? Geolocator.isLocationServiceEnabled,
        _readPermission = readPermission ?? Geolocator.checkPermission,
        _requestNativePermission =
            requestNativePermission ?? Geolocator.requestPermission,
        _readPosition = readPosition ??
            (() => Geolocator.getCurrentPosition(
                locationSettings: const LocationSettings(
                    accuracy: LocationAccuracy.medium,
                    timeLimit: Duration(seconds: 15)))),
        _readPlacemark = readPlacemark ??
            ((lat, lng) => Geocoding().placemarkFromCoordinates(lat, lng));
  final bool Function()? _isActive;
  final Future<bool> Function() _servicesEnabled;
  final Future<LocationPermission> Function() _readPermission;
  final Future<LocationPermission> Function() _requestNativePermission;
  final Future<Position> Function() _readPosition;
  final Future<List<Placemark>> Function(double lat, double lng) _readPlacemark;

  /// Only an explicit foreground action may request the native permission.
  Future<DevicePlace?> locate({required bool requestPermission}) async {
    if (_isActive?.call() == false) return null;
    final enabled = await _servicesEnabled();
    if (_isActive?.call() == false) return null;
    if (!enabled) {
      if (requestPermission) {
        throw const LocationFailure(
            'Slå på platstjänster på telefonen och försök igen.');
      }
      return null;
    }
    var permission = await _readPermission();
    if (_isActive?.call() == false) return null;
    if (permission == LocationPermission.denied && requestPermission) {
      permission = await _requestNativePermission();
      if (_isActive?.call() == false) return null;
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
      position = await _readPosition().timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const LocationFailure(
          'Platsen kunde inte hämtas i tid. Försök igen med bättre mottagning.');
    }
    if (_isActive?.call() == false) return null;
    if (!DevicePlace(position.latitude, position.longitude, '')
            .hasValidCoordinates ||
        !position.accuracy.isFinite ||
        position.accuracy < 0 ||
        position.accuracy > 20000) {
      throw const LocationFailure(
          'Platsen är för osäker. Försök igen där telefonen har bättre mottagning.');
    }
    var name = 'Nuvarande plats';
    try {
      final places = await _readPlacemark(position.latitude, position.longitude)
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

/// The contextual explanation is offered once per installation, never on resume.
/// An existing fix means the user already made a choice, even if tracking is off.
class LocationConsentGate {
  LocationConsentGate({Future<SharedPreferences> Function()? preferences})
      : _preferences = preferences ?? SharedPreferences.getInstance;
  static const preferenceKey = 'zullo.location_explanation.v1';
  final Future<SharedPreferences> Function() _preferences;
  bool _claimed = false;
  static Future<void> _claimQueue = Future.value();

  Future<bool> claim(Map<String, dynamic> settings) async {
    if (_claimed ||
        settings['automaticLocation'] == true ||
        settings['locationUpdatedAtUtc'] != null) {
      return false;
    }
    _claimed = true;
    final decision = Completer<bool>();
    _claimQueue = _claimQueue.then((_) async {
      decision.complete(await _claimPreferences());
    });
    return decision.future;
  }

  Future<bool> _claimPreferences() async {
    try {
      final preferences =
          await _preferences().timeout(const Duration(seconds: 3));
      if (preferences.getBool(preferenceKey) == true) return false;
      // Save before displaying, so a permission-dialog resume or app restart
      // cannot produce another explanation or native permission prompt.
      return await preferences.setBool(preferenceKey, true);
    } catch (_) {
      // Location remains opt-in and available from settings if storage is down.
      return false;
    }
  }
}

/// Foreground refresh only: no background tracking or permission prompts.
class ForegroundLocationSync {
  final AuthService auth;
  final DeviceLocationService location;
  final bool Function()? isActive;
  final DateTime Function() now;
  final Duration minimumInterval;
  final int generation = AccountSession.generation;
  DateTime? _checked;
  DevicePlace? _feedOrigin;
  bool _busy = false;
  ForegroundLocationSync(this.auth,
      {DeviceLocationService? location,
      this.isActive,
      DateTime Function()? now,
      this.minimumInterval = const Duration(minutes: 1)})
      : location = location ?? DeviceLocationService(isActive: isActive),
        now = now ?? DateTime.now;

  Future<bool> refresh({bool force = false}) async {
    if (!AccountSession.isCurrent(generation) || isActive?.call() == false) {
      return false;
    }
    if (_busy ||
        (!force &&
            _checked != null &&
            now().difference(_checked!) < minimumInterval)) {
      return false;
    }
    _busy = true;
    try {
      final settings = await auth.discoverySettings();
      AccountSession.check(generation);
      _checked = now();
      if (settings['automaticLocation'] != true || isActive?.call() == false) {
        _feedOrigin = null;
        return false;
      }
      final place = await location.locate(requestPermission: false);
      AccountSession.check(generation);
      if (place == null ||
          !place.hasValidCoordinates ||
          isActive?.call() == false) {
        return false;
      }
      final result = await auth.discoverySettings(update: {
        'lat': place.lat,
        'lng': place.lng,
        'locationName': place.name
      });
      AccountSession.check(generation);
      if (isActive?.call() == false) return false;
      final origin = _feedOrigin;
      final changed = result['locationChanged'] == true ||
          (origin != null &&
              Geolocator.distanceBetween(
                      origin.lat, origin.lng, place.lat, place.lng) >=
                  500);
      // Accumulate movement against the discovery centre, not the previous GPS
      // poll. Otherwise several short walking steps can move a user kilometres
      // without ever refreshing the visible discovery profiles.
      if (origin == null || changed) _feedOrigin = place;
      return changed;
    } catch (_) {
      return false;
    } finally {
      _busy = false;
    }
  }
}
