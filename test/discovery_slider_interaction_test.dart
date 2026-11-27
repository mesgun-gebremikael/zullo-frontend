import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zullo_app/l10n/app_localizations.dart';
import 'package:zullo_app/widgets/discovery_settings_sheet.dart';

void main() {
  for (final code in ['en', 'ar']) {
    testWidgets('$code slider drags stay local, independent and save once',
        (tester) async {
      tester.view.physicalSize = const Size(430, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final saved = <DiscoveryPreferences>[];
      final pending = Completer<void>();
      await tester.pumpWidget(MaterialApp(
        locale: Locale(code),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
            body: DiscoverySettingsSheet(
          initial: const DiscoveryPreferences(
              interestedIn: 'Alla', radiusKm: 50, minAge: 22, maxAge: 40),
          onSave: (value) {
            saved.add(value);
            return pending.future;
          },
        )),
      ));
      await tester.pumpAndSettle();
      final radiusFinder = find.byType(Slider);
      final agesFinder = find.byType(RangeSlider);
      await tester.ensureVisible(radiusFinder);
      await tester.pumpAndSettle();
      final originalRadius = tester.widget<Slider>(radiusFinder).value;
      final ageWidget = tester.widget<RangeSlider>(agesFinder);
      final settingsTitle = tester.widget<Text>(find.byType(Text).first);
      for (final dx in [100.0, -70.0, 40.0]) {
        await tester.dragFrom(tester.getCenter(radiusFinder), Offset(dx, 0));
        await tester.pumpAndSettle();
      }
      final radius = tester.widget<Slider>(radiusFinder).value;
      expect(radius, isNot(originalRadius));
      expect(
          identical(tester.widget<RangeSlider>(agesFinder), ageWidget), isTrue);
      expect(
          identical(
              tester.widget<Text>(find.byType(Text).first), settingsTitle),
          isTrue);
      expect(saved, isEmpty);
      final radiusWidget = tester.widget<Slider>(radiusFinder);
      await tester.ensureVisible(agesFinder);
      await tester.pumpAndSettle();
      for (final dx in [80.0, -50.0, 30.0]) {
        await tester.dragFrom(tester.getCenter(agesFinder), Offset(dx, 0));
        await tester.pumpAndSettle();
      }
      final ages = tester.widget<RangeSlider>(agesFinder).values;
      expect(ages, isNot(ageWidget.values));
      expect(ages.start, inInclusiveRange(18, 100));
      expect(ages.end, inInclusiveRange(ages.start, 100));
      expect(
          identical(tester.widget<Slider>(radiusFinder), radiusWidget), isTrue);
      expect(saved, isEmpty);
      final button = find.byType(FilledButton);
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pump();
      expect(saved, hasLength(1));
      expect(saved.single.radiusKm, radius.round());
      expect(saved.single.minAge, ages.start.round());
      expect(saved.single.maxAge, ages.end.round());
      expect(tester.widget<Slider>(radiusFinder).onChanged, isNull);
      expect(tester.widget<RangeSlider>(agesFinder).onChanged, isNull);
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      pending.complete();
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
        variant: TargetPlatformVariant(
            {TargetPlatform.android, TargetPlatform.iOS}));
  }
}
