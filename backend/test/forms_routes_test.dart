import 'dart:convert';

import 'package:backend/auth/user.dart';
import 'package:backend/db/exceptions.dart';
import 'package:backend/forms/form_schema.dart';
import 'package:backend/forms/routes.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

/// A repo that always claims to have a definition + an empty schema,
/// but throws DbUnavailableException from insertSubmission. Used to
/// verify the route's F6 503 mapping.
class _ThrowingRepo implements FormsRepositoryBase {
  @override
  Future<bool> hasFormDefinition(String ulid) async => true;
  @override
  Future<FormSchema?> loadSchemaFor(String ulid) async => FormSchema.empty;
  @override
  Future<String> insertSubmission({
    required String pageUlid,
    required Map<String, Object?> fields,
    String? sourceIp,
  }) async =>
      throw const DbUnavailableException(
        'insertSubmission failed: connection refused',
      );
  @override
  Future<List<FormSubmission>?> listSubmissionsFor({
    required String userId,
    required String pageUlid,
  }) async =>
      throw const DbUnavailableException(
        'listSubmissionsFor failed: connection refused',
      );
}

/// E56b — minimal stub for the GET `/{ulid}` handler that only
/// exercises `loadSchemaFor`. Reusing the larger `_StubRepo` here
/// would expose 4 unrelated method overrides per test (TS-05).
class _SchemaStub implements FormsRepositoryBase {
  _SchemaStub(this.schemas);
  final Map<String, FormSchema?> schemas;

  @override
  Future<FormSchema?> loadSchemaFor(String ulid) async => schemas[ulid];

  @override
  Future<bool> hasFormDefinition(String ulid) =>
      throw UnimplementedError('GET /<ulid> does not gate on hasFormDefinition');

  @override
  Future<String> insertSubmission({
    required String pageUlid,
    required Map<String, Object?> fields,
    String? sourceIp,
  }) =>
      throw UnimplementedError('GET /<ulid> does not insert submissions');

  @override
  Future<List<FormSubmission>?> listSubmissionsFor({
    required String userId,
    required String pageUlid,
  }) =>
      throw UnimplementedError('GET /<ulid> does not list submissions');
}

class _StubRepo implements FormsRepositoryBase {
  _StubRepo({
    this.definedFor = const <String>{},
    this.pageOwners = const <String, String>{},
    this.submissionsByPage = const <String, List<FormSubmission>>{},
    this.schemas = const <String, FormSchema>{},
  });
  final Set<String> definedFor;
  // E49 — ownership + submission listing.
  final Map<String, String> pageOwners; // pageUlid → userId
  final Map<String, List<FormSubmission>> submissionsByPage;
  // F5 — schema lookup keyed by pageUlid.
  final Map<String, FormSchema> schemas;
  // Captured for tests so they can assert what was inserted.
  String? lastPageUlid;
  Map<String, Object?>? lastFields;
  String? lastSourceIp;
  int insertCount = 0;
  String nextId = 'submission-id-01';

  @override
  Future<bool> hasFormDefinition(String ulid) async {
    return definedFor.contains(ulid);
  }

  @override
  Future<FormSchema?> loadSchemaFor(String ulid) async {
    return schemas[ulid];
  }

  @override
  Future<List<FormSubmission>?> listSubmissionsFor({
    required String userId,
    required String pageUlid,
  }) async {
    if (pageOwners[pageUlid] != userId) return null;
    return submissionsByPage[pageUlid] ?? const [];
  }

