import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zullo_app/onboarding/onboarding_birthdate_page.dart';
import 'package:zullo_app/onboarding/onboarding_data.dart';
import 'package:zullo_app/onboarding/onboarding_name_page.dart';
import 'package:zullo_app/onboarding/onboarding_photos_page.dart';

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
        'name' => OnboardingNamePage(data: data),
        'birthdate' => OnboardingBirthdatePage(data: data),
        _ => OnboardingPhotosPage(data: data),
      };
      await tester.pumpWidget(MaterialApp(home: page));
      expect(
          tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
          isNull);
      if (step == 'name') {
        await tester.enterText(find.byType(TextField), 'Anna');
        await tester.pump();
        expect(
            tester
                .widget<ElevatedButton>(find.byType(ElevatedButton))
                .onPressed,
            isNotNull);
        await tester.tap(find.text('Nästa'));
        await tester.pumpAndSettle();
        expect(data.displayName, 'Anna');
        expect(find.text('När föddes du?'), findsOneWidget);
      }
    });
  }
}
