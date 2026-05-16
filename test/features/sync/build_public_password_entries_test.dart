import 'package:bcrypt/bcrypt.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/sync/domain/usecases/build_public_password_entries.dart';
import 'package:my_notion/features/vault/domain/entities/frontmatter_entry.dart';

/// E44 — exercises the pure helper that builds the `public:true` +
/// `public_password: <hash>` frontmatter pair for the "Publish with
/// password…" flow.
void main() {
  group('buildPublicPasswordEntries (E44)', () {
    test('returns public:true + public_password:<hash> entry pair', () {
      final result = buildPublicPasswordEntries('correct-horse');
      // public: true entry
      expect(result.publicFlag.key, 'public');
      expect(result.publicFlag.rawScalar, 'true');
      expect(result.publicFlag.type, FrontmatterType.checkbox);
      expect(result.publicFlag.value, true);
      // public_password: <hash>
      expect(result.passwordHash.key, 'public_password');
      expect(result.passwordHash.type, FrontmatterType.text);
      // Quoted to keep $-laden raw round-trip unambiguous.
      expect(result.passwordHash.rawScalar.startsWith('"'), isTrue);
      expect(result.passwordHash.rawScalar.endsWith('"'), isTrue);
    });

    test('hash is a valid bcrypt hash matching the chosen password', () {
      final result = buildPublicPasswordEntries('correct-horse-battery');
      final hash = result.passwordHash.value! as String;
      // Shape check.
      expect(
        RegExp(r'^\$2[abxy]\$\d{2}\$[./A-Za-z0-9]{53}$').hasMatch(hash),
        isTrue,
        reason: 'hash $hash does not look like a bcrypt hash',
      );
      // Round-trip check.
      expect(BCrypt.checkpw('correct-horse-battery', hash), isTrue);
      expect(BCrypt.checkpw('wrong-password', hash), isFalse);
    });

    test('rejects empty passwords', () {
      expect(
        () => buildPublicPasswordEntries(''),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('two calls with the same password produce different hashes', () {
      // bcrypt salts each hash differently — verify the helper doesn't
      // somehow share state and produce identical output.
      final a = buildPublicPasswordEntries('same-pw').passwordHash.value!
          as String;
      final b = buildPublicPasswordEntries('same-pw').passwordHash.value!
          as String;
      expect(a, isNot(equals(b)));
      // Both should still validate against the same plaintext.
      expect(BCrypt.checkpw('same-pw', a), isTrue);
      expect(BCrypt.checkpw('same-pw', b), isTrue);
    });
  });
}
