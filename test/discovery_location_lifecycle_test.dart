import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zullo_app/discovery_location_page.dart';
import 'package:zullo_app/services/auth_service.dart';
import 'package:zullo_app/services/account_session.dart';
import 'package:zullo_app/services/device_location_service.dart';

class _Settings extends AuthService {
  final Map<String, dynamic> value = {
    'automaticLocation': true,
    'expandDistance': false,
    'expandAge': false,
    'locationName': 'Saved city',
    'radiusKm': 50,
    'minAge': 18,
    'maxAge': 99,
  };
  final writes = <Map<String, dynamic>>[];
  bool failWrites = false;
  @override
  Future<Map<String, dynamic>> discoverySettings(
      {Map<String, dynamic>? update}) async {
    if (update != null) {
      if (failWrites) throw StateError('Offline');
      writes.add(Map.of(update));
      value.addAll(update);
    }
    return Map.of(value);
  }
}

class _Location extends DeviceLocationService {
  final permissions = <bool>[];
  DevicePlace value = const DevicePlace(40.4, -3.7, 'Madrid');
  Completer<DevicePlace?>? pending;
  LocationFailure? failure;
  @override
  Future<DevicePlace?> locate({required bool requestPermission}) async {
    permissions.add(requestPermission);
    if (failure != null) throw failure!;
    return pending?.future ?? value;
  }
}

Future<void> _show(
    WidgetTester tester, _Settings auth, _Location location) async {
  await tester.pumpWidget(MaterialApp(
      home:
          DiscoveryLocationPage(authService: auth, locationService: location)));
  await tester.pumpAndSettle();
}

Future<void> _dispose(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pump();
}

void main() {
  testWidgets(
      'turning automatic location on asks permission and saves a real fix atomically',
      (tester) async {
    final auth = _Settings()..value['automaticLocation'] = false;
    final location = _Location();
    await _show(tester, auth, location);
    expect(location.permissions, isEmpty);
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(location.permissions, [true]);
    expect(auth.writes.single['automaticLocation'], isTrue);
    expect(auth.writes.single['lat'], 40.4);
    expect(find.text('Madrid'), findsOneWidget);
    await _dispose(tester);
  });
  testWidgets(
      'opening settings and resuming refreshes an enabled position without another permission prompt',
      (tester) async {
    final auth = _Settings();
    final location = _Location();
    await _show(tester, auth, location);
    expect(location.permissions, [false]);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    location.value = const DevicePlace(59.3, 18.0, 'Stockholm');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(location.permissions, [false, false]);
    expect(auth.writes.last['locationName'], 'Stockholm');
    expect(find.text('Stockholm'), findsOneWidget);
    await _dispose(tester);
  });
  testWidgets(
      'backgrounding before a settings GPS read finishes prevents saving its coordinates',
      (tester) async {
    final auth = _Settings();
    final location = _Location()..pending = Completer<DevicePlace?>();
    await tester.pumpWidget(MaterialApp(
        home: DiscoveryLocationPage(
            authService: auth, locationService: location)));
    await tester.pump();
    expect(location.permissions, [false]);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    location.pending!.complete(const DevicePlace(59.3, 18, 'Stockholm'));
    await tester.pumpAndSettle();
    expect(auth.writes, isEmpty);
    await _dispose(tester);
  });
  testWidgets('turning tracking off wins against an older resumed GPS read',
      (tester) async {
    final auth = _Settings();
    final location = _Location();
    await _show(tester, auth, location);
    location.pending = Completer<DevicePlace?>();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(location.permissions, [false, false]);
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    location.pending!.complete(const DevicePlace(59.3, 18, 'Stockholm'));
    await tester.pumpAndSettle();
    expect(auth.writes, hasLength(2));
    expect(auth.writes.last, {'automaticLocation': false});
    expect(tester.widget<Switch>(find.byType(Switch).first).value, isFalse);
    expect(find.text('Stockholm'), findsNothing);
    await _dispose(tester);
  });
  testWidgets(
      'failed preference save keeps the previous switch and supports retry',
      (tester) async {
    final auth = _Settings()..value['automaticLocation'] = false;
    await _show(tester, auth, _Location());
    auth.failWrites = true;
    await tester.ensureVisible(find.byType(Switch).at(1));
    await tester.tap(find.byType(Switch).at(1));
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(find.byType(Switch).at(1)).value, isFalse);
    await tester.drag(find.byType(ListView), const Offset(0, 1000));
    await tester.pumpAndSettle();
    expect(find.textContaining('Ändringen kunde inte sparas'), findsOneWidget);
    auth.failWrites = false;
    await tester.ensureVisible(find.byType(Switch).at(1));
    await tester.tap(find.byType(Switch).at(1));
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(find.byType(Switch).at(1)).value, isTrue);
    await _dispose(tester);
  });
  testWidgets('stale account settings cannot write into the next account',
      (tester) async {
    final auth = _Settings()..value['automaticLocation'] = false;
    await _show(tester, auth, _Location());
    AccountSession.reset();
    await tester.ensureVisible(find.byType(Switch).at(1));
    await tester.tap(find.byType(Switch).at(1));
    await tester.pumpAndSettle();
    expect(auth.writes, isEmpty);
    await _dispose(tester);
  });
  testWidgets(
      'denied GPS permission leaves automatic location off with explanation',
      (tester) async {
    final auth = _Settings()..value['automaticLocation'] = false;
    final location = _Location()
      ..failure = const LocationFailure(
          'Tillåt platsåtkomst när appen används i telefonens inställningar.');
    await _show(tester, auth, location);
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(auth.writes, isEmpty);
    expect(tester.widget<Switch>(find.byType(Switch).first).value, isFalse);
    expect(find.textContaining('Tillåt platsåtkomst'), findsOneWidget);
    await _dispose(tester);
  });
}
