import 'dart:convert';

import 'package:backend/auth/tokens.dart';
import 'package:backend/auth/user.dart';
import 'package:backend/db/users.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:shelf/shelf.dart';

/// Build a shelf `Middleware` that turns `Authorization: Bearer <jwt>`
/// into a verified `User` on `request.context['user']` for downstream
/// handlers. Missing or malformed header → 401 unauthorized; verified
/// token but no longer existing user → 401 stale_session.
///
/// Usage:
/// ```dart
/// final pipeline = Pipeline()
///   .addMiddleware(logRequests())
///   .addMiddleware(requireAuth(users: ..., tokens: ...))
///   .addHandler(router.call);
/// ```
Middleware requireAuth({
  required UserRepositoryBase users,
  required TokenIssuer tokens,
}) {
  return (Handler inner) {
    return (Request request) async {
      final header = request.headers['authorization'];
      if (header == null ||
          !header.toLowerCase().startsWith('bearer ')) {
        return _err(401, 'missing_bearer_token');
      }
      final token = header.substring(7).trim();
      String userId;
      try {
        userId = tokens.verify(token);
      } on JWTExpiredException {
        return _err(401, 'token_expired');
      } on JWTException {
        return _err(401, 'invalid_token');
      }
      final user = await users.findById(userId);
      if (user == null) {
        return _err(401, 'stale_session');
      }
      return inner(request.change(context: {'user': user}));
    };
  };
}

/// Convenience getter for handlers that have been wrapped by `requireAuth`.
/// Throws StateError when called from an un-authed route — a programmer
/// error, not user input.
User currentUser(Request request) {
  final user = request.context['user'];
  if (user is! User) {
    throw StateError(
      'currentUser called from a route without requireAuth middleware',
    );
  }
  return user;
}

Response _err(int status, String code) => Response(
      status,
      body: jsonEncode({'error': code}),
      headers: const {'content-type': 'application/json'},
    );
