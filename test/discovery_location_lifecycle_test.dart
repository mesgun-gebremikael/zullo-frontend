import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zullo_app/discovery_location_page.dart';
import 'package:zullo_app/services/auth_service.dart';
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
  @override
  Future<Map<String, dynamic>> discoverySettings(
      {Map<String, dynamic>? update}) async {
    if (update != null) {
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
  @override
  Future<DevicePlace?> locate({required bool requestPermission}) async {
    permissions.add(requestPermission);
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
}
