import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/editor/domain/slash_entries.dart';

void main() {
  group('filterSlashEntries', () {
    test('empty query returns all entries', () {
      expect(filterSlashEntries(''), equals(kSlashEntries));
    });

    test('matches by label substring', () {
      final out = filterSlashEntries('to-do');
      expect(out, isNotEmpty);
      expect(out.first.label, equals('To-do'));
    });

    test('matches by keyword (case-insensitive)', () {
      final out = filterSlashEntries('katex');
      expect(out.map((e) => e.label),
          containsAll(['Inline math', 'Math block']));
    });

    test('no matches returns empty list', () {
      expect(filterSlashEntries('xyzzy'), isEmpty);
    });

    test('"h" matches all three heading levels', () {
      final out = filterSlashEntries('h');
      // Three headings, plus other labels containing 'h'.
      expect(out.where((e) => e.label.startsWith('Heading')).length, 3);
    });
  });

  group('SlashEntry.caretAfterInsert', () {
    test('default = end of snippet', () {
      const e = SlashEntry(
          icon: 'x', label: 'x', hint: '', snippet: 'hello');
      expect(e.caretAfterInsert(0), 5);
      expect(e.caretAfterInsert(10), 15);
    });

    test('explicit cursorOffset positions cursor inside snippet', () {
      const e = SlashEntry(
          icon: 'x',
          label: 'x',
          hint: '',
          snippet: '```\n\n```\n',
          cursorOffset: 4);
      expect(e.caretAfterInsert(0), 4);
      expect(e.caretAfterInsert(10), 14);
    });
  });
}
