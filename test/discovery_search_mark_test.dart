import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zullo_app/widgets/discovery_search_mark.dart';

Widget mark(
        {bool paused = false, bool reduceMotion = false, bool ticker = true}) =>
    MaterialApp(
        home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: TickerMode(
          enabled: ticker,
          child: Center(child: DiscoverySearchMark(size: 156, paused: paused))),
    ));

void main() {
  testWidgets('discovery colour moves while visible and stops when paused',
      (tester) async {
    await tester.pumpWidget(mark());
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    await tester.pump(const Duration(milliseconds: 650));
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    await tester.pumpWidget(mark(paused: true));
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
  testWidgets('reduced motion and hidden tabs never keep an animation ticking',
      (tester) async {
    await tester.pumpWidget(mark(reduceMotion: true));
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(mark(ticker: false));
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
  testWidgets('background pauses animation and foreground resumes it',
      (tester) async {
    await tester.pumpWidget(mark());
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    expect(tester.binding.transientCallbackCount, 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}
