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
  });
}
