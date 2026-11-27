import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zullo_app/services/account_session.dart';
import 'package:zullo_app/widgets/discovery_settings_sheet.dart';

Future<void> showSheet(WidgetTester tester, DiscoveryPreferences initial,
    Future<void> Function(DiscoveryPreferences) save) async {
  tester.view.physicalSize = const Size(430, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: Builder(
    builder: (context) => TextButton(
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => DiscoverySettingsSheet(initial: initial, onSave: save),
      ),
      child: const Text('open'),
    ),
  ))));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('legacy out of range and reversed ages remain editable and safe',
      (tester) async {
    DiscoveryPreferences? saved;
    await showSheet(
        tester,
        const DiscoveryPreferences(
            interestedIn: 'Alla',
            radiusKm: 500,
            minAge: 120,
            maxAge: 16), (value) async {
      saved = value;
    });
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.byType(RangeSlider), 200);
    final slider = tester.widget<RangeSlider>(find.byType(RangeSlider));
    expect(slider.values, const RangeValues(18, 100));
    await tester.scrollUntilVisible(find.text('Spara inställningar'), 200);
    await tester.tap(find.text('Spara inställningar'));
    await tester.pumpAndSettle();
    expect(saved?.minAge, 18);
    expect(saved?.maxAge, 100);
    expect(saved?.radiusKm, 300);
  });

  testWidgets('old account save completion cannot close a new account route',
      (tester) async {
    final pending = Completer<void>();
    await showSheet(
        tester,
        const DiscoveryPreferences(
            interestedIn: 'Alla', radiusKm: 50, minAge: 18, maxAge: 40),
        (_) => pending.future);
    await tester.scrollUntilVisible(find.text('Spara inställningar'), 200);
    await tester.tap(find.text('Spara inställningar'));
    await tester.pump();
    AccountSession.reset();
    final context = tester.element(find.byType(DiscoverySettingsSheet));
    unawaited(Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('New account')))));
    await tester.pumpAndSettle();
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('New account'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
