import 'dart:convert';

import 'package:backend/forms/routes.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

class _StubRepo implements FormsRepositoryBase {
  _StubRepo({this.definedFor = const <String>{}});
  final Set<String> definedFor;

  @override
  Future<bool> hasFormDefinition(String ulid) async {
    return definedFor.contains(ulid);
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

    test('POST /<ulid>/submit when repo says definition exists → 501 stub',
        () async {
      // Slice E46 places the placeholder behind the definition check
      // so we know the call would otherwise route to the future
      // schema-validate + insert path.
      final repo = _StubRepo(definedFor: {ulid});
      final res = await _hit(
        '/$ulid/submit',
        repo: repo,
        body: Uri(queryParameters: const {'name': 'Pat', 'email': 'p@x'})
            .query,
      );
      expect(res.statusCode, 501);
      expect(await res.readAsString(), 'not_implemented');
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
