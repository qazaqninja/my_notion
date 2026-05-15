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

  group('sentenceCaseLinesIn', () {
    test('lowercases SHOUTING and capitalises the first letter', () {
      const text = 'HELLO WORLD\n';
      expect(
        sentenceCaseLinesIn(text, 0, text.length).text,
        'Hello world\n',
      );
    });

    test('capitalises after a period + space', () {
      const text = 'hello world. how are you? fine!\n';
      expect(
        sentenceCaseLinesIn(text, 0, text.length).text,
        'Hello world. How are you? Fine!\n',
      );
    });

    test('handles MiXeD CaSe sources by lowering first', () {
      const text = 'aLpHa BeTa\n';
      expect(
        sentenceCaseLinesIn(text, 0, text.length).text,
        'Alpha beta\n',
      );
    });

    test('re-capitalises the pronoun I', () {
      const text = 'whatever i think\n';
      expect(
        sentenceCaseLinesIn(text, 0, text.length).text,
        'Whatever I think\n',
      );
    });

    test('preserves blank lines', () {
      const text = 'hello\n\nworld\n';
      expect(
        sentenceCaseLinesIn(text, 0, text.length).text,
        'Hello\n\nWorld\n',
      );
    });

    test('non-alpha first character does not eat the capital', () {
      // After leading punctuation/whitespace, the next alpha still
      // gets capitalised.
      const text = '   hello world\n';
      expect(
        sentenceCaseLinesIn(text, 0, text.length).text,
        '   Hello world\n',
      );
    });
  });

  group('stripLeadingWhitespaceIn', () {
    test('strips leading spaces on every line', () {
      const text = '  one\n    two\n      three\n';
      final r = stripLeadingWhitespaceIn(text, 0, text.length);
      expect(r.text, 'one\ntwo\nthree\n');
    });

    test('strips leading tabs too', () {
      const text = '\tone\n\t\ttwo\n';
      final r = stripLeadingWhitespaceIn(text, 0, text.length);
      expect(r.text, 'one\ntwo\n');
    });

    test('leaves trailing whitespace alone', () {
      const text = '  one  \n';
      final r = stripLeadingWhitespaceIn(text, 0, text.length);
      expect(r.text, 'one  \n');
    });

    test('no-op when nothing leads', () {
      const text = 'clean\nlines\n';
      final r = stripLeadingWhitespaceIn(text, 0, text.length);
      expect(r.text, text);
    });
  });

  group('tabsToSpacesIn', () {
    test('replaces tabs with 2 spaces by default', () {
      const text = '\tone\n\t\ttwo\n';
      final r = tabsToSpacesIn(text, 0, text.length);
      expect(r.text, '  one\n    two\n');
    });

    test('configurable width', () {
      const text = '\tone\n';
      expect(tabsToSpacesIn(text, 0, text.length, width: 4).text, '    one\n');
    });

    test('replaces tabs anywhere on the line, not just leading', () {
      const text = 'foo\tbar\tbaz\n';
      final r = tabsToSpacesIn(text, 0, text.length);
      expect(r.text, 'foo  bar  baz\n');
    });

    test('no-op when there are no tabs', () {
      const text = 'no tabs here\n';
      final r = tabsToSpacesIn(text, 0, text.length);
      expect(r.text, text);
    });
  });

  group('spacesToTabsIn', () {
    test('converts a 2-space indent into one tab (default)', () {
      const text = '  one\n    two\n';
      final r = spacesToTabsIn(text, 0, text.length);
      expect(r.text, '\tone\n\t\ttwo\n');
    });

    test('configurable width', () {
      const text = '    one\n';
      expect(spacesToTabsIn(text, 0, text.length, width: 4).text, '\tone\n');
    });

    test('leftover spaces (not a full multiple) stay as spaces', () {
      // 3 leading spaces with width 2 → 1 tab + 1 leftover space.
      const text = '   foo\n';
      expect(spacesToTabsIn(text, 0, text.length).text, '\t foo\n');
    });

    test('leaves mid-line and trailing spaces alone', () {
      const text = '  one two   \n';
      final r = spacesToTabsIn(text, 0, text.length);
      expect(r.text, '\tone two   \n');
    });

    test('round-trip indent-only file is identity', () {
      const text = '\tfoo\n\t\tbar\n';
      final asSpaces = tabsToSpacesIn(text, 0, text.length).text;
      final back = spacesToTabsIn(asSpaces, 0, asSpaces.length).text;
      expect(back, text);
    });

    test('no-op when there is no leading whitespace', () {
      const text = 'plain\nstuff\n';
      expect(spacesToTabsIn(text, 0, text.length).text, text);
    });
  });

  group('decimalToRoman / romanToDecimal', () {
    test('basic decimal → roman', () {
      expect(decimalToRoman(1), 'I');
      expect(decimalToRoman(4), 'IV');
      expect(decimalToRoman(9), 'IX');
      expect(decimalToRoman(40), 'XL');
      expect(decimalToRoman(90), 'XC');
      expect(decimalToRoman(400), 'CD');
      expect(decimalToRoman(900), 'CM');
      expect(decimalToRoman(1994), 'MCMXCIV');
      expect(decimalToRoman(3999), 'MMMCMXCIX');
    });

    test('out-of-range returns empty', () {
      expect(decimalToRoman(0), '');
      expect(decimalToRoman(-3), '');
      expect(decimalToRoman(4000), '');
    });

    test('basic roman → decimal', () {
      expect(romanToDecimal('I'), 1);
      expect(romanToDecimal('IV'), 4);
      expect(romanToDecimal('IX'), 9);
      expect(romanToDecimal('LVIII'), 58);
      expect(romanToDecimal('MCMXCIV'), 1994);
    });

    test('accepts mixed case', () {
      expect(romanToDecimal('mcmxciv'), 1994);
      expect(romanToDecimal('McMxCiV'), 1994);
    });

    test('non-roman returns null', () {
      expect(romanToDecimal('hello'), isNull);
      expect(romanToDecimal('123'), isNull);
      expect(romanToDecimal(''), isNull);
    });

    test('round-trips for 1..3999 sample', () {
      for (final n in [1, 7, 14, 49, 99, 500, 888, 1234, 3000, 3999]) {
        final r = decimalToRoman(n);
        expect(romanToDecimal(r), n, reason: 'round-trip for $n via $r');
      }
    });
  });

  group('convertDecimalToRomanLinesIn / convertRomanToDecimalLinesIn', () {
    test('converts only numeric lines, leaves others untouched', () {
      const text = '1\nhello\n7\nworld\n';
      final r = convertDecimalToRomanLinesIn(text, 0, text.length);
      expect(r.text, 'I\nhello\nVII\nworld\n');
    });

    test('reverse: converts only roman lines', () {
      const text = 'I\nhello\nVII\nworld\n';
      final r = convertRomanToDecimalLinesIn(text, 0, text.length);
      expect(r.text, '1\nhello\n7\nworld\n');
    });

    test('decimal-roman-decimal round-trip is identity for numeric lines', () {
      const text = '1\n7\n42\n3999\n';
      final asRoman = convertDecimalToRomanLinesIn(text, 0, text.length).text;
      final back = convertRomanToDecimalLinesIn(asRoman, 0, asRoman.length).text;
      expect(back, text);
    });

    test('out-of-range decimals stay untouched', () {
      const text = '0\n4000\n7\n';
      final r = convertDecimalToRomanLinesIn(text, 0, text.length);
      expect(r.text, '0\n4000\nVII\n');
    });
  });

  group('smartTypography', () {
    test('opens and closes double quotes by context', () {
      expect(smartTypography('"hello"'), '“hello”');
    });

    test('opens and closes single quotes', () {
      expect(smartTypography("'hello'"), '‘hello’');
    });

    test('contraction apostrophe is a right-single', () {
      // "don't" → "don’t" (right single after letter)
      expect(smartTypography("don't"), 'don’t');
    });

    test('em-dash and ellipsis are substituted', () {
      expect(smartTypography('a -- b'), 'a — b');
      expect(smartTypography('to be... or not'), 'to be… or not');
    });

    test('quote after opening bracket is opening', () {
      expect(smartTypography('("yes")'), '(“yes”)');
    });

    test('no-op on text without ASCII typography', () {
      expect(smartTypography('plain text'), 'plain text');
    });
  });

  group('dumbifyTypography (inverse)', () {
    test('reverts smart quotes to ASCII', () {
      expect(dumbifyTypography('“hello”'), '"hello"');
    });

    test('reverts ellipsis and em-dash', () {
      expect(dumbifyTypography('a — b… c'), 'a -- b... c');
    });

    test('smart → dumb round-trip preserves the original ASCII', () {
      // No fancy chars in source, conversion + revert is identity.
      const ascii = '"hello" "world"';
      final smart = smartTypography(ascii);
      expect(dumbifyTypography(smart), ascii);
    });
  });

  group('smartTypographyIn / dumbifyTypographyIn', () {
    test('applies per-line transformation', () {
      const text = '"a"\n"b"\n';
      final r = smartTypographyIn(text, 0, text.length);
      expect(r.text, '“a”\n“b”\n');
    });

    test('dumbify works per-line too', () {
      const text = '“a”\n“b”\n';
      final r = dumbifyTypographyIn(text, 0, text.length);
      expect(r.text, '"a"\n"b"\n');
    });
  });

  group('base64EncodeLinesIn / base64DecodeLinesIn', () {
    test('encodes each line as UTF-8 base64', () {
      const text = 'hello\nworld\n';
      final r = base64EncodeLinesIn(text, 0, text.length);
      expect(r.text, 'aGVsbG8=\nd29ybGQ=\n');
    });

    test('round-trip is identity for ASCII lines', () {
      const text = 'foo\nbar\nbaz\n';
      final enc = base64EncodeLinesIn(text, 0, text.length).text;
      final dec = base64DecodeLinesIn(enc, 0, enc.length).text;
      expect(dec, text);
    });

    test('round-trip is identity for multibyte UTF-8 lines', () {
      const text = '你好\n🚀 rocket\n';
      final enc = base64EncodeLinesIn(text, 0, text.length).text;
      final dec = base64DecodeLinesIn(enc, 0, enc.length).text;
      expect(dec, text);
    });

    test('decode leaves non-base64 lines untouched', () {
      const text = 'not base64\nalso plain\n';
      final r = base64DecodeLinesIn(text, 0, text.length);
      expect(r.text, text);
    });

    test('decode preserves blank lines', () {
      const text = '';
      expect(base64DecodeLinesIn(text, 0, 0).text, text);
    });

    test('encode preserves blank lines', () {
      const text = 'a\n\nb\n';
      final r = base64EncodeLinesIn(text, 0, text.length);
      expect(r.text, 'YQ==\n\nYg==\n');
    });
  });

  group('urlEncodeLinesIn / urlDecodeLinesIn', () {
    test('encodes spaces and reserved chars', () {
      const text = 'hello world\nfoo/bar?baz=1\n';
      final r = urlEncodeLinesIn(text, 0, text.length);
      expect(r.text, 'hello%20world\nfoo%2Fbar%3Fbaz%3D1\n');
    });

    test('round-trip ASCII line preserves it', () {
      const text = 'a b c\nx=y&z\n';
      final enc = urlEncodeLinesIn(text, 0, text.length).text;
      final dec = urlDecodeLinesIn(enc, 0, enc.length).text;
      expect(dec, text);
    });

    test('round-trip multibyte UTF-8 line preserves it', () {
      const text = 'café 🍰\n你好\n';
      final enc = urlEncodeLinesIn(text, 0, text.length).text;
      final dec = urlDecodeLinesIn(enc, 0, enc.length).text;
      expect(dec, text);
    });

    test('decode leaves malformed lines untouched', () {
      // Lone "%" without 2 hex chars is malformed.
      const text = '50% off\n';
      final r = urlDecodeLinesIn(text, 0, text.length);
      expect(r.text, text);
    });

    test('encode preserves blank lines', () {
      const text = 'a\n\nb\n';
      final r = urlEncodeLinesIn(text, 0, text.length);
      expect(r.text, text);
    });
  });

  group('convertDecimalToHexLinesIn / convertHexToDecimalLinesIn', () {
    test('decimal → hex with 0x prefix and lowercase', () {
      const text = '255\n0\n4096\n';
      final r = convertDecimalToHexLinesIn(text, 0, text.length);
      expect(r.text, '0xff\n0x0\n0x1000\n');
    });

    test('hex → decimal accepts both 0x and bare hex with letters', () {
      const text = '0xff\nFF\n0x1000\n';
      final r = convertHexToDecimalLinesIn(text, 0, text.length);
      expect(r.text, '255\n255\n4096\n');
    });

    test('bare decimal digits stay as-is on hex→decimal pass', () {
      // "42" without a 0x prefix and without [a-f] letters is decimal.
      // Without this guard it'd parse as hex 0x42 = 66, masking user intent.
      const text = '42\n';
      final r = convertHexToDecimalLinesIn(text, 0, text.length);
      expect(r.text, text);
    });

    test('non-numeric lines are left untouched', () {
      const text = 'hello\nworld\n';
      expect(
        convertDecimalToHexLinesIn(text, 0, text.length).text,
        text,
      );
      expect(
        convertHexToDecimalLinesIn(text, 0, text.length).text,
        text,
      );
    });

    test('round-trip preserves numeric values', () {
      const text = '0\n255\n4096\n65535\n';
      final asHex = convertDecimalToHexLinesIn(text, 0, text.length).text;
      final back = convertHexToDecimalLinesIn(asHex, 0, asHex.length).text;
      expect(back, text);
    });

    test('negative decimals stay untouched', () {
      const text = '-5\n';
      expect(convertDecimalToHexLinesIn(text, 0, text.length).text, text);
    });
  });

  group('reverseCharactersInLineIn', () {
    test('reverses characters on each line independently', () {
      const text = 'hello\nworld\n';
      final r = reverseCharactersInLineIn(text, 0, text.length);
      expect(r.text, 'olleh\ndlrow\n');
    });

    test('palindromes are invariant', () {
      const text = 'racecar\n';
      expect(reverseCharactersInLineIn(text, 0, text.length).text, text);
    });

    test('double-reverse is identity', () {
      const text = 'one\ntwo\nthree\n';
      final once = reverseCharactersInLineIn(text, 0, text.length);
      final twice = reverseCharactersInLineIn(once.text, 0, once.text.length);
      expect(twice.text, text);
    });
  });

  group('rot13 / rot13LinesIn', () {
    test('rot13 rotates lowercase a..z by 13', () {
      expect(rot13('abc'), 'nop');
      expect(rot13('hello'), 'uryyb');
    });

    test('rot13 rotates uppercase preserving case', () {
      expect(rot13('Hello, World!'), 'Uryyb, Jbeyq!');
    });

    test('non-letters pass through unchanged', () {
      expect(rot13('1234 / "abc"'), '1234 / "nop"');
    });

    test('rot13 is its own inverse', () {
      const s = 'The quick brown fox jumps over the lazy dog.';
      expect(rot13(rot13(s)), s);
    });

    test('rot13LinesIn applies per line', () {
      const text = 'abc\nxyz\n';
      final r = rot13LinesIn(text, 0, text.length);
      expect(r.text, 'nop\nklm\n');
    });
  });

  group('htmlEscapeLinesIn / htmlUnescapeLinesIn', () {
    test('escapes the five standard entities', () {
      const text = '<b>"a & b"</b>\n';
      final r = htmlEscapeLinesIn(text, 0, text.length);
      expect(r.text, '&lt;b&gt;&quot;a &amp; b&quot;&lt;/b&gt;\n');
    });

    test("escapes apostrophes as numeric &#39;", () {
      const text = "don't\n";
      final r = htmlEscapeLinesIn(text, 0, text.length);
      expect(r.text, 'don&#39;t\n');
    });

    test('& must escape before the others', () {
      // Naive ordering would emit "&amp;lt;" — verify we don't.
      const text = '<\n';
      expect(htmlEscapeLinesIn(text, 0, text.length).text, '&lt;\n');
    });

    test('round-trip on the five-entity sample is identity', () {
      const text = '<b>"a & b" don\'t</b>\n';
      final enc = htmlEscapeLinesIn(text, 0, text.length).text;
      final dec = htmlUnescapeLinesIn(enc, 0, enc.length).text;
      expect(dec, text);
    });

    test('unescape recognises &apos; for compatibility', () {
      const text = 'don&apos;t\n';
      expect(htmlUnescapeLinesIn(text, 0, text.length).text, "don't\n");
    });

    test('no-op on lines without entities', () {
      const text = 'plain text\n';
      expect(htmlEscapeLinesIn(text, 0, text.length).text, text);
      expect(htmlUnescapeLinesIn(text, 0, text.length).text, text);
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
