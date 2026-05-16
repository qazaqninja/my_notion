import 'package:backend/sync/frontmatter_probe.dart';
import 'package:test/test.dart';

void main() {
  group('FrontmatterProbe (E16)', () {
    const ulid = '01HX0V0000000000000000000A';

    test('empty body → no ulid, not public', () {
      final p = FrontmatterProbe.fromBody('');
      expect(p.ulid, isNull);
      expect(p.isPublic, isFalse);
    });

    test('body without frontmatter → no ulid, not public', () {
      final p = FrontmatterProbe.fromBody('just some text\n');
      expect(p.ulid, isNull);
      expect(p.isPublic, isFalse);
    });

    test('frontmatter with id: extracts the ULID', () {
      final p = FrontmatterProbe.fromBody('---\nid: $ulid\n---\nhello\n');
      expect(p.ulid, ulid);
      expect(p.isPublic, isFalse);
    });

    test('id: with quotes is unwrapped', () {
      final p = FrontmatterProbe.fromBody('---\nid: "$ulid"\n---\n');
      expect(p.ulid, ulid);
    });

    test('public: true sets isPublic', () {
      final p = FrontmatterProbe.fromBody(
        '---\nid: $ulid\npublic: true\n---\nbody',
      );
      expect(p.ulid, ulid);
      expect(p.isPublic, isTrue);
    });

    test('public: false leaves isPublic false', () {
      final p = FrontmatterProbe.fromBody(
        '---\nid: $ulid\npublic: false\n---\nbody',
      );
      expect(p.isPublic, isFalse);
    });

    test('public: yes also flips to true (Obsidian convention)', () {
      final p = FrontmatterProbe.fromBody(
        '---\nid: $ulid\npublic: yes\n---\nbody',
      );
      expect(p.isPublic, isTrue);
    });

    test('non-ULID `id:` is rejected (defensive)', () {
      final p = FrontmatterProbe.fromBody('---\nid: not-a-ulid\n---\n');
      expect(p.ulid, isNull);
    });

    test('other frontmatter keys are ignored', () {
      final p = FrontmatterProbe.fromBody(
        '---\ntitle: My note\nid: $ulid\ntags: [a, b]\n---\nbody',
      );
      expect(p.ulid, ulid);
    });

    // E43 — public_password handling.
    test('public_password: a valid bcrypt hash is captured', () {
      // Bcrypt fixture — `$2a$10$…` with 53 trailing chars. Real
      // hash, doesn't matter what plaintext it represents because
      // the probe only checks shape, not value.
      const hash =
          r'$2a$10$abcdefghijklmnopqrstuuv1234567890ABCDEFGHIJKLMNOPQRST';
      final p = FrontmatterProbe.fromBody(
        '---\nid: $ulid\npublic: true\npublic_password: $hash\n---\nbody',
      );
      expect(p.isPublic, isTrue);
      expect(p.publicPasswordHash, hash);
      expect(p.isPasswordProtected, isTrue);
    });

    test('public_password: a malformed value is ignored (defensive)', () {
      final p = FrontmatterProbe.fromBody(
        '---\nid: $ulid\npublic: true\npublic_password: not-a-bcrypt-hash\n---\n',
      );
      expect(p.publicPasswordHash, isNull);
      expect(p.isPasswordProtected, isFalse);
    });

    test('public_password without public: true is not "protected"', () {
      const hash =
          r'$2a$10$abcdefghijklmnopqrstuuv1234567890ABCDEFGHIJKLMNOPQRST';
      final p = FrontmatterProbe.fromBody(
        '---\nid: $ulid\npublic_password: $hash\n---\n',
      );
      // Hash is still parsed for completeness, but the convenience
      // helper requires both flags to be set.
      expect(p.publicPasswordHash, hash);
      expect(p.isPasswordProtected, isFalse);
    });
  });
}
