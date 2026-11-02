import 'package:zullo_app/onboarding/onboarding_wizard.dart';
import 'package:zullo_app/onboarding/onboarding_steps.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zullo_app/onboarding/onboarding_data.dart';

void main() {
  Future<void> next(WidgetTester tester) async {
    await tester.tap(find.text('Nästa'));
    await tester.pumpAndSettle();
  }

  for (final scenario in ['intention', 'religion', 'work']) {
    testWidgets('$scenario starts blank, supports deselection and skipping',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final data = OnboardingData();
      final page = switch (scenario) {
        'intention' =>
          OnboardingWizard(data: data, initialStep: OnboardingStep.intention),
        'religion' =>
          OnboardingWizard(data: data, initialStep: OnboardingStep.religion),
        _ => OnboardingWizard(data: data, initialStep: OnboardingStep.work),
      };
      final label = switch (scenario) {
        'intention' => 'Seriöst förhållande',
        'religion' => 'Kristen',
        _ => 'Pluggar just nu',
      };
      await tester.pumpWidget(MaterialApp(home: page));
      expect(find.byIcon(Icons.check_rounded), findsNothing);
      if (scenario == 'work') {
        expect(
            tester
                .widgetList<ChoiceChip>(find.byType(ChoiceChip))
                .every((chip) => !chip.selected),
            isTrue);
      }
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      if (scenario != 'work') {
        expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      }
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check_rounded), findsNothing);
      await next(tester);
      expect(data.intention, isEmpty);
      expect(data.religion, isEmpty);
      expect(data.workStatus, isEmpty);
    });
  }

  testWidgets('optional lifestyle answers start blank, toggle, and save blank',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final data = OnboardingData();
    await tester.pumpWidget(MaterialApp(
        home:
            OnboardingWizard(data: data, initialStep: OnboardingStep.height)));
    await next(tester);
    expect(find.byIcon(Icons.check_rounded), findsNothing);
    await tester.tap(find.text('Ibland'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    await tester.tap(find.text('Ibland'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_rounded), findsNothing);
    await next(tester);
    expect(find.byIcon(Icons.check_rounded), findsNothing);
    for (var i = 0; i < 5; i++) {
      await next(tester);
    }
    expect(find.text('Vill du ha barn i framtiden?'), findsOneWidget);
    await next(tester);
    expect(data.heightCm, isNull);
    expect(data.workout, isEmpty);
    expect(data.pets, isEmpty);
    expect(data.smoking, isEmpty);
    expect(data.relationshipHistory, isEmpty);
    expect(data.zodiacSign, isEmpty);
    expect(data.childrenCount, isEmpty);
    expect(data.wantChildren, isEmpty);
  });

  testWidgets(
      'saved family answer can be cleared and stay clear after going back',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final data = OnboardingData()..childrenCount = '1 barn';
    await tester.pumpWidget(MaterialApp(
        home: OnboardingWizard(
            data: data, initialStep: OnboardingStep.children)));
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    await tester.tap(find.text('1 barn'));
    await tester.pumpAndSettle();
    await next(tester);
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Hur många barn har du?'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsNothing);
    await next(tester);
    await next(tester);
    expect(data.childrenCount, isEmpty);
  });
}
