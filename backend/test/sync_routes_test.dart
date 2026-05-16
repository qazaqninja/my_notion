import 'dart:convert';

import 'package:backend/auth/middleware.dart';
import 'package:backend/auth/tokens.dart';
import 'package:backend/auth/user.dart';
import 'package:backend/db/sync.dart';
import 'package:backend/db/users.dart';
import 'package:backend/sync/file_summary.dart';
import 'package:backend/sync/routes.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

class _Users implements UserRepositoryBase {
  _Users(this._users);
  final Map<String, User> _users;

  @override
  Future<User?> findById(String id) async => _users[id];

  @override
  Future<User> create(
          {required String email, required String passwordHash}) async =>
      throw UnimplementedError();

  @override
  Future<User?> findByEmail(String email) async => throw UnimplementedError();

  @override
  Future<String?> passwordHashOf(String email) async =>
      throw UnimplementedError();
}

class _Sync implements SyncRepositoryBase {
  _Sync(this._byUser);
  final Map<String, List<FileSummary>> _byUser;
  // (userId → (relpath → body)) — captured by upsert so tests can
  // assert per-user scoping on writes too.
  final Map<String, Map<String, String>> bodies = {};

  @override
  Future<List<FileSummary>> listFor(String userId) async =>
      _byUser[userId] ?? const [];

  @override
  Future<FileSummary> upsert({
    required String userId,
    required String relpath,
    required String body,
    required String sha256,
  }) async {
    bodies.putIfAbsent(userId, () => {})[relpath] = body;
    final summary = FileSummary(
      relpath: relpath,
      sha256: sha256,
      mtime: DateTime.utc(2026, 5, 17, 12),
    );
    final list = _byUser.putIfAbsent(userId, () => <FileSummary>[]);
    final without = list.where((f) => f.relpath != relpath).toList();
    _byUser[userId] = [...without, summary]
      ..sort((a, b) => a.relpath.compareTo(b.relpath));
    return summary;
  }
}

