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

    test('ranks label-prefix matches before substring matches', () {
      // "co" prefixes "Code block" and "Two columns" has "columns" keyword;
      // the code block entry should rank above it.
      final out = filterSlashEntries('co');
      expect(out, isNotEmpty);
      expect(out.first.label, 'Code block');
    });

    test('Button entry is present and inserts a :::button fence', () {
      final out = filterSlashEntries('button');
      expect(out, isNotEmpty);
      final btn = out.firstWhere((e) => e.label == 'Button');
      expect(btn.snippet, startsWith(':::button'));
      expect(btn.snippet, contains('action:'));
      expect(btn.snippet, endsWith(':::\n'));
    });

    test('Emoji entry routes through SlashAction.pickEmoji', () {
      final out = filterSlashEntries('emoji');
      expect(out, isNotEmpty);
      final em = out.firstWhere((e) => e.label == 'Emoji…');
      expect(em.action, SlashAction.pickEmoji);
    });

    test('Lorem ipsum entry inserts three placeholder paragraphs', () {
      final out = filterSlashEntries('lorem');
      expect(out, isNotEmpty);
      final lipsum = out.firstWhere((e) => e.label == 'Lorem ipsum');
      // Three paragraphs separated by blank lines.
      expect(
          '\n\n'.allMatches(lipsum.snippet).length, greaterThanOrEqualTo(2));
      expect(lipsum.snippet, startsWith('Lorem ipsum dolor'));
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
