import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zullo_app/main_navigation.dart';
import 'package:zullo_app/services/auth_service.dart';
import 'package:zullo_app/services/signalr_service.dart';
import 'support/fake_chat_transport.dart';

class _Auth extends AuthService {
  @override
  Future<List<dynamic>> getMatches() async => [];
}

void main() {
  testWidgets('floating selection follows RTL tab order and reduced motion',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Directionality(
      textDirection: TextDirection.rtl,
      child: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MainNavigation(
            authService: _Auth(),
            liveService: SignalRService(transport: FakeChatTransport()),
            pages: const [SizedBox(), SizedBox(), SizedBox(), SizedBox()]),
      ),
    )));
    await tester.pumpAndSettle();
    var selection = tester.widget<AnimatedAlign>(find.byType(AnimatedAlign));
    expect(
        selection.alignment.resolve(TextDirection.rtl), Alignment.centerRight);
    expect(selection.duration, Duration.zero);
    await tester.tap(find.text('Chattar'));
    await tester.pumpAndSettle();
    selection = tester.widget<AnimatedAlign>(find.byType(AnimatedAlign));
    expect(selection.alignment.resolve(TextDirection.rtl).x,
        closeTo(-1 / 3, .000001));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
