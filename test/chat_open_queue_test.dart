import 'package:flutter_test/flutter_test.dart';
import 'package:zullo_app/models/chat_open_request.dart';
import 'package:zullo_app/services/chat_coordinator.dart';

void main() {
  setUp(() => ChatCoordinator.instance.clearPendingRequest());
  tearDown(() => ChatCoordinator.instance.clearPendingRequest());
  test(
      'acknowledging a live request prevents a repeated open after navigation recreation',
      () {
    final request =
        ChatOpenRequest(userId: 'peer', displayName: 'Person', photoUrl: '');
    ChatCoordinator.instance.requestOpenChat(request);
    expect(ChatCoordinator.instance.consumePendingRequest(expected: request),
        same(request));
    expect(ChatCoordinator.instance.consumePendingRequest(), isNull);
  });
  test('an older stream event cannot consume a newer pending chat', () {
    final older =
        ChatOpenRequest(userId: 'first', displayName: 'First', photoUrl: '');
    final newer =
        ChatOpenRequest(userId: 'second', displayName: 'Second', photoUrl: '');
    ChatCoordinator.instance.requestOpenChat(older);
    ChatCoordinator.instance.requestOpenChat(newer);
    expect(ChatCoordinator.instance.consumePendingRequest(expected: older),
        isNull);
    expect(ChatCoordinator.instance.consumePendingRequest(), same(newer));
    expect(ChatCoordinator.instance.consumePendingRequest(), isNull);
  });
}
