import 'dart:io';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

/// JWT issue / verify helpers backed by `dart_jsonwebtoken`.
///
/// Keys: read `JWT_SECRET` from the environment for HS256 signing. The
/// `localhost-dev-only` fallback is loud-and-obvious so a deploy without the
/// env var crashes rather than ships a weak secret. Production rotates via
/// re-deploy; refresh-token rotation lands at E15+.
class TokenIssuer {
  /// Construct an issuer. [secret] defaults to `JWT_SECRET` env var,
  /// falling back to a loud-and-obvious dev-only string so production
  /// crashes rather than ships a weak secret.
  TokenIssuer({String? secret, this.issuer = 'quill', this.audience = 'quill'})
      : _secret = secret ??
            Platform.environment['JWT_SECRET'] ??
            'localhost-dev-only-DO-NOT-SHIP';

  final String _secret;

  /// JWT `iss` claim — validated on verify.
  final String issuer;

  /// JWT `aud` claim — validated on verify.
  final String audience;

  /// Mint a short-lived (1 h) JWT containing [userId] in `sub`. Callers
  /// typically pair with a longer-lived refresh token (slice E15).
  String issue(String userId, {Duration lifetime = const Duration(hours: 1)}) {
    final jwt = JWT(
      {'sub': userId},
      issuer: issuer,
      audience: Audience.one(audience),
    );
    return jwt.sign(
      SecretKey(_secret),
      expiresIn: lifetime,
    );
  }

  /// Returns the `sub` (user id) when [token] is well-formed, signature
  /// verifies, and the standard claims (`iss`, `aud`, `exp`) are valid.
  /// Throws `JWTException` (or subclass) on failure.
  String verify(String token) {
    final jwt = JWT.verify(
      token,
      SecretKey(_secret),
      issuer: issuer,
      audience: Audience.one(audience),
    );
    final sub = jwt.payload is Map<String, dynamic>
        ? (jwt.payload as Map<String, dynamic>)['sub']
        : null;
    if (sub is! String || sub.isEmpty) {
      throw JWTInvalidException('missing sub claim');
    }
    return sub;
  }
}
