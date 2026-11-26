import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zullo_app/services/account_session.dart';
import 'package:zullo_app/services/auth_service.dart';
import 'package:zullo_app/services/auth_storage.dart';

class WaitingTokenStorage extends AuthStorage {
  final token = Completer<String?>();
  @override
  Future<String?> getToken() => token.future;
}

void main() {
  for (final superLike in [false, true, null]) {
    test('account switch while reading token never submits swipe $superLike',
        () async {
      final storage = WaitingTokenStorage();
      var sent = 0;
      final auth = AuthService(
          storage: storage,
          client: MockClient((request) async {
            sent++;
            return http.Response('{"matched":false}', 200);
          }));
      final pending = superLike == null
          ? auth.skip('peer')
          : auth.like('peer', superLike: superLike);
      final failure =
          expectLater(pending, throwsA(isA<SessionChangedException>()));
      AccountSession.reset();
      storage.token.complete('old-account-token');
      await failure;
      expect(sent, 0);
    });
  }
}
