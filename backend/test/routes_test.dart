import 'dart:convert';

import 'package:backend/auth/password.dart';
import 'package:backend/auth/routes.dart';
import 'package:backend/auth/tokens.dart';
import 'package:backend/auth/user.dart';
import 'package:backend/db/users.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:test/test.dart';
import 'package:ulid/ulid.dart';

/// In-memory UserRepositoryBase for route tests. Email is normalised on
/// the route side, so the fake just does literal string-keyed lookups.
class _FakeUsers implements UserRepositoryBase {
  final Map<String, User> _byEmail = {};
  final Map<String, String> _hashByEmail = {};

  @override
  Future<User> create({
    required String email,
    required String passwordHash,
  }) async {
    if (_byEmail.containsKey(email)) {
      throw EmailAlreadyTakenException(email);
    }
    final user = User(
      id: Ulid().toString(),
      email: email,
      createdAt: DateTime.utc(2026, 5, 17),
    );
    _byEmail[email] = user;
    _hashByEmail[email] = passwordHash;
    return user;
  }

  @override
  Future<User?> findByEmail(String email) async => _byEmail[email];

  @override
  Future<User?> findById(String id) async =>
      _byEmail.values.firstWhere((u) => u.id == id, orElse: () => _missing);

  @override
  Future<String?> passwordHashOf(String email) async => _hashByEmail[email];

  static final _missing = User(
    id: '__missing__',
    email: '',
    createdAt: DateTime.utc(0),
  );
}

Future<Response> _request(
  String path,
  Map<String, Object?> body,
  Router router,
) async {
  final req = Request(
    'POST',
    Uri.parse('http://localhost$path'),
    body: jsonEncode(body),
    headers: const {'content-type': 'application/json'},
  );
  // Router.call returns FutureOr<Response>; await unwraps both.
  return router.call(req);
}

void main() {
  group('Auth routes (E6)', () {
    late _FakeUsers users;
    late Router router;

    setUp(() {
      users = _FakeUsers();
      router = buildAuthRouter(
        users: users,
        hasher: const PasswordHasher(cost: 4),
        tokens: TokenIssuer(secret: 'route-test-secret'),
      );
    });

    test('POST /signup with bad JSON returns 400 invalid_json', () async {
      final req = Request(
        'POST',
        Uri.parse('http://localhost/signup'),
        body: 'not json',
        headers: const {'content-type': 'application/json'},
      );
      final res = await router.call(req);
      expect(res.statusCode, 400);
      final body =
          jsonDecode(await res.readAsString()) as Map<String, Object?>;
      expect(body['error'], 'invalid_json');
    });

    test('POST /signup with short password returns 400', () async {
      final res = await _request(
        '/signup',
        {'email': 'a@quill', 'password': 'short'},
        router,
      );
      expect(res.statusCode, 400);
      expect(
        (jsonDecode(await res.readAsString()) as Map<String, Object?>)['error'],
        'email_or_password_invalid',
      );
    });

    test('POST /signup with valid payload returns 201 + token + user', () async {
      final res = await _request(
        '/signup',
        {'email': 'a@quill', 'password': 'correct-horse'},
        router,
      );
      expect(res.statusCode, 201);
      final body = jsonDecode(await res.readAsString()) as Map<String, dynamic>;
      expect(body['token'], isA<String>());
      expect((body['token'] as String).split('.'), hasLength(3));
      final user = body['user'] as Map<String, dynamic>;
      expect(user['email'], 'a@quill');
      // bcrypt hash never appears in the response.
      expect(jsonEncode(body), isNot(contains(r'$2')));
    });

    test('POST /signup with duplicate email returns 409 email_taken',
        () async {
      await _request(
        '/signup',
        {'email': 'a@quill', 'password': 'correct-horse'},
        router,
      );
      final res = await _request(
        '/signup',
        {'email': 'a@quill', 'password': 'other-password'},
        router,
      );
      expect(res.statusCode, 409);
      expect((jsonDecode(await res.readAsString()) as Map<String, Object?>)['error'], 'email_taken');
    });

    test('POST /signup normalises email to lowercase', () async {
      await _request(
        '/signup',
        {'email': 'Alice@Quill', 'password': 'correct-horse'},
        router,
      );
      final found = await users.findByEmail('alice@quill');
      expect(found, isNotNull);
    });

    test('POST /login with wrong password returns 401 invalid_credentials',
        () async {
      await _request(
        '/signup',
        {'email': 'a@quill', 'password': 'correct-horse'},
        router,
      );
      final res = await _request(
        '/login',
        {'email': 'a@quill', 'password': 'wrong-password'},
        router,
      );
      expect(res.statusCode, 401);
      expect(
        (jsonDecode(await res.readAsString()) as Map<String, Object?>)['error'],
        'invalid_credentials',
      );
    });

    test('POST /login with unknown email also returns 401 (no enumeration)',
        () async {
      final res = await _request(
        '/login',
        {'email': 'unknown@quill', 'password': 'any-password'},
        router,
      );
      expect(res.statusCode, 401);
      expect(
        (jsonDecode(await res.readAsString()) as Map<String, Object?>)['error'],
        'invalid_credentials',
      );
    });

    test('POST /login with correct creds returns 200 + token + user',
        () async {
      await _request(
        '/signup',
        {'email': 'a@quill', 'password': 'correct-horse'},
        router,
      );
      final res = await _request(
        '/login',
        {'email': 'a@quill', 'password': 'correct-horse'},
        router,
      );
      expect(res.statusCode, 200);
      final body = jsonDecode(await res.readAsString()) as Map<String, dynamic>;
      expect(body['token'], isA<String>());
      expect((body['user'] as Map<String, dynamic>)['email'], 'a@quill');
    });
  });
}