void main() {
  final now = DateTime.utc(2026, 5, 17);
  final alice = User(id: '01HXALICE', email: 'alice@quill', createdAt: now);
  final tokens = TokenIssuer(secret: 'sync-test-secret');

  group('Sync routes (E8)', () {
    test('GET /list without Authorization → 401 from middleware', () async {
      final users = _Users({alice.id: alice});
      final sync = _Sync(const {});
      final pipeline = Pipeline()
          .addMiddleware(requireAuth(users: users, tokens: tokens))
          .addHandler(buildSyncRouter(sync: sync).call);
      final res = await pipeline(
        Request('GET', Uri.parse('http://localhost/list')),
      );
      expect(res.statusCode, 401);
    });

    test('GET /list with valid Bearer for empty user returns []', () async {
      final users = _Users({alice.id: alice});
      final sync = _Sync({alice.id: const []});
      final tok = tokens.issue(alice.id);
      final pipeline = Pipeline()
          .addMiddleware(requireAuth(users: users, tokens: tokens))
          .addHandler(buildSyncRouter(sync: sync).call);
      final res = await pipeline(
        Request(
          'GET',
          Uri.parse('http://localhost/list'),
          headers: {'authorization': 'Bearer $tok'},
        ),
      );
      expect(res.statusCode, 200);
      expect(jsonDecode(await res.readAsString()), isEmpty);
    });

    test('GET /list returns the user`s file summaries sorted by relpath',
        () async {
      final users = _Users({alice.id: alice});
      final files = [
        FileSummary(
          relpath: 'Inbox/Note.md',
          sha256: 'aaa',
          mtime: now,
        ),
        FileSummary(
          relpath: 'README.md',
          sha256: 'bbb',
          mtime: now.add(const Duration(hours: 1)),
        ),
      ];
      final sync = _Sync({alice.id: files});
      final tok = tokens.issue(alice.id);
      final pipeline = Pipeline()
          .addMiddleware(requireAuth(users: users, tokens: tokens))
          .addHandler(buildSyncRouter(sync: sync).call);
      final res = await pipeline(
        Request(
          'GET',
          Uri.parse('http://localhost/list'),
          headers: {'authorization': 'Bearer $tok'},
        ),
      );
      expect(res.statusCode, 200);
      final body = jsonDecode(await res.readAsString()) as List;
      expect(body, hasLength(2));
      expect(body[0]['relpath'], 'Inbox/Note.md');
      expect(body[0]['sha256'], 'aaa');
      expect(body[1]['relpath'], 'README.md');
    });

    test('PUT /put/<relpath> upserts body and returns FileSummary', () async {
      final users = _Users({alice.id: alice});
      final sync = _Sync({alice.id: const []});
      final tok = tokens.issue(alice.id);
      final pipeline = Pipeline()
          .addMiddleware(requireAuth(users: users, tokens: tokens))
          .addHandler(buildSyncRouter(sync: sync).call);
      final res = await pipeline(
        Request(
          'PUT',
          Uri.parse('http://localhost/put/Inbox/Note.md'),
          headers: {'authorization': 'Bearer $tok'},
          body: '# hello',
        ),
      );
      expect(res.statusCode, 200);
      final body = jsonDecode(await res.readAsString()) as Map<String, dynamic>;
      expect(body['relpath'], 'Inbox/Note.md');
      // Server-computed sha256 of '# hello'.
      expect(body['sha256'], isA<String>());
      expect((body['sha256'] as String).length, 64);
      // The fake captured the body for the right user.
      expect(sync.bodies[alice.id]?['Inbox/Note.md'], '# hello');
    });

    test('PUT /put: path-traversal `..` is normalised away by Uri parsing '
        'before the route handler runs', () async {
      // Defense-in-depth note: Dart's Uri.parse collapses `..` segments
      // automatically (RFC 3986 §5.2.4), so a URL like
      // `/put/notes/../bob/secret.md` is decoded to `/put/bob/secret.md`
      // before shelf_router matches the pattern. The handler sees
      // `bob/secret.md` and accepts it — safe. The `_isSafeRelpath`
      // check still rejects literal `..` segments that bypass URI
      // normalisation (e.g. body-decoded multipart paths in future work).
      final users = _Users({alice.id: alice});
      final sync = _Sync({alice.id: const []});
      final tok = tokens.issue(alice.id);
      final pipeline = Pipeline()
          .addMiddleware(requireAuth(users: users, tokens: tokens))
          .addHandler(buildSyncRouter(sync: sync).call);
      final res = await pipeline(
        Request(
          'PUT',
          Uri.parse('http://localhost/put/notes/../bob/secret.md'),
          headers: {'authorization': 'Bearer $tok'},
          body: 'bad',
        ),
      );
      expect(res.statusCode, 200);
      // The relpath that landed in storage has the `..` segment collapsed.
      expect(sync.bodies[alice.id]?.keys, contains('bob/secret.md'));
    });

    test("GET /list scopes to the caller's user_id only", () async {
      final bob = User(id: '01HXBOB', email: 'bob@quill', createdAt: now);
      final users = _Users({alice.id: alice, bob.id: bob});
      final sync = _Sync({
        alice.id: [
          FileSummary(relpath: 'alice.md', sha256: 'a', mtime: now),
        ],
        bob.id: [
          FileSummary(relpath: 'bob.md', sha256: 'b', mtime: now),
        ],
      });
      final aliceTok = tokens.issue(alice.id);
      final pipeline = Pipeline()
          .addMiddleware(requireAuth(users: users, tokens: tokens))
          .addHandler(buildSyncRouter(sync: sync).call);
      final res = await pipeline(
        Request(
          'GET',
          Uri.parse('http://localhost/list'),
          headers: {'authorization': 'Bearer $aliceTok'},
        ),
      );
      final body = jsonDecode(await res.readAsString()) as List;
      expect(body, hasLength(1));
      expect(body[0]['relpath'], 'alice.md');
      // Bob's file must NOT appear.
      expect(jsonEncode(body), isNot(contains('bob.md')));
    });
  });
}
