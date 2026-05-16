import 'package:backend/auth/password.dart';
import 'package:backend/auth/tokens.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:test/test.dart';

void main() {
  group('PasswordHasher (E3)', () {
    final hasher = const PasswordHasher(cost: 4); // low cost = fast tests

    test('hash produces a bcrypt modular crypt string', () {
      final h = hasher.hash('correct horse battery staple');
      expect(h, startsWith(r'$2'));
      expect(h.length, greaterThanOrEqualTo(60));
    });

    test('verify accepts the original plaintext', () {
      final h = hasher.hash('secret123');
      expect(hasher.verify('secret123', h), isTrue);
    });

    test('verify rejects the wrong plaintext', () {
      final h = hasher.hash('secret123');
      expect(hasher.verify('secret124', h), isFalse);
    });

    test('two hashes of the same input differ (random salt)', () {
      final a = hasher.hash('same');
      final b = hasher.hash('same');
      expect(a, isNot(equals(b)));
      // Both must still verify.
      expect(hasher.verify('same', a), isTrue);
      expect(hasher.verify('same', b), isTrue);
    });
  });

  group('TokenIssuer (E3)', () {
    final issuer = TokenIssuer(secret: 'unit-test-secret');

    test('issue produces a signed JWT', () {
      final tok = issuer.issue('01HABC');
      expect(tok.split('.'), hasLength(3)); // header.payload.signature
    });

    test('verify returns the sub from a freshly-issued token', () {
      final tok = issuer.issue('01HABC');
      expect(issuer.verify(tok), '01HABC');
    });

    test('verify rejects a token signed with a different secret', () {
      final otherIssuer = TokenIssuer(secret: 'attacker-key');
      final tok = otherIssuer.issue('01HABC');
      expect(() => issuer.verify(tok), throwsA(isA<JWTException>()));
    });

    test('verify rejects an expired token', () async {
      final tok = issuer.issue('01HABC',
          lifetime: const Duration(milliseconds: 1));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(() => issuer.verify(tok), throwsA(isA<JWTExpiredException>()));
    });
  });
}
