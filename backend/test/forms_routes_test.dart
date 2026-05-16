import 'dart:convert';

import 'package:backend/forms/routes.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

class _StubRepo implements FormsRepositoryBase {
  _StubRepo({this.definedFor = const <String>{}});
  final Set<String> definedFor;
  // Captured for tests so they can assert what was inserted.
  String? lastPageUlid;
  Map<String, String>? lastFields;
  String? lastSourceIp;
  int insertCount = 0;
  String nextId = 'submission-id-01';

  @override
  Future<bool> hasFormDefinition(String ulid) async {
    return definedFor.contains(ulid);
  }

  @override
  Future<String> insertSubmission({
    required String pageUlid,
    required Map<String, String> fields,
    String? sourceIp,
  }) async {
    insertCount++;
    lastPageUlid = pageUlid;
    lastFields = fields;
    lastSourceIp = sourceIp;
    return nextId;
  }
}

Future<Response> _hit(
  String path, {
  required FormsRepositoryBase repo,
  String body = '',
  String method = 'POST',
}) async {
  final handler = buildFormsRouter(repo: repo).call;
  final req = Request(
    method,
    Uri.parse('http://localhost$path'),
    body: body,
    headers: const {'content-type': 'application/x-www-form-urlencoded'},
  );
  return handler(req);
}

void main() {
  group('Forms routes (E46)', () {
    const ulid = '01HX0V0000000000000000000A';

    test('POST /<malformed>/submit → 404 not_found', () async {
      final res = await _hit('/not-a-ulid/submit', repo: _StubRepo());
      expect(res.statusCode, 404);
      expect(await res.readAsString(), 'not_found');
    });

    test('POST /<ulid>/submit with no definition → 404 no_form_definition',
        () async {
      // Repo claims nothing has a definition.
      final res = await _hit('/$ulid/submit', repo: _StubRepo());
      expect(res.statusCode, 404);
      expect(await res.readAsString(), 'no_form_definition');
    });

    test('NoFormsRepository never claims a definition exists', () async {
      const repo = NoFormsRepository();
      expect(await repo.hasFormDefinition(ulid), isFalse);
      expect(await repo.hasFormDefinition('anything'), isFalse);
    });

    test('Valid submit returns 303 to thanks page + inserts row',
        (
    ) async {
      final repo = _StubRepo(definedFor: {ulid});
      final res = await _hit(
        '/$ulid/submit',
        repo: repo,
        body: Uri(queryParameters: const {'name': 'Pat', 'email': 'p@x'})
            .query,
      );
      expect(res.statusCode, 303);
      expect(
        res.headersAll['location']?.single,
        '/forms/$ulid/thanks?id=${repo.nextId}',
      );
      expect(repo.insertCount, 1);
      expect(repo.lastPageUlid, ulid);
      expect(repo.lastFields, {'name': 'Pat', 'email': 'p@x'});
    });

    test('Empty body (no fields) → 400 empty_body', () async {
      final repo = _StubRepo(definedFor: {ulid});
      final res = await _hit('/$ulid/submit', repo: repo);
      expect(res.statusCode, 400);
      expect(await res.readAsString(), 'empty_body');
      expect(repo.insertCount, 0);
    });

    test('All-blank field values → 400 empty_body', () async {
      // Form fields with empty string values shouldn't count as a
      // real submission.
      final repo = _StubRepo(definedFor: {ulid});
      final res = await _hit(
        '/$ulid/submit',
        repo: repo,
        body: 'name=&email=',
      );
      expect(res.statusCode, 400);
      expect(repo.insertCount, 0);
    });

    test('Body larger than 32 KB → 413 body_too_large', () async {
      final repo = _StubRepo(definedFor: {ulid});
      // 33 KB of `a=…` payload.
      final huge = 'a=${'x' * (33 * 1024)}';
      final res = await _hit('/$ulid/submit', repo: repo, body: huge);
      expect(res.statusCode, 413);
      expect(await res.readAsString(), 'body_too_large');
      expect(repo.insertCount, 0);
    });

    test('X-Forwarded-For is captured as source_ip', () async {
      final repo = _StubRepo(definedFor: {ulid});
      final handler = buildFormsRouter(repo: repo).call;
      final req = Request(
        'POST',
        Uri.parse('http://localhost/$ulid/submit'),
        body: 'name=Pat',
        headers: const {
          'content-type': 'application/x-www-form-urlencoded',
          'x-forwarded-for': '203.0.113.42, 10.0.0.1',
        },
      );
      final res = await handler(req);
      expect(res.statusCode, 303);
      expect(repo.lastSourceIp, '203.0.113.42');
    });

    test('GET /<ulid>/thanks returns 200 HTML', () async {
      final res = await _hit(
        '/$ulid/thanks',
        repo: _StubRepo(),
        method: 'GET',
      );
      expect(res.statusCode, 200);
      expect(res.headersAll['content-type']?.single,
          'text/html; charset=utf-8');
      expect(await res.readAsString(), contains('Thanks!'));
    });

    test('Malformed percent-encoding is skipped, not 500ed', () async {
      final repo = _StubRepo(definedFor: {ulid});
      final res = await _hit(
        '/$ulid/submit',
        repo: repo,
        // %ZZ is invalid percent-encoding; the offending pair should
        // be skipped and the rest of the body processed normally.
        body: 'name=%ZZbroken&email=ok%40x',
      );
      // 'name' pair was malformed → dropped; only 'email' remained.
      expect(res.statusCode, 303);
      expect(repo.lastFields, {'email': 'ok@x'});
    });

    test('NoFormsRepository.insertSubmission throws (route should never call)',
        () async {
      const repo = NoFormsRepository();
      expect(
        () => repo.insertSubmission(
          pageUlid: 'X',
          fields: const {'a': 'b'},
        ),
        throwsStateError,
      );
    });

    test('GET on the submit path is not routed (POST only)', () async {
      final res = await _hit('/$ulid/submit', repo: _StubRepo(), method: 'GET');
      // shelf_router returns 404 for an unmatched method.
      expect(res.statusCode, 404);
    });

    test('Submit body is read but ignored at E46 — no crash on non-utf8',
        () async {
      // Even unusual bodies must not crash the handler; E46 just
      // returns 404 before reading the body. Belt-and-braces.
      final res = await _hit(
        '/$ulid/submit',
        repo: _StubRepo(),
        body: utf8.decode([0x68, 0x69]), // 'hi'
      );
      expect(res.statusCode, 404);
    });
  });
}
