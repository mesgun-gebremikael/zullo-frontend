import 'package:http/http.dart' as http;
import 'account_session.dart';

/// Never return an old account's response, including a delayed response body.
class SessionHttpClient extends http.BaseClient {
  SessionHttpClient(this._inner, {int Function()? generation})
      : _generation = generation ?? (() => AccountSession.generation);
  final int Function() _generation;
  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final generation = _generation();
    AccountSession.check(generation);
    final response = await _inner.send(request);
    final bytes = await response.stream.toBytes();
    AccountSession.check(generation);
    return http.StreamedResponse(
      Stream.value(bytes),
      response.statusCode,
      contentLength: bytes.length,
      request: response.request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }

  @override
  void close() => _inner.close();
}
