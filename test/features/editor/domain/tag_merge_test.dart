import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/editor/domain/tag_merge.dart';
import 'package:my_notion/features/vault/domain/entities/frontmatter_entry.dart';

FrontmatterEntry _entry(Object? value, {String rawScalar = ''}) =>
    FrontmatterEntry(
      key: 'tags',
      rawScalar: rawScalar,
      type: FrontmatterType.multi,
      value: value,
    );

void main() {
  group('readExistingTags', () {
    test('returns [] when the entry is null', () {
      expect(readExistingTags(null), <String>[]);
    });

    test('reads a single-item String value', () {
      // Legacy `tags: draft` (a bare YAML string, no flow list)
      // surfaces as a String at parse time. Trim + non-empty.
      expect(readExistingTags(_entry('draft')), ['draft']);
    });

    test('treats an all-whitespace String as empty', () {
      // Defensive: `tags: "   "` is effectively no tags.
      expect(readExistingTags(_entry('   ')), <String>[]);
    });

    test('reads a List<dynamic> value, trimming + dropping empties', () {
      expect(
        readExistingTags(_entry(<dynamic>['draft', '  pinned  ', '', 'urgent'])),
        ['draft', 'pinned', 'urgent'],
      );
    });

    test('returns [] for an unsupported value type (non-String non-List)', () {
      // `tags: 42` is invalid frontmatter but the helper shouldn't
      // throw — drop silently.
      expect(readExistingTags(_entry(42)), <String>[]);
    });
  });

  group('mergeTags', () {
    test('returns the additions as both merged + actuallyNew when no current',
        () {
      final r = mergeTags(current: const [], added: const ['draft', 'urgent']);
      expect(r.merged, ['draft', 'urgent']);
      expect(r.actuallyNew, ['draft', 'urgent']);
    });

    test('appends genuinely new tags after the current ones', () {
      final r = mergeTags(
        current: const ['draft', 'pinned'],
        added: const ['urgent'],
      );
      expect(r.merged, ['draft', 'pinned', 'urgent']);
      expect(r.actuallyNew, ['urgent']);
    });

    test('drops exact-case duplicates of existing tags', () {
      final r = mergeTags(
        current: const ['draft'],
        added: const ['draft', 'urgent'],
      );
      expect(r.merged, ['draft', 'urgent']);
      expect(r.actuallyNew, ['urgent']);
    });

    test('drops case-insensitive duplicates, preserving the original casing',
        () {
      // M786: re-adding "Draft" when "draft" is already on the page
      // is a no-op rather than double-listing the same tag with two
      // casings. The kept entry keeps its original casing.
      final r = mergeTags(
        current: const ['draft'],
        added: const ['DRAFT', 'urgent'],
      );
      expect(r.merged, ['draft', 'urgent']);
      expect(r.actuallyNew, ['urgent']);
    });

    test('dedupes within the added list itself when the input repeats', () {
      // If the user types `foo, foo, bar` the helper should still
      // emit ['foo', 'bar'], not ['foo', 'foo', 'bar'].
      final r = mergeTags(
        current: const [],
        added: const ['foo', 'foo', 'bar', 'BAR'],
      );
      expect(r.merged, ['foo', 'bar']);
      expect(r.actuallyNew, ['foo', 'bar']);
    });

    test('actuallyNew is empty when every added tag was already present', () {
      final r = mergeTags(
        current: const ['draft', 'urgent'],
        added: const ['draft', 'URGENT'],
      );
      expect(r.merged, ['draft', 'urgent']);
      expect(r.actuallyNew, <String>[]);
    });

    test('preserves the order of the added list across genuinely-new entries',
        () {
      final r = mergeTags(
        current: const ['alpha'],
        added: const ['gamma', 'beta'],
      );
      expect(r.merged, ['alpha', 'gamma', 'beta']);
      expect(r.actuallyNew, ['gamma', 'beta']);
    });
  });

  group('addedTagsLabel', () {
    test('1 added tag uses singular', () {
      expect(addedTagsLabel(1), 'Added 1 tag');
    });

    test('2+ added tags uses plural', () {
      expect(addedTagsLabel(2), 'Added 2 tags');
      expect(addedTagsLabel(42), 'Added 42 tags');
    });

    test('0 added tags uses plural (matches the family convention)', () {
      // Mirrors the project-wide plural-for-zero choice used by
      // wordGoalLabel, copiedCharsLabel.
      expect(addedTagsLabel(0), 'Added 0 tags');
    });
  });
}
