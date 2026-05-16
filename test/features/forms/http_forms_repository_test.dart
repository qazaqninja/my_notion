import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_notion/features/forms/data/repositories/http_forms_repository.dart';
import 'package:my_notion/features/forms/domain/repositories/forms_repository.dart';

/// E50 — HTTP-side of the owner-form-submissions client. Uses
/// MockClient to stand in for the live backend — mirrors how
/// HttpSyncRepository is tested.
void main() {
  const baseUrl = 'http://localhost:8080';
  const ulid = '01HX0V0000000000000000000A';
  const token = 'jwt-tester';

  group('HttpFormsRepository.listSubmissions (E50)', () {
    test('200 with JSON list → decoded FormSubmission entities', () async {
      final client = MockClient((req) async {
        expect(req.method, 'GET');
        expect(
          req.url.toString(),
          '$baseUrl/forms/owner/$ulid/submissions',
        );
        expect(req.headers['authorization'], 'Bearer $token');
        return http.Response(
          jsonEncode({
            'submissions': [
              {
                'id': 'sub-1',
                'page_ulid': ulid,
                'fields': {'name': 'Pat', 'email': 'p@x'},
                'created_at': '2026-05-17T12:00:00.000Z',
                'source_ip': '203.0.113.42',
              },
              {
                'id': 'sub-2',
                'page_ulid': ulid,
                'fields': {'name': 'Jo'},
                'created_at': '2026-05-17T13:00:00.000Z',
              },
            ],
          }),
          200,
          headers: const {'content-type': 'application/json'},
        );
      });
      final repo = HttpFormsRepository(baseUrl: baseUrl, client: client);
      final list = await repo.listSubmissions(token: token, ulid: ulid);
      expect(list.length, 2);
      expect(list[0].id, 'sub-1');
      expect(list[0].fields, {'name': 'Pat', 'email': 'p@x'});
      expect(list[0].sourceIp, '203.0.113.42');
      expect(list[1].sourceIp, isNull);
    });

    test('401 throws FormsAuthException', () async {
      final client = MockClient((req) async => http.Response('', 401));
      final repo = HttpFormsRepository(baseUrl: baseUrl, client: client);
      expect(
        () => repo.listSubmissions(token: token, ulid: ulid),
        throwsA(isA<FormsAuthException>()),
      );
    });

    test('403 throws FormsNotOwnerException', () async {
      final client = MockClient(
        (req) async => http.Response(
          jsonEncode({'error': 'not_owner'}),
          403,
          headers: const {'content-type': 'application/json'},
        ),
      );
      final repo = HttpFormsRepository(baseUrl: baseUrl, client: client);
      expect(
        () => repo.listSubmissions(token: token, ulid: ulid),
        throwsA(isA<FormsNotOwnerException>()),
      );
    });

    test('Other non-200 throws generic FormsException', () async {
      final client = MockClient(
        (req) async => http.Response('boom', 500),
      );
      final repo = HttpFormsRepository(baseUrl: baseUrl, client: client);
      expect(
        () => repo.listSubmissions(token: token, ulid: ulid),
        throwsA(isA<FormsException>()
            .having((e) => e.message, 'message', contains('500'))),
      );
    });

    test('Transport failure throws FormsNetworkException', () async {
      final client = MockClient((req) async {
        throw const FormatException('connection refused');
      });
      final repo = HttpFormsRepository(baseUrl: baseUrl, client: client);
      expect(
        () => repo.listSubmissions(token: token, ulid: ulid),
        throwsA(isA<FormsNetworkException>()),
      );
    });

    test('Empty submissions array decodes to empty list', () async {
      final client = MockClient(
        (req) async => http.Response(
          jsonEncode(<String, dynamic>{'submissions': <Object>[]}),
          200,
          headers: const {'content-type': 'application/json'},
        ),
      );
      final repo = HttpFormsRepository(baseUrl: baseUrl, client: client);
      final list = await repo.listSubmissions(token: token, ulid: ulid);
      expect(list, isEmpty);
    });

    test('Missing submissions key defaults to empty list', () async {
      final client = MockClient(
        (req) async => http.Response(
          jsonEncode(<String, dynamic>{'submissions': <Object>[]}),
          200,
          headers: const {'content-type': 'application/json'},
        ),
      );
      final repo = HttpFormsRepository(baseUrl: baseUrl, client: client);
      final list = await repo.listSubmissions(token: token, ulid: ulid);
      expect(list, isEmpty);
    });
  });
}
