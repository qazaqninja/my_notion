import 'dart:convert';

import 'package:backend/auth/password.dart';
import 'package:backend/auth/tokens.dart';
import 'package:backend/db/users.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

/// Build the `/auth/...` sub-router. Caller mounts at `/auth`.
///
/// Routes:
/// - POST /auth/signup  → 201 {token, user}  | 400 bad request | 409 email taken
/// - POST /auth/login   → 200 {token, user}  | 400 bad request | 401 invalid
Router buildAuthRouter({
  required UserRepositoryBase users,
  required PasswordHasher hasher,
  required TokenIssuer tokens,
}) {
  final router = Router();

  router.post('/signup', (Request req) async {
    final body = await _readJson(req);
    if (body == null) {
      return _err(400, 'invalid_json');
    }
    final email = (body['email'] as String?)?.trim().toLowerCase();
    final password = body['password'] as String?;
    if (email == null || email.isEmpty || password == null || password.length < 8) {
      return _err(400, 'email_or_password_invalid');
    }
    try {
      final hash = hasher.hash(password);
      final user = await users.create(email: email, passwordHash: hash);
      return _ok(201, {
        'token': tokens.issue(user.id),
        'user': _publicUser(user.id, user.email, user.createdAt),
      });
    } on EmailAlreadyTakenException {
      return _err(409, 'email_taken');
    }
  });

  router.post('/login', (Request req) async {
    final body = await _readJson(req);
    if (body == null) {
      return _err(400, 'invalid_json');
    }
    final email = (body['email'] as String?)?.trim().toLowerCase();
    final password = body['password'] as String?;
    if (email == null || email.isEmpty || password == null) {
      return _err(400, 'email_or_password_missing');
    }
    final hash = await users.passwordHashOf(email);
    if (hash == null || !hasher.verify(password, hash)) {
      // Same error shape for unknown email vs wrong password — avoids
      // user-enumeration via response timing/content.
      return _err(401, 'invalid_credentials');
    }
    final user = await users.findByEmail(email);
    if (user == null) {
      // Race: deleted between hash lookup and email lookup. Treat as
      // 401 since the user effectively can't log in.
      return _err(401, 'invalid_credentials');
    }
    return _ok(200, {
      'token': tokens.issue(user.id),
      'user': _publicUser(user.id, user.email, user.createdAt),
    });
  });

  return router;
}

Map<String, dynamic> _publicUser(String id, String email, DateTime createdAt) =>
    {'id': id, 'email': email, 'created_at': createdAt.toIso8601String()};

Future<Map<String, dynamic>?> _readJson(Request req) async {
  try {
    final raw = await req.readAsString();
    if (raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return null;
    return decoded;
  } catch (_) {
    return null;
  }
}

Response _ok(int status, Map<String, dynamic> body) => Response(
      status,
      body: jsonEncode(body),
      headers: const {'content-type': 'application/json'},
    );

Response _err(int status, String code) => _ok(status, {'error': code});
