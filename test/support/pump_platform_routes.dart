import 'package:flutter_test/flutter_test.dart';

/// Route animations use the fake widget clock; platform secure-storage calls
/// resolve in the real async zone. Give both a turn before settling animations.
Future<void> pumpPlatformRoutes(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
  }
  await tester.pumpAndSettle();
}
