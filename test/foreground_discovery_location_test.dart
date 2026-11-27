import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:zullo_app/services/account_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zullo_app/services/auth_service.dart';
import 'package:zullo_app/services/device_location_service.dart';
import 'package:zullo_app/widgets/location_consent_sheet.dart';

class _Auth extends AuthService {
  bool automatic = true;
  int reads = 0;
  final writes = <Map<String, dynamic>>[];
  @override
  Future<Map<String, dynamic>> discoverySettings(
      {Map<String, dynamic>? update}) async {
    if (update != null) {
      writes.add(Map.of(update));
    } else {
      reads++;
    }
    return {'automaticLocation': automatic, 'locationChanged': false};
  }
}

class _Places extends DeviceLocationService {
  int reads = 0;
  final List<DevicePlace> places;
  _Places(this.places);
  @override
  Future<DevicePlace?> locate({required bool requestPermission}) async {
    expect(requestPermission, isFalse);
    return places[reads++ % places.length];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
      'foreground walking accumulates against discovery centre instead of individual GPS steps',
      () async {
    var now = DateTime.utc(2026, 11, 4);
    final auth = _Auth();
    final positions = _Places([
      for (final offset in [0.0, .004, .008, .012])
        DevicePlace(59.3, 18 + offset, 'Stockholm')
    ]);
    final sync =
        ForegroundLocationSync(auth, location: positions, now: () => now);
    expect(await sync.refresh(), isFalse);
    for (final expected in [false, false, true]) {
      now = now.add(const Duration(minutes: 1));
      expect(await sync.refresh(), expected);
    }
    expect(positions.reads, 4);
    expect(auth.writes.last['lng'], 18.012);
  });
  test(
      'normal polling is throttled while a foreground resume can request a fresh position',
      () async {
    final auth = _Auth();
    final positions = _Places([const DevicePlace(40, -3, 'Madrid')]);
    final sync = ForegroundLocationSync(auth, location: positions);
    await sync.refresh();
    await sync.refresh();
    expect(positions.reads, 1);
    await sync.refresh(force: true);
    expect(positions.reads, 2);
    auth.automatic = false;
    await sync.refresh(force: true);
    expect(positions.reads, 2);
  });
  test(
      'background and disabled automatic tracking never request a position, even on forced refresh',
      () async {
    final auth = _Auth()..automatic = false;
    final positions = _Places([const DevicePlace(40, -3, 'Madrid')]);
    await ForegroundLocationSync(auth, location: positions)
        .refresh(force: true);
    auth.automatic = true;
    await ForegroundLocationSync(auth,
        location: positions, isActive: () => false).refresh(force: true);
    expect(positions.reads, 0);
    expect(auth.writes, isEmpty);
  });
  test(
      'location explanation is offered once per installation, including after Later or denial',
      () async {
    expect(await LocationConsentGate().claim({'automaticLocation': false}),
        isTrue);
    expect(await LocationConsentGate().claim({'automaticLocation': false}),
        isFalse);
  });
  test(
      'existing explicit location choices are respected and are not prompted again',
      () async {
    expect(await LocationConsentGate().claim({'automaticLocation': true}),
        isFalse);
    expect(
        await LocationConsentGate().claim({
          'automaticLocation': false,
          'locationUpdatedAtUtc': '2026-11-04T00:00:00Z'
        }),
        isFalse);
  });
  test(
      'unavailable preference storage never produces an automatic location opt-in',
      () async {
    expect(
        await LocationConsentGate(
            preferences: () => Future.error(StateError('offline'))).claim({}),
        isFalse);
  });
  test('parallel consent claims cannot display two explanations', () async {
    final decisions = await Future.wait([
      LocationConsentGate().claim({'automaticLocation': false}),
      LocationConsentGate().claim({'automaticLocation': false}),
    ]);
    expect(decisions.where((accepted) => accepted), hasLength(1));
  });
  test('a stale account sync does not read another account settings or GPS',
      () async {
    final auth = _Auth();
    final positions = _Places([const DevicePlace(40, -3, 'Madrid')]);
    final sync = ForegroundLocationSync(auth, location: positions);
    AccountSession.reset();
    expect(await sync.refresh(force: true), isFalse);
    expect(auth.reads, 0);
    expect(positions.reads, 0);
    expect(auth.writes, isEmpty);
  });
  test('invalid provider coordinates are never sent to the API', () async {
    final auth = _Auth();
    final positions = _Places([DevicePlace(double.nan, -3, 'Invalid')]);
    expect(await ForegroundLocationSync(auth, location: positions).refresh(),
        isFalse);
    expect(auth.writes, isEmpty);
  });
  test('native permission completion after backgrounding never starts GPS',
      () async {
    var foreground = true;
    var positions = 0;
    final permission = Completer<LocationPermission>();
    final service = DeviceLocationService(
      isActive: () => foreground,
      servicesEnabled: () async => true,
      readPermission: () async => LocationPermission.denied,
      requestNativePermission: () => permission.future,
      readPosition: () async {
        positions++;
        throw StateError('must not read');
      },
    );
    final result = service.locate(requestPermission: true);
    await Future<void>.delayed(Duration.zero);
    foreground = false;
    permission.complete(LocationPermission.whileInUse);
    expect(await result, isNull);
    expect(positions, 0);
  });
  test('foreground automatic reads never prompt after a denied permission',
      () async {
    var prompts = 0;
    var positions = 0;
    final service = DeviceLocationService(
      servicesEnabled: () async => true,
      readPermission: () async => LocationPermission.denied,
      requestNativePermission: () async {
        prompts++;
        return LocationPermission.whileInUse;
      },
      readPosition: () async {
        positions++;
        throw StateError('must not read');
      },
    );
    expect(await service.locate(requestPermission: false), isNull);
    expect(prompts, 0);
    expect(positions, 0);
  });
  for (final invalid in [
    (double.nan, 18.0, 10.0),
    (91.0, 18.0, 10.0),
    (59.0, double.infinity, 10.0),
    (59.0, 181.0, 10.0),
    (59.0, 18.0, double.nan),
    (59.0, 18.0, -1.0),
    (59.0, 18.0, 20001.0),
  ]) {
    test('invalid native GPS fix is rejected: $invalid', () async {
      var geocodes = 0;
      final service = DeviceLocationService(
        servicesEnabled: () async => true,
        readPermission: () async => LocationPermission.whileInUse,
        readPosition: () async => Position(
            latitude: invalid.$1,
            longitude: invalid.$2,
            accuracy: invalid.$3,
            timestamp: DateTime.now(),
            altitude: 0,
            altitudeAccuracy: 0,
            heading: 0,
            headingAccuracy: 0,
            speed: 0,
            speedAccuracy: 0),
        readPlacemark: (lat, lng) async {
          geocodes++;
          return [];
        },
      );
      await expectLater(service.locate(requestPermission: false),
          throwsA(isA<LocationFailure>()));
      expect(geocodes, 0);
    });
  }
  testWidgets(
      'contextual location explanation fits enlarged text and Later does not enable tracking',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    bool? decision;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                    body: TextButton(
                  onPressed: () async {
                    decision = await showModalBottomSheet<bool>(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => const MediaQuery(
                            data: MediaQueryData(
                                textScaler: TextScaler.linear(1.7)),
                            child: LocationConsentSheet()));
                  },
                  child: const Text('Open'),
                )))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Fortsätt senare'));
    await tester.tap(find.text('Fortsätt senare'));
    await tester.pumpAndSettle();
    expect(decision, isFalse);
    expect(tester.takeException(), isNull);
  });
}
