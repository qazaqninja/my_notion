import 'dart:convert';

import 'package:backend/auth/middleware.dart';
import 'package:backend/auth/tokens.dart';
import 'package:backend/auth/user.dart';
import 'package:backend/db/users.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

class _FakeUsers implements UserRepositoryBase {
  _FakeUsers(this._users);
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

Handler _attach(User who) => (Request req) async {
      // Sanity: middleware exposes the user via currentUser().
      final u = currentUser(req);
      expect(u, who);
      return Response.ok('ok');
    };

void main() {
  final now = DateTime.utc(2026, 5, 17);
  final alice = User(id: '01HX', email: 'alice@quill', createdAt: now);
  final tokens = TokenIssuer(secret: 'middleware-test-secret');

  group('requireAuth middleware (E7)', () {
    test('missing Authorization header → 401 missing_bearer_token', () async {
      final users = _FakeUsers({alice.id: alice});
      final handler =
          requireAuth(users: users, tokens: tokens)((_) => Response.ok('ok'));
      final res = await handler(
        Request('GET', Uri.parse('http://localhost/x')),
      );
      expect(res.statusCode, 401);
      expect(
        (jsonDecode(await res.readAsString()) as Map<String, Object?>)['error'],
        'missing_bearer_token',
      );
    });

    test('non-Bearer scheme → 401 missing_bearer_token', () async {
      final users = _FakeUsers({alice.id: alice});
      final handler =
          requireAuth(users: users, tokens: tokens)((_) => Response.ok('ok'));
      final res = await handler(
        Request(
          'GET',
          Uri.parse('http://localhost/x'),
          headers: const {'authorization': 'Basic abc'},
        ),
      );
      expect(res.statusCode, 401);
      expect(
        (jsonDecode(await res.readAsString()) as Map<String, Object?>)['error'],
        'missing_bearer_token',
      );
    });

    test('garbage JWT → 401 invalid_token', () async {
      final users = _FakeUsers({alice.id: alice});
      final handler =
          requireAuth(users: users, tokens: tokens)((_) => Response.ok('ok'));
      final res = await handler(
        Request(
          'GET',
          Uri.parse('http://localhost/x'),
          headers: const {'authorization': 'Bearer not-a-real-token'},
        ),
      );
      expect(res.statusCode, 401);
      expect(
        (jsonDecode(await res.readAsString()) as Map<String, Object?>)['error'],
        'invalid_token',
      );
    });

    test('expired JWT → 401 token_expired', () async {
      final users = _FakeUsers({alice.id: alice});
      final tok = tokens.issue(
        alice.id,
        lifetime: const Duration(milliseconds: 1),
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));
      final handler =
          requireAuth(users: users, tokens: tokens)((_) => Response.ok('ok'));
      final res = await handler(
        Request(
          'GET',
          Uri.parse('http://localhost/x'),
          headers: {'authorization': 'Bearer $tok'},
        ),
      );
      expect(res.statusCode, 401);
      expect(
        (jsonDecode(await res.readAsString()) as Map<String, Object?>)['error'],
        'token_expired',
      );
    });

    test('valid JWT for missing user → 401 stale_session', () async {
      final users = _FakeUsers(const {}); // user deleted
      final tok = tokens.issue(alice.id);
      final handler =
          requireAuth(users: users, tokens: tokens)((_) => Response.ok('ok'));
      final res = await handler(
        Request(
          'GET',
          Uri.parse('http://localhost/x'),
          headers: {'authorization': 'Bearer $tok'},
        ),
      );
      expect(res.statusCode, 401);
      expect(
        (jsonDecode(await res.readAsString()) as Map<String, Object?>)['error'],
        'stale_session',
      );
    });

    test('valid JWT + present user → 200 with user in context', () async {
      final users = _FakeUsers({alice.id: alice});
      final tok = tokens.issue(alice.id);
      final handler = requireAuth(users: users, tokens: tokens)(_attach(alice));
      final res = await handler(
        Request(
          'GET',
          Uri.parse('http://localhost/x'),
          headers: {'authorization': 'Bearer $tok'},
        ),
      );
      expect(res.statusCode, 200);
    });

    test('currentUser throws StateError when middleware is missing', () {
      final req = Request('GET', Uri.parse('http://localhost/x'));
      expect(() => currentUser(req), throwsStateError);
    });
  });
}
