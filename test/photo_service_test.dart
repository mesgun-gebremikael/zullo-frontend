import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zullo_app/services/account_session.dart';
import 'package:zullo_app/services/auth_storage.dart';
import 'package:zullo_app/services/photo_service.dart';

class PhotoStorage extends AuthStorage {
  @override
  Future<String?> getToken() async => 'photo-token';
}

void main() {
  final bytes = List<int>.filled(20, 1);
  const url = 'https://res.cloudinary.com/test/image/upload/v1/owned.jpg';
  http.Response ready() =>
      http.Response(jsonEncode({'state': 'ready', 'url': url}), 200);
  PhotoService service(Future<http.Response> Function(http.Request) handler) =>
      PhotoService(
          client: MockClient(handler),
          storage: PhotoStorage(),
          delay: (_) async {});
  setUp(AccountSession.reset);

  test(
      'uploads only to authenticated backend with multipart and no local filename',
      () async {
    final photos = service((request) async {
      expect(request.method, 'PUT');
      expect(request.url.path, '/me/photos/operation');
      expect(request.headers['Authorization'], 'Bearer photo-token');
      expect(request.headers['content-type'], contains('multipart/form-data'));
      expect(request.body, contains('name="file"; filename="photo"'));
      expect(request.body, isNot(contains('upload_preset')));
      return ready();
    });
    expect(await photos.uploadBytes(bytes, operationId: 'operation'), url);
  });
  test('network retry reuses the same upload id', () async {
    final paths = <String>[];
    final photos = service((request) async {
      paths.add(request.url.path);
      if (paths.length == 1) throw http.ClientException('offline');
      return ready();
    });
    expect(await photos.uploadBytes(bytes), url);
    expect(paths.length, 2);
    expect(paths[0], paths[1]);
  });
  test('processing response polls the same resource until ready', () async {
    final methods = <String>[];
    final photos = service((request) async {
      methods.add(request.method);
      expect(request.url.path, '/me/photos/pending');
      return methods.length == 1
          ? http.Response('{"state":"uploading"}', 202)
          : ready();
    });
    expect(await photos.uploadBytes(bytes, operationId: 'pending'), url);
    expect(methods, ['PUT', 'GET']);
  });
  test(
      'missing provider configuration is visible before reading the selected file',
      () async {
    final photos = service((request) async {
      expect(request.url.path, '/me/photos/availability');
      return http.Response('{"available":false}', 200);
    });
    expect(await photos.available(), isFalse);
    await expectLater(
        photos.uploadFile(File('/not-a-real-local-image')),
        throwsA(isA<PhotoUploadException>().having(
            (e) => e.message, 'message', contains('inte tillgänglig'))));
  });
  test(
      'server validation message stays readable and failure does not yield a URL',
      () async {
    final photos = service((_) async => http.Response(
        '{"message":"Välj en JPG-, PNG- eller WebP-bild."}', 400));
    await expectLater(
        photos.uploadBytes(bytes),
        throwsA(isA<PhotoUploadException>()
            .having((e) => e.message, 'message', contains('JPG'))));
  });
  test('oversize response and exhausted network retries have friendly messages',
      () async {
    await expectLater(
        service((_) async => http.Response('', 413)).uploadBytes(bytes),
        throwsA(isA<PhotoUploadException>()
            .having((e) => e.message, 'message', contains('10 MB'))));
    var calls = 0;
    await expectLater(
        service((_) async {
          calls++;
          throw http.ClientException('private network detail');
        }).uploadBytes(bytes),
        throwsA(isA<PhotoUploadException>()
            .having((e) => e.message, 'message', isNot(contains('private')))));
    expect(calls, 2);
  });
  for (final value in [
    'http://res.cloudinary.com/x.jpg',
    'https://attacker.test/x.jpg',
    ''
  ]) {
    test('rejects untrusted provider URL: $value', () async {
      final photos = service((_) async =>
          http.Response(jsonEncode({'state': 'ready', 'url': value}), 200));
      await expectLater(
          photos.uploadBytes(bytes), throwsA(isA<PhotoUploadException>()));
    });
  }
  test('malformed success and retired operation never become a saved image',
      () async {
    for (final body in ['[]', '{}', '{"state":"deleted"}', 'not json']) {
      await expectLater(
          service((_) async => http.Response(body, 200)).uploadBytes(bytes),
          throwsA(isA<PhotoUploadException>()));
    }
  });
  test(
      'logout during upload cannot add the previous account image to the next account',
      () async {
    final pending = Completer<http.Response>();
    final started = Completer<void>();
    final photos = service((_) {
      started.complete();
      return pending.future;
    });
    final operation = photos.uploadBytes(bytes);
    final rejected =
        expectLater(operation, throwsA(isA<SessionChangedException>()));
    await started.future;
    AccountSession.reset();
    pending.complete(ready());
    await rejected;
  });
  test('small invalid files are rejected before any network request', () async {
    var calls = 0;
    await expectLater(
        service((_) async {
          calls++;
          return ready();
        }).uploadBytes([1, 2]),
        throwsA(isA<PhotoUploadException>()));
    expect(calls, 0);
  });
}
