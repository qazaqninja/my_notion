// E12: HttpSyncRepository unit tests using package:http/testing's
// `MockClient`. Routes are mirrored against the backend's contract
// (`backend/lib/auth/routes.dart` + `backend/lib/sync/routes.dart`).
//
// These tests prove the request shape (URL, method, headers, body)
// and the response-decode logic without booting a real server.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_notion/features/sync/data/repositories/http_sync_repository.dart';
import 'package:my_notion/features/sync/domain/repositories/sync_repository.dart';

void main() {
  const baseUrl = 'http://localhost:8080';

  HttpSyncRepository repo(http.Client client) =>
      HttpSyncRepository(baseUrl: baseUrl, client: client);

  group('HttpSyncRepository (E12)', () {
    test('signup returns the token from 201', () async {
      final client = MockClient((req) async {
        expect(req.method, 'POST');
        expect(req.url.toString(), '$baseUrl/auth/signup');
        expect(jsonDecode(req.body),
            {'email': 'a@quill', 'password': 'correcthorse'});
        return http.Response(
          jsonEncode({'token': 'jwt-abc', 'user': <String, dynamic>{}}),
          201,
        );
      });
      final token = await repo(client)
          .signup(email: 'a@quill', password: 'correcthorse');
      expect(token, 'jwt-abc');
    });

    test('signup throws SyncEmailTakenException on 409', () async {
      final client = MockClient((_) async => http.Response(
            jsonEncode({'error': 'email_taken'}),
            409,
          ));
      expect(
        repo(client).signup(email: 'a@quill', password: 'correcthorse'),
        throwsA(isA<SyncEmailTakenException>()),
      );
    });

    test('login throws SyncAuthException on 401', () async {
      final client = MockClient((_) async => http.Response(
            jsonEncode({'error': 'invalid_credentials'}),
            401,
          ));
      expect(
        repo(client).login(email: 'a@quill', password: 'wrong'),
        throwsA(isA<SyncAuthException>()),
      );
    });

    test('list decodes the JSON array into SyncFileSummary list', () async {
      final client = MockClient((req) async {
        expect(req.method, 'GET');
        expect(req.url.toString(), '$baseUrl/sync/list');
        expect(req.headers['authorization'], 'Bearer t');
        return http.Response(
          jsonEncode([
            {
              'relpath': 'a.md',
              'sha256': 'aa',
              'mtime': '2026-05-17T00:00:00.000Z',
            },
            {
              'relpath': 'b.md',
              'sha256': 'bb',
              'mtime': '2026-05-17T00:01:00.000Z',
            },
          ]),
          200,
        );
      });
      final list = await repo(client).list(token: 't');
      expect(list, hasLength(2));
      expect(list.first.relpath, 'a.md');
      expect(list.last.sha256, 'bb');
    });

    test('get returns null on 404', () async {
      final client = MockClient((_) async => http.Response(
            jsonEncode({'error': 'not_found'}),
            404,
          ));
      final res = await repo(client).get(token: 't', relpath: 'missing.md');
      expect(res, isNull);
    });

    test('get decodes FileBody on 200', () async {
      final client = MockClient((_) async => http.Response(
            jsonEncode({
              'relpath': 'x.md',
              'sha256': 'sh',
              'mtime': '2026-05-17T00:00:00.000Z',
              'body': '# hi',
            }),
            200,
          ));
      final body = await repo(client).get(token: 't', relpath: 'x.md');
      expect(body, isNotNull);
      expect(body!.body, '# hi');
      expect(body.summary.relpath, 'x.md');
    });

    test('put sends If-Match when provided and returns SyncPutSuccess',
        () async {
      final client = MockClient((req) async {
        expect(req.method, 'PUT');
        expect(req.headers['if-match'], 'old-sha');
        expect(req.body, '# body');
        return http.Response(
          jsonEncode({
            'relpath': 'a.md',
            'sha256': 'new-sha',
            'mtime': '2026-05-17T00:00:00.000Z',
          }),
          200,
        );
      });
      final out = await repo(client).put(
        token: 't',
        relpath: 'a.md',
        body: '# body',
        ifMatch: 'old-sha',
      );
      expect(out, isA<SyncPutSuccess>());
      expect((out as SyncPutSuccess).summary.sha256, 'new-sha');
    });

    test('put returns SyncPutConflict on 409', () async {
      final client = MockClient((_) async => http.Response(
            jsonEncode({
              'error': 'conflict',
              'current': {
                'relpath': 'a.md',
                'sha256': 'server-sha',
                'mtime': '2026-05-17T00:00:00.000Z',
              },
            }),
            409,
          ));
      final out = await repo(client).put(
        token: 't',
        relpath: 'a.md',
        body: '# body',
        ifMatch: 'stale-sha',
      );
      expect(out, isA<SyncPutConflict>());
      expect((out as SyncPutConflict).current.sha256, 'server-sha');
    });

    test('delete returns true on 204', () async {
      final client = MockClient((req) async {
        expect(req.method, 'DELETE');
        return http.Response('', 204);
      });
      expect(
        await repo(client).delete(token: 't', relpath: 'a.md'),
        isTrue,
      );
    });

    test('delete returns false on 404', () async {
      final client = MockClient((_) async => http.Response(
            jsonEncode({'error': 'not_found'}),
            404,
          ));
      expect(
        await repo(client).delete(token: 't', relpath: 'a.md'),
        isFalse,
      );
    });

    test('network failure throws SyncNetworkException', () async {
      final client = MockClient((_) async => throw const FormatException('boom'));
      expect(
        repo(client).list(token: 't'),
        throwsA(isA<SyncNetworkException>()),
      );
    });

    // F8: backend's dbExceptionToResponse middleware emits 503 on a
    // Postgres transport failure. Each HTTP method should surface that
    // as a SyncNetworkException carrying the `backend_unhealthy_db`
    // marker so the UI banner can show specific copy.
    test('F8: list 503 throws SyncNetworkException(backend_unhealthy_db)',
        () async {
      final client = MockClient((_) async => http.Response('', 503));
      await expectLater(
        () => repo(client).list(token: 't'),
        throwsA(
          isA<SyncNetworkException>().having(
            (e) => e.message,
            'message',
            'backend_unhealthy_db',
          ),
        ),
      );
    });

    test('F8: put 503 throws SyncNetworkException(backend_unhealthy_db)',
        () async {
      final client = MockClient((_) async => http.Response('', 503));
      await expectLater(
        () => repo(client).put(token: 't', relpath: 'a.md', body: 'x'),
        throwsA(
          isA<SyncNetworkException>().having(
            (e) => e.message,
            'message',
            'backend_unhealthy_db',
          ),
        ),
      );
    });

    test('F8: delete 503 throws SyncNetworkException(backend_unhealthy_db)',
        () async {
      final client = MockClient((_) async => http.Response('', 503));
      await expectLater(
        () => repo(client).delete(token: 't', relpath: 'a.md'),
        throwsA(
          isA<SyncNetworkException>().having(
            (e) => e.message,
            'message',
            'backend_unhealthy_db',
          ),
        ),
      );
    });
  });
}
