import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zullo_app/onboarding/onboarding_data.dart';
import 'package:zullo_app/onboarding/onboarding_steps.dart';
import 'package:zullo_app/onboarding/onboarding_wizard.dart';
import 'package:zullo_app/welcome_page.dart';

void main() {
  for (final step in OnboardingStep.values) {
    testWidgets(
        'compact keyboard and large text remain scrollable: ${step.name}',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 220);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(MaterialApp(
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!),
          home: OnboardingWizard(data: OnboardingData(), initialStep: step)));
      expect(tester.takeException(), isNull);
      expect(find.byType(SingleChildScrollView), findsWidgets);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('welcome actions remain available on a compact display',
      (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: WelcomePage()));
    await tester.scrollUntilVisible(find.text('Log in'), 120);
    expect(tester.takeException(), isNull);
  });
}
