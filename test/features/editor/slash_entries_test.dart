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

    test('Mention me entry routes through insertCurrentUser', () {
      final out = filterSlashEntries('me');
      expect(out, isNotEmpty);
      final e = out.firstWhere((e) => e.label == 'Mention me');
      expect(e.action, SlashAction.insertCurrentUser);
    });

    test('Random page link entry routes through insertRandomPageLink', () {
      final out = filterSlashEntries('random');
      expect(out, isNotEmpty);
      final e = out.firstWhere((e) => e.label == 'Random page link');
      expect(e.action, SlashAction.insertRandomPageLink);
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

  group('kSlashEntries registration', () {
    test('every SlashAction has at least one entry in kSlashEntries', () {
      final actions = kSlashEntries.map((e) => e.action).toSet();
      // Every enum value should be reachable from the picker. If a new
      // SlashAction is added to the enum without registering an entry,
      // this guard fires before users discover it as a silent gap.
      for (final a in SlashAction.values) {
        expect(actions.contains(a), isTrue,
            reason: 'No kSlashEntries entry registered for SlashAction.$a');
      }
    });

    test('M969/M970 numeric sort entries are reachable by keyword', () {
      // Defends the M969 ("|x|") and M970 ("first number") slash entries
      // against accidental removal during keyword-table refactors.
      final byAbs = filterSlashEntries('magnitude');
      expect(byAbs.map((e) => e.action),
          contains(SlashAction.sortLinesByAbsValue));

      final byFirst = filterSlashEntries('leading');
      expect(byFirst.map((e) => e.action),
          contains(SlashAction.sortLinesByFirstNumber));
    });
  });
}
