import 'package:zullo_app/onboarding/onboarding_wizard.dart';
import 'package:zullo_app/onboarding/onboarding_steps.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zullo_app/onboarding/onboarding_data.dart';

void main() {
  for (final step in ['name', 'birthdate', 'photos']) {
    testWidgets('$step cannot be skipped without required information',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final data = OnboardingData();
      final page = switch (step) {
        'name' =>
          OnboardingWizard(data: data, initialStep: OnboardingStep.name),
        'birthdate' =>
          OnboardingWizard(data: data, initialStep: OnboardingStep.birthDate),
        _ => OnboardingWizard(data: data, initialStep: OnboardingStep.photos),
      };
      await tester.pumpWidget(MaterialApp(home: page));
      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull);
      if (step == 'name') {
        await tester.enterText(find.byType(TextFormField), 'Anna');
        await tester.pump();
        expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
            isNotNull);
        await tester.tap(find.text('Nästa'));
        await tester.pumpAndSettle();
        expect(data.displayName, 'Anna');
        expect(find.text('När föddes du?'), findsOneWidget);
      }
    });
  }
}
