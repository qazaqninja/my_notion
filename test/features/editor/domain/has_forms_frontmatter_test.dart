import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/editor/domain/has_forms_frontmatter.dart';
import 'package:my_notion/features/vault/domain/entities/frontmatter.dart';
import 'package:my_notion/features/vault/domain/entities/frontmatter_entry.dart';

void main() {
  group('hasFormsFrontmatter', () {
    test('returns false for an empty frontmatter', () {
      expect(hasFormsFrontmatter(Frontmatter.empty), isFalse);
    });

    test('returns false when no `forms:` key is present', () {
      const fm = Frontmatter(entries: [
        FrontmatterEntry(
          key: 'title',
          rawScalar: 'Notes',
          type: FrontmatterType.text,
          value: 'Notes',
        ),
      ]);
      expect(hasFormsFrontmatter(fm), isFalse);
    });

    test('returns true when `forms:` is a non-empty wikilink scalar', () {
      // Mirrors the legacy editor_page.dart `_hasForms` and backend
      // `FrontmatterProbe.hasForms` rule — any non-empty string after
      // trim qualifies.
      const fm = Frontmatter(entries: [
        FrontmatterEntry(
          key: 'forms',
          rawScalar: '[[01HX0VEY5T6K7R9X4Y8Z0A3D4G]]',
          type: FrontmatterType.text,
          value: '[[01HX0VEY5T6K7R9X4Y8Z0A3D4G]]',
        ),
      ]);
      expect(hasFormsFrontmatter(fm), isTrue);
    });

    test('returns false when `forms:` is an empty string', () {
      const fm = Frontmatter(entries: [
        FrontmatterEntry(
          key: 'forms',
          rawScalar: '',
          type: FrontmatterType.text,
          value: '',
        ),
      ]);
      expect(hasFormsFrontmatter(fm), isFalse);
    });

    test('returns false when `forms:` is whitespace-only', () {
      // Match the legacy `'$v'.trim().isNotEmpty` — pure spaces or tabs
      // shouldn't count.
      const fm = Frontmatter(entries: [
        FrontmatterEntry(
          key: 'forms',
          rawScalar: '   ',
          type: FrontmatterType.text,
          value: '   ',
        ),
      ]);
      expect(hasFormsFrontmatter(fm), isFalse);
    });

    test('returns true when `forms:` value is non-string but non-empty', () {
      // The legacy `'$v'.trim().isNotEmpty` would coerce any non-null
      // value to its string form; preserving that lets a future schema
      // change (e.g. ULID list) still register as form-bearing.
      const fm = Frontmatter(entries: [
        FrontmatterEntry(
          key: 'forms',
          rawScalar: '42',
          type: FrontmatterType.number,
          value: 42,
        ),
      ]);
      expect(hasFormsFrontmatter(fm), isTrue);
    });
  });
}
