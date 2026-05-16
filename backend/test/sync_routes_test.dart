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
  Future<UpsertOutcome> upsert({
    required String userId,
    required String relpath,
    required String body,
    required String sha256,
    String? ifMatch,
  }) async {
    // Conflict-detection mirror of the real impl.
    final existing = _byUser[userId]
        ?.where((f) => f.relpath == relpath)
        .firstOrNull;
    if (ifMatch != null) {
      if (ifMatch == '*' && existing != null) {
        return UpsertOutcome.conflict(existing);
      }
      if (ifMatch != '*' &&
          existing != null &&
          existing.sha256 != ifMatch) {
        return UpsertOutcome.conflict(existing);
      }
    }
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
    return UpsertOutcome.persisted(summary);
  }

  @override
  Future<bool> delete({
    required String userId,
    required String relpath,
  }) async {
    final list = _byUser[userId];
    if (list == null) return false;
    final without = list.where((f) => f.relpath != relpath).toList();
    if (without.length == list.length) return false;
    _byUser[userId] = without;
    bodies[userId]?.remove(relpath);
    return true;
  }

  @override
  Future<FileBody?> fetch({
    required String userId,
    required String relpath,
  }) async {
    final body = bodies[userId]?[relpath];
    final list = _byUser[userId];
    if (list == null || body == null) return null;
    FileSummary? summary;
    for (final f in list) {
      if (f.relpath == relpath) {
        summary = f;
        break;
      }
    }
    if (summary == null) return null;
    return FileBody(summary: summary, body: body);
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

    test('GET /get/<relpath> returns 404 when the file does not exist',
        () async {
      final users = _Users({alice.id: alice});
      final sync = _Sync({alice.id: const []});
      final tok = tokens.issue(alice.id);
      final pipeline = Pipeline()
          .addMiddleware(requireAuth(users: users, tokens: tokens))
          .addHandler(buildSyncRouter(sync: sync).call);
      final res = await pipeline(
        Request(
          'GET',
          Uri.parse('http://localhost/get/Nope.md'),
          headers: {'authorization': 'Bearer $tok'},
        ),
      );
      expect(res.statusCode, 404);
      expect(jsonDecode(await res.readAsString())['error'], 'not_found');
    });

    test('PUT /put then GET /get round-trips the body', () async {
      final users = _Users({alice.id: alice});
      final sync = _Sync({alice.id: const []});
      final tok = tokens.issue(alice.id);
      final pipeline = Pipeline()
          .addMiddleware(requireAuth(users: users, tokens: tokens))
          .addHandler(buildSyncRouter(sync: sync).call);
      // PUT
      final put = await pipeline(
        Request(
          'PUT',
          Uri.parse('http://localhost/put/notes/idea.md'),
          headers: {'authorization': 'Bearer $tok'},
          body: 'eat the rich',
        ),
      );
      expect(put.statusCode, 200);
      // GET
      final get = await pipeline(
        Request(
          'GET',
          Uri.parse('http://localhost/get/notes/idea.md'),
          headers: {'authorization': 'Bearer $tok'},
        ),
      );
      expect(get.statusCode, 200);
      final body = jsonDecode(await get.readAsString()) as Map<String, dynamic>;
      expect(body['relpath'], 'notes/idea.md');
      expect(body['body'], 'eat the rich');
      expect((body['sha256'] as String).length, 64);
    });

    test('PUT with If-Match: <stale> returns 409 + current summary', () async {
      final users = _Users({alice.id: alice});
      final sync = _Sync({alice.id: const []});
      final tok = tokens.issue(alice.id);
      final pipeline = Pipeline()
          .addMiddleware(requireAuth(users: users, tokens: tokens))
          .addHandler(buildSyncRouter(sync: sync).call);
      // Initial put — no If-Match.
      await pipeline(
        Request(
          'PUT',
          Uri.parse('http://localhost/put/contention.md'),
          headers: {'authorization': 'Bearer $tok'},
          body: 'v1',
        ),
      );
      // Stale client sends If-Match with the wrong sha — must conflict.
      final res = await pipeline(
        Request(
          'PUT',
          Uri.parse('http://localhost/put/contention.md'),
          headers: {
            'authorization': 'Bearer $tok',
            'if-match': 'deadbeef' * 8,
          },
          body: 'v2',
        ),
      );
      expect(res.statusCode, 409);
      final body = jsonDecode(await res.readAsString()) as Map<String, dynamic>;
      expect(body['error'], 'conflict');
      expect(body['current'], isA<Map<String, dynamic>>());
      // Stored body should still be the original v1 from the first PUT.
      expect(sync.bodies[alice.id]?['contention.md'], 'v1');
    });

    test('PUT with If-Match: * succeeds when no row exists', () async {
      final users = _Users({alice.id: alice});
      final sync = _Sync({alice.id: const []});
      final tok = tokens.issue(alice.id);
      final pipeline = Pipeline()
          .addMiddleware(requireAuth(users: users, tokens: tokens))
          .addHandler(buildSyncRouter(sync: sync).call);
      final res = await pipeline(
        Request(
          'PUT',
          Uri.parse('http://localhost/put/new.md'),
          headers: {
            'authorization': 'Bearer $tok',
            'if-match': '*',
          },
          body: 'first',
        ),
      );
      expect(res.statusCode, 200);
    });

    test('DELETE removes the file and returns 204', () async {
      final users = _Users({alice.id: alice});
      final sync = _Sync({alice.id: const []});
      final tok = tokens.issue(alice.id);
      final pipeline = Pipeline()
          .addMiddleware(requireAuth(users: users, tokens: tokens))
          .addHandler(buildSyncRouter(sync: sync).call);
      // First put a file.
      await pipeline(
        Request(
          'PUT',
          Uri.parse('http://localhost/put/doomed.md'),
          headers: {'authorization': 'Bearer $tok'},
          body: 'about to die',
        ),
      );
      // Then delete it.
      final del = await pipeline(
        Request(
          'DELETE',
          Uri.parse('http://localhost/del/doomed.md'),
          headers: {'authorization': 'Bearer $tok'},
        ),
      );
      expect(del.statusCode, 204);
      expect(sync.bodies[alice.id]?.containsKey('doomed.md') ?? false, false);
    });

    test('DELETE on a missing file returns 404 not_found', () async {
      final users = _Users({alice.id: alice});
      final sync = _Sync({alice.id: const []});
      final tok = tokens.issue(alice.id);
      final pipeline = Pipeline()
          .addMiddleware(requireAuth(users: users, tokens: tokens))
          .addHandler(buildSyncRouter(sync: sync).call);
      final res = await pipeline(
        Request(
          'DELETE',
          Uri.parse('http://localhost/del/ghost.md'),
          headers: {'authorization': 'Bearer $tok'},
        ),
      );
      expect(res.statusCode, 404);
      expect(jsonDecode(await res.readAsString())['error'], 'not_found');
    });

    test('GET /get/<relpath> is scoped to caller user_id', () async {
      final bob = User(id: '01HXBOB2', email: 'bob@quill', createdAt: now);
      final users = _Users({alice.id: alice, bob.id: bob});
      final sync = _Sync({alice.id: const [], bob.id: const []});
      // Pre-seed Bob's vault.
      await sync.upsert(
        userId: bob.id,
        relpath: 'bob-secret.md',
        body: 'classified',
        sha256: 'b' * 64,
      );
      final aliceTok = tokens.issue(alice.id);
      final pipeline = Pipeline()
          .addMiddleware(requireAuth(users: users, tokens: tokens))
          .addHandler(buildSyncRouter(sync: sync).call);
      // Alice tries to read Bob's file.
      final res = await pipeline(
        Request(
          'GET',
          Uri.parse('http://localhost/get/bob-secret.md'),
          headers: {'authorization': 'Bearer $aliceTok'},
        ),
      );
      expect(res.statusCode, 404, reason: 'Alice must not see Bob`s file');
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