  @override
  Future<String> insertSubmission({
    required String pageUlid,
    required Map<String, Object?> fields,
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

    group('GET /<ulid> (E56b)', () {
      // Focused stub: the GET handler only calls loadSchemaFor, so
      // overriding the rest of FormsRepositoryBase is dead weight
      // (TS-05). _StubRepo stays in use for the surrounding submit
      // tests that exercise the full surface.
      _SchemaStub schemaStub({Map<String, FormSchema?> schemas = const {}}) =>
          _SchemaStub(schemas);

      test('malformed ULID → 404 not_found', () async {
        final res = await _hit(
          '/not-a-ulid',
          repo: schemaStub(),
          method: 'GET',
        );
        expect(res.statusCode, 404);
      });

      test('no schema → 404 no_form_definition', () async {
        final res = await _hit('/$ulid', repo: schemaStub(), method: 'GET');
        expect(res.statusCode, 404);
        expect(await res.readAsString(), 'no_form_definition');
      });

      test('real schema → 200 form HTML', () async {
        final res = await _hit(
          '/$ulid',
          repo: schemaStub(schemas: const {
            ulid: FormSchema(fields: [
              FormFieldDef(name: 'subject', type: FormFieldType.text),
              FormFieldDef(
                name: 'priority',
                type: FormFieldType.select,
                options: ['low', 'high'],
              ),
            ]),
          }),
          method: 'GET',
        );
        expect(res.statusCode, 200);
        expect(res.headersAll['content-type']?.single,
            'text/html; charset=utf-8');
        final html = await res.readAsString();
        expect(html,
            contains('<form method="POST" action="/forms/$ulid/submit"'));
        expect(html, contains('name="subject"'));
        expect(html, contains('<option value="high">high</option>'));
      });

      test('FormSchema.empty → 200 form HTML (no inputs)', () async {
        // F5 fallback: form-bearing page but no resolvable schema
        // (e.g. `forms: true` with no linked .database.yaml) still
        // renders the skeleton — the submit endpoint will 400
        // empty_body if the user posts nothing, but the GET
        // shouldn't 404 a real form page.
        final res = await _hit(
          '/$ulid',
          repo: schemaStub(schemas: const {ulid: FormSchema.empty}),
          method: 'GET',
        );
        expect(res.statusCode, 200);
        final html = await res.readAsString();
        expect(html, contains('<form method="POST"'));
        expect(html, isNot(contains('<input')));
      });
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

    // F5 — schema-aware validation in the route.
    FormSchema fullSchema() => const FormSchema(fields: [
          FormFieldDef(
            name: 'email',
            type: FormFieldType.text,
            required: true,
          ),
          FormFieldDef(name: 'age', type: FormFieldType.number),
          FormFieldDef(
            name: 'subscribed',
            type: FormFieldType.checkbox,
          ),
        ]);

    test('F5: valid schema submission → 303 + normalized types', () async {
      final repo = _StubRepo(
        definedFor: {ulid},
        schemas: {ulid: fullSchema()},
      );
      final res = await _hit(
        '/$ulid/submit',
        repo: repo,
        body: 'email=pat%40x&age=42&subscribed=on',
      );
      expect(res.statusCode, 303);
      // Normalized map preserves types — age is int, subscribed is bool.
      expect(repo.lastFields, {
        'email': 'pat@x',
        'age': 42,
        'subscribed': true,
      });
    });

    test('F5: missing required field → 422 validation_failed', () async {
      final repo = _StubRepo(
        definedFor: {ulid},
        schemas: {ulid: fullSchema()},
      );
      final res = await _hit(
        '/$ulid/submit',
        repo: repo,
        body: 'age=42',
      );
      expect(res.statusCode, 422);
      final body =
          jsonDecode(await res.readAsString()) as Map<String, dynamic>;
      expect(body['error'], 'validation_failed');
      expect((body['errors'] as Map)['email'], 'required');
      expect(repo.insertCount, 0);
    });

    test('F5: non-numeric in number field → 422 expected_number', () async {
      final repo = _StubRepo(
        definedFor: {ulid},
        schemas: {ulid: fullSchema()},
      );
      final res = await _hit(
        '/$ulid/submit',
        repo: repo,
        body: 'email=ok%40x&age=forty-two',
      );
      expect(res.statusCode, 422);
      final errors = (jsonDecode(await res.readAsString())
          as Map<String, dynamic>)['errors'] as Map;
      expect(errors['age'], 'expected_number');
      expect(repo.insertCount, 0);
    });

    test('F5: empty schema (legacy fallback) accepts any non-empty body',
        () async {
      final repo = _StubRepo(
        definedFor: {ulid},
        schemas: const {ulid: FormSchema.empty},
      );
      final res = await _hit(
        '/$ulid/submit',
        repo: repo,
        body: 'foo=bar',
      );
      expect(res.statusCode, 303);
      expect(repo.lastFields, {'foo': 'bar'});
    });

    test('F5: null schema (no entry) also falls through', () async {
      // schemas map deliberately empty → loadSchemaFor returns null.
      final repo = _StubRepo(definedFor: {ulid});
      final res = await _hit(
        '/$ulid/submit',
        repo: repo,
        body: 'foo=bar',
      );
      expect(res.statusCode, 303);
      expect(repo.lastFields, {'foo': 'bar'});
    });

    test('F5: submission with only extras + optional schema → 400 empty_body',
        () async {
      const optionalOnly = FormSchema(fields: [
        FormFieldDef(name: 'note', type: FormFieldType.text),
      ]);
      final repo = _StubRepo(
        definedFor: {ulid},
        schemas: const {ulid: optionalOnly},
      );
      // Validator drops `rocketship` (not in schema), `note` was
      // optional + missing → normalized map empty → 400.
      final res = await _hit(
        '/$ulid/submit',
        repo: repo,
        body: 'rocketship=launch',
      );
      expect(res.statusCode, 400);
      expect(await res.readAsString(), 'empty_body');
      expect(repo.insertCount, 0);
    });

    test('F6/F7: repo-thrown DbException maps to 503 db_unavailable',
        () async {
      // F7 moved the catch into a shelf Middleware
      // (dbExceptionToResponse) shared across every db-backed router.
      // Reproduce the production wiring by wrapping the test pipeline
      // with the same middleware — the test only asserts the response
      // contract, not which layer caught the exception.
      final repo = _ThrowingRepo();
      final handler = const Pipeline()
          .addMiddleware(dbExceptionToResponse())
          .addHandler(buildFormsRouter(repo: repo).call);
      final req = Request(
        'POST',
        Uri.parse('http://localhost/$ulid/submit'),
        body: 'name=Pat',
        headers: const {
          'content-type': 'application/x-www-form-urlencoded',
        },
      );
      final res = await handler(req);
      expect(res.statusCode, 503);
      final body = jsonDecode(await res.readAsString())
          as Map<String, dynamic>;
      expect(body['error'], 'db_unavailable');
      expect(body['op'], contains('insertSubmission'));
    });
  });

  // E49 — owner-facing list-submissions endpoint.
  group('Owner forms routes (E49)', () {
    const ulid = '01HX0V0000000000000000000A';
    const ownerId = 'user-alice';

    User owner({String id = ownerId}) =>
        User(id: id, email: '$id@quill', createdAt: DateTime.utc(2026));

    Future<Response> ownerHit({
      required FormsRepositoryBase repo,
      required User user,
      required String path,
    }) async {
      final handler = buildOwnerFormsRouter(repo: repo).call;
      final req = Request(
        'GET',
        Uri.parse('http://localhost$path'),
      ).change(context: {'user': user});
      return handler(req);
    }

    test('Returns 403 not_owner when the caller does not own the page',
        () async {
      final repo = _StubRepo(pageOwners: const {ulid: 'someone-else'});
      final res = await ownerHit(
        repo: repo,
        user: owner(),
        path: '/$ulid/submissions',
      );
      expect(res.statusCode, 403);
      expect(jsonDecode(await res.readAsString()),
          {'error': 'not_owner'});
    });

    test('Returns 403 not_owner when the page is missing entirely',
        () async {
      // Same response shape for not-mine vs missing — avoids ULID
      // enumeration by visitors.
      final repo = _StubRepo();
      final res = await ownerHit(
        repo: repo,
        user: owner(),
        path: '/$ulid/submissions',
      );
      expect(res.statusCode, 403);
    });

    test('Returns 404 not_found for malformed ULID', () async {
      final res = await ownerHit(
        repo: _StubRepo(),
        user: owner(),
        path: '/not-a-ulid/submissions',
      );
      expect(res.statusCode, 404);
    });

    test('Returns 200 with submissions when the caller owns the page',
        () async {
      final submissions = [
        FormSubmission(
          id: 'sub-1',
          pageUlid: ulid,
          fields: const {'name': 'Pat', 'email': 'p@x'},
          createdAt: DateTime.utc(2026, 5, 17, 12),
          sourceIp: '203.0.113.42',
        ),
        FormSubmission(
          id: 'sub-2',
          pageUlid: ulid,
          fields: const {'name': 'Jo'},
          createdAt: DateTime.utc(2026, 5, 17, 13),
        ),
      ];
      final repo = _StubRepo(
        pageOwners: const {ulid: ownerId},
        submissionsByPage: {ulid: submissions},
      );
      final res = await ownerHit(
        repo: repo,
        user: owner(),
        path: '/$ulid/submissions',
      );
      expect(res.statusCode, 200);
      final body = jsonDecode(await res.readAsString())
          as Map<String, dynamic>;
      final list =
          (body['submissions'] as List).cast<Map<String, Object?>>();
      expect(list.length, 2);
      expect(list[0]['id'], 'sub-1');
      expect(list[0]['fields'], {'name': 'Pat', 'email': 'p@x'});
      expect(list[0]['source_ip'], '203.0.113.42');
      expect(list[1]['id'], 'sub-2');
      // sourceIp omitted when null.
      expect(list[1].containsKey('source_ip'), isFalse);
    });

    test(
        'Returns 200 with empty list when owner exists but no submissions',
        () async {
      final repo = _StubRepo(pageOwners: const {ulid: ownerId});
      final res = await ownerHit(
        repo: repo,
        user: owner(),
        path: '/$ulid/submissions',
      );
      expect(res.statusCode, 200);
      final body = jsonDecode(await res.readAsString())
          as Map<String, dynamic>;
      expect(body['submissions'], isEmpty);
    });

    test('NoFormsRepository.listSubmissionsFor returns null', () async {
      const repo = NoFormsRepository();
      final result = await repo.listSubmissionsFor(
        userId: 'any',
        pageUlid: 'any',
      );
      expect(result, isNull);
    });
  });
}
