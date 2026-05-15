import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/editor/domain/source_line_ops.dart';

void main() {
  group('sortLinesIn', () {
    test('sorts three explicitly-selected lines ascending case-insensitive', () {
      const text = 'cherry\napple\nBanana\n';
      // Select all three lines (0..text.length).
      final r = sortLinesIn(text, 0, text.length);
      expect(r.text, 'apple\nBanana\ncherry\n');
      expect(r.selectionStart, 0);
    });

    test('widens partial selection outward to whole-line boundaries', () {
      const text = 'cherry\napple\nBanana\nDate\n';
      // Select from inside "cherry" (offset 2) to inside "Banana" (offset 15).
      final r = sortLinesIn(text, 2, 15);
      expect(r.text, 'apple\nBanana\ncherry\nDate\n');
      // Block widened to lines 0..2, which sorted is 'apple\nBanana\ncherry'
      expect(r.selectionStart, 0);
      // The trailing \n of "Banana" lives at offset 19 in the new text.
      expect(r.selectionEnd, 'apple\nBanana\ncherry'.length);
    });

    test('hi at line start excludes the next line (Notion / VS Code gesture)', () {
      const text = 'b\na\nc\n';
      // hi = 4 = start of "c". The "select two lines from top" gesture
      // should sort only "b" and "a", not include "c".
      final r = sortLinesIn(text, 0, 4);
      expect(r.text, 'a\nb\nc\n');
    });

    test('empty selection inside a line is a no-op for sorting', () {
      const text = 'beta\nalpha\n';
      // Caret at offset 2 (inside "beta"); start == end → only that line.
      final r = sortLinesIn(text, 2, 2);
      expect(r.text, text);
    });

    test('empty text is a no-op', () {
      final r = sortLinesIn('', 0, 0);
      expect(r.text, '');
      expect(r.selectionStart, 0);
      expect(r.selectionEnd, 0);
    });

    test('preserves trailing newline that sat outside the selection', () {
      const text = 'cherry\napple\n';
      // Select lines 0..1 (offsets 0 .. 12 = end of "apple", before \n).
      final r = sortLinesIn(text, 0, 12);
      expect(r.text, 'apple\ncherry\n');
    });

    test('clamps out-of-range bounds', () {
      const text = 'b\na\n';
      final r = sortLinesIn(text, -10, 999);
      expect(r.text, 'a\nb\n');
    });
  });

  group('dedupeLinesIn', () {
    test('removes consecutive duplicates keeping the first', () {
      const text = 'apple\napple\nbanana\n';
      final r = dedupeLinesIn(text, 0, text.length);
      expect(r.text, 'apple\nbanana\n');
    });

    test('removes non-consecutive duplicates keeping the first', () {
      const text = 'apple\nbanana\napple\ncherry\nbanana\n';
      final r = dedupeLinesIn(text, 0, text.length);
      expect(r.text, 'apple\nbanana\ncherry\n');
    });

    test('case-sensitive — Apple and apple are different lines', () {
      const text = 'apple\nApple\napple\n';
      final r = dedupeLinesIn(text, 0, text.length);
      expect(r.text, 'apple\nApple\n');
    });

    test('preserves the trailing newline outside the selection', () {
      const text = 'a\nb\na\n';
      // Selection covers exactly the three rows; trailing newline stays.
      final r = dedupeLinesIn(text, 0, 5);
      expect(r.text, 'a\nb\n');
    });
  });

  group('trimTrailingWhitespaceIn', () {
    test('strips trailing spaces on every line', () {
      const text = 'one  \ntwo\t\nthree   \n';
      final r = trimTrailingWhitespaceIn(text, 0, text.length);
      expect(r.text, 'one\ntwo\nthree\n');
    });

    test('leaves leading whitespace alone (it carries meaning in lists)', () {
      const text = '  - indented item   \n  more  \n';
      final r = trimTrailingWhitespaceIn(text, 0, text.length);
      expect(r.text, '  - indented item\n  more\n');
    });

    test('a line with only whitespace becomes empty', () {
      const text = 'first\n   \nthird\n';
      final r = trimTrailingWhitespaceIn(text, 0, text.length);
      expect(r.text, 'first\n\nthird\n');
    });

    test('no-op when no trailing whitespace exists', () {
      const text = 'clean\nlines\nhere\n';
      final r = trimTrailingWhitespaceIn(text, 0, text.length);
      expect(r.text, text);
    });
  });

  group('uppercaseLinesIn / lowercaseLinesIn', () {
    test('uppercaseLinesIn capitalises every selected line', () {
      const text = 'hello\nworld\n';
      expect(uppercaseLinesIn(text, 0, text.length).text, 'HELLO\nWORLD\n');
    });

    test('lowercaseLinesIn lowercases every selected line', () {
      const text = 'HELLO\nWorld\n';
      expect(lowercaseLinesIn(text, 0, text.length).text, 'hello\nworld\n');
    });

    test('uppercase then lowercase is the lowercase form', () {
      const text = 'Mixed Case Text\n';
      final up = uppercaseLinesIn(text, 0, text.length);
      final down = lowercaseLinesIn(up.text, 0, up.text.length);
      expect(down.text, 'mixed case text\n');
    });

    test('partial selection widens to whole lines', () {
      const text = 'one\ntwo\nthree\n';
      // Caret inside "two".
      final r = uppercaseLinesIn(text, 5, 5);
      expect(r.text, 'one\nTWO\nthree\n');
    });
  });

  group('titleCaseLinesIn', () {
    test('capitalises every non-small word', () {
      const text = 'hello world\n';
      expect(titleCaseLinesIn(text, 0, text.length).text, 'Hello World\n');
    });

    test('lowercases small words in the middle of a line', () {
      const text = 'the lord of the rings\n';
      // First "the" is edge so capitalised; "of" and middle "the" stay lower.
      expect(
        titleCaseLinesIn(text, 0, text.length).text,
        'The Lord of the Rings\n',
      );
    });

    test('always capitalises the first and last word', () {
      const text = 'of mice and men\n';
      // "of" is the first word, "men" is the last — both capitalise.
      expect(
        titleCaseLinesIn(text, 0, text.length).text,
        'Of Mice and Men\n',
      );
    });

    test('preserves blank lines', () {
      const text = 'hello\n\nworld\n';
      expect(
        titleCaseLinesIn(text, 0, text.length).text,
        'Hello\n\nWorld\n',
      );
    });
  });

  group('sortLinesDescIn', () {
    test('sorts three explicit lines descending case-insensitive', () {
      const text = 'apple\nBanana\ncherry\n';
      final r = sortLinesDescIn(text, 0, text.length);
      expect(r.text, 'cherry\nBanana\napple\n');
    });

    test('descending sort is the reverse of the ascending sort', () {
      const text = 'd\nA\nc\nB\n';
      final asc = sortLinesIn(text, 0, text.length).text;
      final desc = sortLinesDescIn(text, 0, text.length).text;
      // Reverse the ascending block (excluding the trailing newline)
      // and confirm it matches the descending output.
      final ascLines = asc.split('\n').where((l) => l.isNotEmpty).toList();
      final descLines = desc.split('\n').where((l) => l.isNotEmpty).toList();
      expect(descLines, ascLines.reversed.toList());
    });

    test('widens partial selection to whole-line boundaries', () {
      const text = 'apple\nBanana\ncherry\nDate\n';
      final r = sortLinesDescIn(text, 2, 15);
      // Block widens to lines 0..2; descending of {apple, Banana, cherry}
      // is cherry, Banana, apple.
      expect(r.text, 'cherry\nBanana\napple\nDate\n');
      expect(r.selectionStart, 0);
    });

    test('empty text is a no-op', () {
      final r = sortLinesDescIn('', 0, 0);
      expect(r.text, '');
    });
  });

  group('toggleBulletPrefixIn', () {
    test('adds "- " to plain lines', () {
      const text = 'apple\nbanana\ncherry\n';
      final r = toggleBulletPrefixIn(text, 0, text.length);
      expect(r.text, '- apple\n- banana\n- cherry\n');
    });

    test('strips "- " when every non-empty line is already bulleted', () {
      const text = '- apple\n- banana\n- cherry\n';
      final r = toggleBulletPrefixIn(text, 0, text.length);
      expect(r.text, 'apple\nbanana\ncherry\n');
    });

    test('toggle twice is the identity (round-trips)', () {
      const text = 'foo\nbar\nbaz\n';
      final once = toggleBulletPrefixIn(text, 0, text.length);
      final twice = toggleBulletPrefixIn(once.text, 0, once.text.length);
      expect(twice.text, text);
    });

    test('preserves leading indentation when toggling on', () {
      const text = '  foo\n  bar\n';
      final r = toggleBulletPrefixIn(text, 0, text.length);
      expect(r.text, '  - foo\n  - bar\n');
    });

    test('preserves leading indentation when toggling off', () {
      const text = '  - foo\n  - bar\n';
      final r = toggleBulletPrefixIn(text, 0, text.length);
      expect(r.text, '  foo\n  bar\n');
    });

    test('blank lines stay blank in both directions', () {
      const text = 'a\n\nb\n';
      final on = toggleBulletPrefixIn(text, 0, text.length);
      expect(on.text, '- a\n\n- b\n');
      final off = toggleBulletPrefixIn(on.text, 0, on.text.length);
      expect(off.text, text);
    });

    test('mixed lines (some bulleted, some not) → all get bulleted', () {
      const text = '- apple\nbanana\n- cherry\n';
      final r = toggleBulletPrefixIn(text, 0, text.length);
      expect(r.text, '- apple\n- banana\n- cherry\n');
    });
  });

  group('toggleTaskPrefixIn', () {
    test('adds "- [ ] " to plain lines', () {
      const text = 'one\ntwo\n';
      final r = toggleTaskPrefixIn(text, 0, text.length);
      expect(r.text, '- [ ] one\n- [ ] two\n');
    });

    test('strips when every non-empty line is already a task', () {
      const text = '- [ ] one\n- [x] two\n';
      final r = toggleTaskPrefixIn(text, 0, text.length);
      expect(r.text, 'one\ntwo\n');
    });

    test('round-trip is back to the original plain text', () {
      const text = 'alpha\nbeta\n';
      final on = toggleTaskPrefixIn(text, 0, text.length);
      final off = toggleTaskPrefixIn(on.text, 0, on.text.length);
      expect(off.text, text);
    });

    test('preserves leading indent on add', () {
      const text = '  foo\n';
      expect(toggleTaskPrefixIn(text, 0, text.length).text, '  - [ ] foo\n');
    });

    test('preserves leading indent on strip', () {
      const text = '  - [x] foo\n';
      expect(toggleTaskPrefixIn(text, 0, text.length).text, '  foo\n');
    });

    test('mixed lines → all get tasked', () {
      const text = '- [ ] one\ntwo\n- [x] three\n';
      final r = toggleTaskPrefixIn(text, 0, text.length);
      expect(r.text, '- [ ] one\n- [ ] two\n- [x] three\n');
    });

    test('blank lines stay blank both directions', () {
      const text = 'a\n\nb\n';
      final on = toggleTaskPrefixIn(text, 0, text.length);
      expect(on.text, '- [ ] a\n\n- [ ] b\n');
    });
  });

  group('toggleNumberedPrefixIn', () {
    test('adds "1. 2. 3. " to plain lines, renumbered from 1', () {
      const text = 'apple\nbanana\ncherry\n';
      final r = toggleNumberedPrefixIn(text, 0, text.length);
      expect(r.text, '1. apple\n2. banana\n3. cherry\n');
    });

    test('strips numbered prefixes when every line is numbered', () {
      const text = '1. apple\n2. banana\n3. cherry\n';
      final r = toggleNumberedPrefixIn(text, 0, text.length);
      expect(r.text, 'apple\nbanana\ncherry\n');
    });

    test('round-trips back to plain text', () {
      const text = 'one\ntwo\nthree\n';
      final on = toggleNumberedPrefixIn(text, 0, text.length);
      final off = toggleNumberedPrefixIn(on.text, 0, on.text.length);
      expect(off.text, text);
    });

    test('renumbers across mixed-numbered input', () {
      // 7. and 42. are wrong — toggle should restart at 1.
      const text = '7. apple\nbanana\n42. cherry\n';
      final r = toggleNumberedPrefixIn(text, 0, text.length);
      expect(r.text, '1. apple\n2. banana\n3. cherry\n');
    });

    test('preserves leading indent on add', () {
      const text = '  one\n  two\n';
      final r = toggleNumberedPrefixIn(text, 0, text.length);
      expect(r.text, '  1. one\n  2. two\n');
    });

    test('preserves leading indent on strip', () {
      const text = '  1. one\n  2. two\n';
      final r = toggleNumberedPrefixIn(text, 0, text.length);
      expect(r.text, '  one\n  two\n');
    });

    test('blank lines do not consume a number', () {
      const text = 'a\n\nb\n';
      final r = toggleNumberedPrefixIn(text, 0, text.length);
      expect(r.text, '1. a\n\n2. b\n');
    });

    test('strips multi-digit numbers (10., 11., …)', () {
      const text = '10. ten\n11. eleven\n';
      final r = toggleNumberedPrefixIn(text, 0, text.length);
      expect(r.text, 'ten\neleven\n');
    });
  });

  group('compareNatural', () {
    test('file2 sorts before file10', () {
      expect(compareNatural('file2', 'file10'), lessThan(0));
    });

    test('case-insensitive alpha comparison', () {
      expect(compareNatural('Apple', 'banana'), lessThan(0));
      expect(compareNatural('apple', 'Banana'), lessThan(0));
    });

    test('digit run treated as number, not lexicographic', () {
      // "2" < "10" naturally; lex would say "10" < "2".
      expect(compareNatural('2', '10'), lessThan(0));
    });

    test('equal numbers tie-break by run length (01 > 1)', () {
      // Same int value but "01" has a longer source — sort it second.
      expect(compareNatural('1', '01'), lessThan(0));
    });

    test('compares mixed segments', () {
      // v1.2 < v1.10 < v2.0
      final inputs = ['v2.0', 'v1.10', 'v1.2'];
      inputs.sort(compareNatural);
      expect(inputs, ['v1.2', 'v1.10', 'v2.0']);
    });

    test('shorter prefix-equal string sorts first', () {
      expect(compareNatural('foo', 'foobar'), lessThan(0));
    });

    test('identical strings compare equal', () {
      expect(compareNatural('abc123', 'abc123'), 0);
    });
  });

  group('sortLinesNaturalIn', () {
    test('sorts a block of file-like names naturally', () {
      const text = 'file10\nfile2\nfile1\n';
      final r = sortLinesNaturalIn(text, 0, text.length);
      expect(r.text, 'file1\nfile2\nfile10\n');
    });

    test('mixed alpha + numeric segments', () {
      const text = 'v2.0\nv1.10\nv1.2\n';
      final r = sortLinesNaturalIn(text, 0, text.length);
      expect(r.text, 'v1.2\nv1.10\nv2.0\n');
    });

    test('empty text is a no-op', () {
      expect(sortLinesNaturalIn('', 0, 0).text, '');
    });
  });

  group('toggleBlockquotePrefixIn', () {
    test('adds "> " to plain lines', () {
      const text = 'one\ntwo\n';
      final r = toggleBlockquotePrefixIn(text, 0, text.length);
      expect(r.text, '> one\n> two\n');
    });

    test('strips "> " when every non-empty line is already quoted', () {
      const text = '> alpha\n> beta\n';
      final r = toggleBlockquotePrefixIn(text, 0, text.length);
      expect(r.text, 'alpha\nbeta\n');
    });

    test('round-trips back to the original plain text', () {
      const text = 'a\nb\nc\n';
      final on = toggleBlockquotePrefixIn(text, 0, text.length);
      final off = toggleBlockquotePrefixIn(on.text, 0, on.text.length);
      expect(off.text, text);
    });

    test('preserves leading indent in both directions', () {
      const text = '  foo\n';
      final on = toggleBlockquotePrefixIn(text, 0, text.length);
      expect(on.text, '  > foo\n');
      final off = toggleBlockquotePrefixIn(on.text, 0, on.text.length);
      expect(off.text, text);
    });

    test('mixed lines → all get quoted', () {
      const text = '> alpha\nbeta\n> gamma\n';
      final r = toggleBlockquotePrefixIn(text, 0, text.length);
      expect(r.text, '> alpha\n> beta\n> gamma\n');
    });

    test('recognises only `> ` — `>>` is treated as plain and gets quoted', () {
      // The function deliberately only matches the exact `> ` prefix.
      // A `>> nested` line is plain text to this transform, so toggling
      // adds one more level. (Single-level by design.)
      const text = '>> nested\n';
      final r = toggleBlockquotePrefixIn(text, 0, text.length);
      expect(r.text, '> >> nested\n');
    });

    test('blank lines stay blank', () {
      const text = 'a\n\nb\n';
      final r = toggleBlockquotePrefixIn(text, 0, text.length);
      expect(r.text, '> a\n\n> b\n');
    });
  });

  group('shuffleLinesIn', () {
    test('seeded shuffle is deterministic', () {
      const text = 'one\ntwo\nthree\nfour\nfive\n';
      final a = shuffleLinesIn(text, 0, text.length, random: Random(42)).text;
      final b = shuffleLinesIn(text, 0, text.length, random: Random(42)).text;
      expect(a, b);
    });

    test('shuffle preserves the multiset of lines', () {
      const text = 'a\nb\nc\nd\n';
      final r = shuffleLinesIn(text, 0, text.length, random: Random(7)).text;
      final origLines = text.split('\n')..sort();
      final newLines = r.split('\n')..sort();
      expect(newLines, origLines);
    });

    test('single line is a no-op', () {
      const text = 'solo\n';
      final r = shuffleLinesIn(text, 0, text.length, random: Random(1)).text;
      expect(r, text);
    });

    test('empty text is a no-op', () {
      final r = shuffleLinesIn('', 0, 0, random: Random(1)).text;
      expect(r, '');
    });
  });

  group('slugifyLine', () {
    test('basic title', () {
      expect(slugifyLine('My Cool Title'), 'my-cool-title');
    });

    test('trailing punctuation does not leak a dash', () {
      expect(slugifyLine('Hello!'), 'hello');
    });

    test('runs of non-alphanumerics collapse to one dash', () {
      expect(slugifyLine('A — B   C…D'), 'a-b-c-d');
    });

    test('leading and trailing non-alphanumerics are stripped', () {
      expect(slugifyLine('  --hello world!!  '), 'hello-world');
    });

    test('numbers are kept', () {
      expect(slugifyLine('v1.2.3 final'), 'v1-2-3-final');
    });

    test('case-folded to lowercase', () {
      expect(slugifyLine('CamelCase'), 'camelcase');
    });

    test('empty input returns empty', () {
      expect(slugifyLine(''), '');
    });

    test('all-punctuation input collapses to empty', () {
      expect(slugifyLine('!!!---???'), '');
    });
  });

  group('slugifyLinesIn', () {
    test('slugifies every non-empty line', () {
      const text = 'My First Page\nSecond Page!!\n';
      final r = slugifyLinesIn(text, 0, text.length);
      expect(r.text, 'my-first-page\nsecond-page\n');
    });

    test('preserves blank lines', () {
      const text = 'one\n\ntwo\n';
      final r = slugifyLinesIn(text, 0, text.length);
      expect(r.text, 'one\n\ntwo\n');
    });
  });

  group('reverseLinesIn', () {
    test('flips three explicit lines', () {
      const text = 'one\ntwo\nthree\n';
      final r = reverseLinesIn(text, 0, text.length);
      expect(r.text, 'three\ntwo\none\n');
    });

    test('reversing twice is the identity', () {
      const text = 'a\nb\nc\nd\n';
      final once = reverseLinesIn(text, 0, text.length);
      final twice = reverseLinesIn(once.text, 0, once.text.length);
      expect(twice.text, text);
    });

    test('widens partial selection to whole-line boundaries', () {
      const text = 'one\ntwo\nthree\n';
      // Caret inside "two" → only that single line, reverse is a no-op.
      final r = reverseLinesIn(text, 5, 5);
      expect(r.text, text);
    });
  });
}
