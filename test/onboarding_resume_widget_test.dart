import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zullo_app/onboarding/onboarding_start_page.dart';
import 'package:zullo_app/services/onboarding_draft_service.dart';
import 'support/draft_fakes.dart';
import 'support/pump_platform_routes.dart';

void main() {
  testWidgets(
      'a saved account draft opens at its saved step with existing answers',
      (tester) async {
    final service = FakeDraftService(storage: DraftStorage())
      ..remote = const DraftSnapshot(
          3, 7, {'displayName': 'Anna', 'livePlace': 'Stockholm'});
    await tester.pumpWidget(
        MaterialApp(home: OnboardingStartPage(draftService: service)));
    await pumpPlatformRoutes(tester);
    expect(find.text('Var bor du?'), findsOneWidget);
    expect(find.text('Stockholm'), findsOneWidget);
    await tester.tap(find.byTooltip('Tillbaka'));
    await tester.pumpAndSettle();
    expect(find.text('Vad jobbar du med?'), findsOneWidget);
  });
}
