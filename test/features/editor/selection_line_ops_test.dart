import 'dart:convert';
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

  group('stripMarkdownEmphasisLinesIn', () {
    test('strips bold + italic + strike + highlight + code', () {
      const text = '**bold** _italic_ ~~strike~~ ==hi== `code`\n';
      final r = stripMarkdownEmphasisLinesIn(text, 0, text.length);
      expect(r.text, 'bold italic strike hi code\n');
    });

    test('peels nested ***both*** into plain inner text', () {
      const text = '***both***\n';
      final r = stripMarkdownEmphasisLinesIn(text, 0, text.length);
      expect(r.text, 'both\n');
    });

    test('plain prose with no markers is the identity', () {
      const text = 'hello world\nno markup here\n';
      expect(stripMarkdownEmphasisLinesIn(text, 0, text.length).text, text);
    });

    test('unmatched single markers pass through', () {
      // No closing `*` → no transform on this line.
      const text = '*lonely\nstays *the same*\n';
      final r = stripMarkdownEmphasisLinesIn(text, 0, text.length);
      expect(r.text, '*lonely\nstays the same\n');
    });

    test('does not unwrap links or images', () {
      // Links carry semantic info (the URL) and have a dedicated slash
      // entry already — leave them alone.
      const text = '[label](http://example.com) **bold**\n';
      final r = stripMarkdownEmphasisLinesIn(text, 0, text.length);
      expect(r.text, '[label](http://example.com) bold\n');
    });

    test('empty input stays empty', () {
      expect(stripMarkdownEmphasisLinesIn('', 0, 0).text, '');
    });
  });

  group('swapCaseLinesIn', () {
    test('inverts upper/lower case per character', () {
      const text = 'Hello World\n';
      expect(swapCaseLinesIn(text, 0, text.length).text, 'hELLO wORLD\n');
    });

    test('non-cased characters pass through', () {
      // Digits, punctuation, whitespace and symbols stay put.
      const text = 'aB1 c-D 42!\n';
      expect(swapCaseLinesIn(text, 0, text.length).text, 'Ab1 C-d 42!\n');
    });

    test('double-application is the identity for ASCII input', () {
      const text = 'The QUICK brown Fox.\n';
      final once = swapCaseLinesIn(text, 0, text.length);
      final twice = swapCaseLinesIn(once.text, 0, once.text.length);
      expect(twice.text, text);
    });

    test('non-Latin scripts without casing pass through unchanged', () {
      // CJK ideographs and digits have no case.
      const text = '日本 2026\n';
      expect(swapCaseLinesIn(text, 0, text.length).text, text);
    });

    test('empty input stays empty', () {
      expect(swapCaseLinesIn('', 0, 0).text, '');
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

  group('convertDecimalToBinaryLinesIn / convertBinaryToDecimalLinesIn', () {
    test('decimal → binary with 0b prefix', () {
      const text = '5\n255\n0\n';
      final r = convertDecimalToBinaryLinesIn(text, 0, text.length);
      expect(r.text, '0b101\n0b11111111\n0b0\n');
    });

    test('binary → decimal needs 0b prefix', () {
      const text = '0b101\n0b11111111\n0b0\n';
      final r = convertBinaryToDecimalLinesIn(text, 0, text.length);
      expect(r.text, '5\n255\n0\n');
    });

    test('bare 1s and 0s without 0b prefix stay as-is', () {
      // 1010 could be decimal 1010 or binary 10 — we leave it alone.
      const text = '1010\n0101\n';
      expect(
        convertBinaryToDecimalLinesIn(text, 0, text.length).text,
        text,
      );
    });

    test('non-numeric lines stay untouched in both directions', () {
      const text = 'hello\nworld\n';
      expect(
        convertDecimalToBinaryLinesIn(text, 0, text.length).text,
        text,
      );
      expect(
        convertBinaryToDecimalLinesIn(text, 0, text.length).text,
        text,
      );
    });

    test('round-trip preserves the numeric values', () {
      const text = '0\n5\n42\n255\n1024\n';
      final asBin = convertDecimalToBinaryLinesIn(text, 0, text.length).text;
      final back = convertBinaryToDecimalLinesIn(asBin, 0, asBin.length).text;
      expect(back, text);
    });

    test('negative decimals stay untouched on decimal→binary', () {
      const text = '-3\n';
      expect(
        convertDecimalToBinaryLinesIn(text, 0, text.length).text,
        text,
      );
    });
  });

  group('zeroPadLinesIn', () {
    test('auto width: pads all lines to the longest in the block', () {
      const text = '5\n50\n500\n';
      final r = zeroPadLinesIn(text, 0, text.length);
      expect(r.text, '005\n050\n500\n');
    });

    test('explicit width pads up to that width', () {
      const text = '5\n50\n';
      final r = zeroPadLinesIn(text, 0, text.length, width: 4);
      expect(r.text, '0005\n0050\n');
    });

    test('lines longer than the width pass through unchanged', () {
      const text = '5\n500000\n';
      final r = zeroPadLinesIn(text, 0, text.length, width: 4);
      expect(r.text, '0005\n500000\n');
    });

    test('zero-pad lets numeric lines sort lexicographically', () {
      // Without padding: "5" > "50" lex. With padding: "005" < "050".
      const text = '5\n50\n500\n';
      final padded = zeroPadLinesIn(text, 0, text.length).text;
      final lines = padded.split('\n').where((l) => l.isNotEmpty).toList()
        ..sort();
      expect(lines, ['005', '050', '500']);
    });

    test('blank lines stay blank', () {
      const text = '1\n\n22\n';
      final r = zeroPadLinesIn(text, 0, text.length);
      expect(r.text, '01\n\n22\n');
    });

    test('empty input is a no-op', () {
      expect(zeroPadLinesIn('', 0, 0).text, '');
    });
  });

  group('padRightLinesIn', () {
    test('auto width pads all lines to the longest length with spaces', () {
      const text = 'a\nbb\nccc\n';
      final r = padRightLinesIn(text, 0, text.length);
      expect(r.text, 'a  \nbb \nccc\n');
    });

    test('explicit width pads even past the longest line', () {
      const text = 'a\nbb\n';
      final r = padRightLinesIn(text, 0, text.length, width: 5);
      expect(r.text, 'a    \nbb   \n');
    });

    test('lines already at or above width pass unchanged', () {
      const text = 'short\nverylonger\n';
      final r = padRightLinesIn(text, 0, text.length, width: 3);
      expect(r.text, text);
    });

    test('blank lines stay blank', () {
      const text = 'a\n\nbb\n';
      final r = padRightLinesIn(text, 0, text.length);
      expect(r.text, 'a \n\nbb\n');
    });

    test('empty input is a no-op', () {
      expect(padRightLinesIn('', 0, 0).text, '');
    });
  });

  group('textStats / formatTextStats', () {
    test('empty body returns all-zero stats', () {
      final s = textStats('');
      expect(s.words, 0);
      expect(s.chars, 0);
      expect(s.lines, 0);
    });

    test('single line counts words and chars', () {
      final s = textStats('hello world');
      expect(s.words, 2);
      expect(s.chars, 11);
      expect(s.lines, 1);
    });

    test('multiple lines count non-blank lines only', () {
      final s = textStats('one\n\ntwo\nthree\n');
      expect(s.lines, 3);
      expect(s.words, 3);
    });

    test('multi-space runs collapse to one word boundary', () {
      final s = textStats('one    two\tthree\nfour');
      expect(s.words, 4);
    });

    test('formatTextStats renders the human summary', () {
      expect(
        formatTextStats((words: 5, chars: 23, lines: 2)),
        '(5 words · 23 characters · 2 lines)',
      );
    });

    test('formatTextStats handles zero values', () {
      expect(
        formatTextStats((words: 0, chars: 0, lines: 0)),
        '(0 words · 0 characters · 0 lines)',
      );
    });
  });

  group('sortLinesByLengthIn / sortLinesByLengthDescIn', () {
    test('ascending: shortest first', () {
      const text = 'banana\napple\nblueberry\n';
      final r = sortLinesByLengthIn(text, 0, text.length);
      expect(r.text, 'apple\nbanana\nblueberry\n');
    });

    test('descending: longest first', () {
      const text = 'banana\napple\nblueberry\n';
      final r = sortLinesByLengthDescIn(text, 0, text.length);
      expect(r.text, 'blueberry\nbanana\napple\n');
    });

    test('equal-length tie-break is case-insensitive lex', () {
      // Same length, sort alpha — "Bee" < "ant" because "Bee".lower < "ant".lower? No.
      // "ant" < "bee" → ascending puts "ant" first.
      const text = 'bee\nant\ncat\n';
      final r = sortLinesByLengthIn(text, 0, text.length);
      expect(r.text, 'ant\nbee\ncat\n');
    });

    test('asc-then-desc returns the same multiset', () {
      const text = 'one\nthree\ntwo\nfour\n';
      final asc = sortLinesByLengthIn(text, 0, text.length).text;
      final desc = sortLinesByLengthDescIn(asc, 0, asc.length).text;
      final ascLines = asc.split('\n').where((l) => l.isNotEmpty).toList();
      final descLines = desc.split('\n').where((l) => l.isNotEmpty).toList();
      expect(descLines.toSet(), ascLines.toSet());
    });
  });

  group('sortLinesByAbsValueIn', () {
    test('ascending by magnitude across signs', () {
      const text = '-5\n2\n-1\n3\n';
      final r = sortLinesByAbsValueIn(text, 0, text.length);
      expect(r.text, '-1\n2\n3\n-5\n');
    });

    test('non-numeric lines pushed to the bottom in original order', () {
      const text = 'banana\n-3\napple\n1\n';
      final r = sortLinesByAbsValueIn(text, 0, text.length);
      expect(r.text, '1\n-3\nbanana\napple\n');
    });

    test('all-numeric matches abs(x) ordering', () {
      const text = '1.5\n-2\n0\n-0.5\n';
      final r = sortLinesByAbsValueIn(text, 0, text.length);
      expect(r.text, '0\n-0.5\n1.5\n-2\n');
    });

    test('empty input stays empty', () {
      final r = sortLinesByAbsValueIn('', 0, 0);
      expect(r.text, '');
    });
  });

  group('sortLinesByFirstNumberIn', () {
    test('sorts log-like lines by the leading bracket score', () {
      const text = '[42] beta\n[7] alpha\n[100] gamma\n';
      final r = sortLinesByFirstNumberIn(text, 0, text.length);
      expect(r.text, '[7] alpha\n[42] beta\n[100] gamma\n');
    });

    test('first number wins even when buried mid-line', () {
      const text = 'alpha 50\nbeta 10\ngamma 30\n';
      final r = sortLinesByFirstNumberIn(text, 0, text.length);
      expect(r.text, 'beta 10\ngamma 30\nalpha 50\n');
    });

    test('signed leading numbers sort numerically', () {
      const text = '-3°C Monday\n12°C Tuesday\n-15°C Wednesday\n';
      final r = sortLinesByFirstNumberIn(text, 0, text.length);
      expect(r.text, '-15°C Wednesday\n-3°C Monday\n12°C Tuesday\n');
    });

    test('lines without numbers fall to the bottom in original order', () {
      const text = 'banana\nv1 release\napple\nv9 release\n';
      final r = sortLinesByFirstNumberIn(text, 0, text.length);
      expect(r.text, 'v1 release\nv9 release\nbanana\napple\n');
    });

    test('empty input stays empty', () {
      final r = sortLinesByFirstNumberIn('', 0, 0);
      expect(r.text, '');
    });
  });

  group('sortLinesByWordCountIn', () {
    test('orders bullets shortest-first by word count', () {
      const text = 'one two three\nalpha\nbeta gamma\n';
      final r = sortLinesByWordCountIn(text, 0, text.length);
      expect(r.text, 'alpha\nbeta gamma\none two three\n');
    });

    test('equal-count lines fall back to case-insensitive lex', () {
      const text = 'beta gamma\nAlpha Delta\nApple Pie\n';
      final r = sortLinesByWordCountIn(text, 0, text.length);
      expect(r.text, 'Alpha Delta\nApple Pie\nbeta gamma\n');
    });

    test('blank lines count as zero words and float to the top', () {
      const text = 'one two\n\nthree four five\n';
      final r = sortLinesByWordCountIn(text, 0, text.length);
      expect(r.text, '\none two\nthree four five\n');
    });

    test('runs of whitespace collapse to a single word boundary', () {
      // Three spaces between tokens still count as 2 words, not 4.
      const text = 'a   b\nc d e f\n';
      final r = sortLinesByWordCountIn(text, 0, text.length);
      expect(r.text, 'a   b\nc d e f\n');
    });

    test('empty input stays empty', () {
      final r = sortLinesByWordCountIn('', 0, 0);
      expect(r.text, '');
    });
  });

  group('reverseWordsInLineIn', () {
    test('flips two-word lines', () {
      const text = 'hello world\n';
      final r = reverseWordsInLineIn(text, 0, text.length);
      expect(r.text, 'world hello\n');
    });

    test('flips multi-word lines', () {
      const text = 'one two three four\n';
      final r = reverseWordsInLineIn(text, 0, text.length);
      expect(r.text, 'four three two one\n');
    });

    test('double-reverse on a single-space line is identity', () {
      const text = 'alpha beta gamma\n';
      final once = reverseWordsInLineIn(text, 0, text.length);
      final twice = reverseWordsInLineIn(once.text, 0, once.text.length);
      expect(twice.text, text);
    });

    test('blank lines stay blank', () {
      const text = 'one\n\ntwo three\n';
      final r = reverseWordsInLineIn(text, 0, text.length);
      expect(r.text, 'one\n\nthree two\n');
    });

    test('single-word line is invariant', () {
      const text = 'solo\n';
      expect(reverseWordsInLineIn(text, 0, text.length).text, text);
    });
  });

  group('centerLinesIn', () {
    test('auto width: centers each line within the longest', () {
      const text = 'a\nbbb\nccccc\n';
      // Target = 5. "a" gets 2/2, "bbb" gets 1/1, "ccccc" passes through.
      final r = centerLinesIn(text, 0, text.length);
      expect(r.text, '  a  \n bbb \nccccc\n');
    });

    test('odd remainder puts the extra space on the right', () {
      const text = 'abc\n';
      // Target 4: pad=1, left=0, right=1.
      final r = centerLinesIn(text, 0, text.length, width: 4);
      expect(r.text, 'abc \n');
    });

    test('lines at-or-above width pass through unchanged', () {
      const text = 'too-long-line\n';
      final r = centerLinesIn(text, 0, text.length, width: 5);
      expect(r.text, text);
    });

    test('blank lines stay blank', () {
      // Target = 'bb'.length = 2. 'a' has pad=1, extra goes right.
      const text = 'a\n\nbb\n';
      final r = centerLinesIn(text, 0, text.length);
      expect(r.text, 'a \n\nbb\n');
    });

    test('empty input is a no-op', () {
      expect(centerLinesIn('', 0, 0).text, '');
    });
  });

  group('joinLinesWithCommaIn / splitOnCommaIn', () {
    test('joins three lines into a single comma-separated row', () {
      const text = 'apple\nbanana\ncherry\n';
      final r = joinLinesWithCommaIn(text, 0, text.length);
      expect(r.text, 'apple, banana, cherry\n');
    });

    test('trims whitespace around each joined cell', () {
      const text = '  apple  \nbanana\n  cherry\n';
      final r = joinLinesWithCommaIn(text, 0, text.length);
      expect(r.text, 'apple, banana, cherry\n');
    });

    test('splits a single CSV row into multiple lines', () {
      const text = 'apple, banana, cherry\n';
      final r = splitOnCommaIn(text, 0, text.length);
      expect(r.text, 'apple\nbanana\ncherry\n');
    });

    test('split→join round-trip is identity for trimmed cells', () {
      const text = 'a, b, c\n';
      final exploded = splitOnCommaIn(text, 0, text.length).text;
      final back = joinLinesWithCommaIn(exploded, 0, exploded.length).text;
      expect(back, text);
    });

    test('split leaves no-comma lines untouched', () {
      const text = 'no comma here\n';
      expect(splitOnCommaIn(text, 0, text.length).text, text);
    });

    test('join with no non-blank lines is a no-op', () {
      const text = '\n\n\n';
      expect(joinLinesWithCommaIn(text, 0, text.length).text, text);
    });
  });

  group('toSnakeCase / snakeCaseLinesIn', () {
    test('basic title to snake', () {
      expect(toSnakeCase('My Cool Title'), 'my_cool_title');
    });

    test('preserves numbers', () {
      expect(toSnakeCase('v1.2.3 final'), 'v1_2_3_final');
    });

    test('collapses runs to single underscore', () {
      expect(toSnakeCase('A — B   C…D'), 'a_b_c_d');
    });

    test('strips outer punctuation', () {
      expect(toSnakeCase('  --hello world!!  '), 'hello_world');
    });

    test('all-punctuation returns empty', () {
      expect(toSnakeCase('!!!---'), '');
    });

    test('per-line transform skips blanks', () {
      const text = 'My Cool\n\nv1.2 final\n';
      final r = snakeCaseLinesIn(text, 0, text.length);
      expect(r.text, 'my_cool\n\nv1_2_final\n');
    });
  });

  group('toCamelCase / camelCaseLinesIn', () {
    test('basic title to camel', () {
      expect(toCamelCase('My Cool Title'), 'myCoolTitle');
    });

    test('snake source converts cleanly', () {
      expect(toCamelCase('hello_world'), 'helloWorld');
    });

    test('numbers stay in their word', () {
      expect(toCamelCase('v1.2.3 final'), 'v123Final');
    });

    test('empty / all-punctuation returns empty', () {
      expect(toCamelCase(''), '');
      expect(toCamelCase('!!!---'), '');
    });

    test('single word stays lowercase', () {
      expect(toCamelCase('Solo'), 'solo');
    });

    test('per-line transform skips blanks', () {
      const text = 'My Cool\n\nfoo_bar\n';
      final r = camelCaseLinesIn(text, 0, text.length);
      expect(r.text, 'myCool\n\nfooBar\n');
    });
  });

  group('toPascalCase / pascalCaseLinesIn', () {
    test('basic title to Pascal', () {
      expect(toPascalCase('my cool title'), 'MyCoolTitle');
    });

    test('snake source converts cleanly', () {
      expect(toPascalCase('hello_world'), 'HelloWorld');
    });

    test('numbers stay in their word', () {
      expect(toPascalCase('v1.2.3 final'), 'V123Final');
    });

    test('empty / all-punctuation returns empty', () {
      expect(toPascalCase(''), '');
      expect(toPascalCase('!!!---'), '');
    });

    test('single word capitalises first letter', () {
      expect(toPascalCase('solo'), 'Solo');
    });

    test('per-line transform skips blanks', () {
      const text = 'my cool\n\nfoo_bar\n';
      final r = pascalCaseLinesIn(text, 0, text.length);
      expect(r.text, 'MyCool\n\nFooBar\n');
    });
  });

  group('toConstantCase / constantCaseLinesIn', () {
    test('basic title to CONSTANT', () {
      expect(toConstantCase('my cool title'), 'MY_COOL_TITLE');
    });

    test('mirrors uppercased snake form', () {
      expect(toConstantCase('hello-world'), 'HELLO_WORLD');
      expect(toConstantCase('hello_world'), 'HELLO_WORLD');
    });

    test('preserves numbers', () {
      expect(toConstantCase('v1.2.3 final'), 'V1_2_3_FINAL');
    });

    test('empty / all-punctuation returns empty', () {
      expect(toConstantCase(''), '');
      expect(toConstantCase('!!!---'), '');
    });

    test('per-line transform skips blanks', () {
      const text = 'my cool\n\nfoo bar\n';
      final r = constantCaseLinesIn(text, 0, text.length);
      expect(r.text, 'MY_COOL\n\nFOO_BAR\n');
    });
  });

  group('convertDecimalToOctalLinesIn / convertOctalToDecimalLinesIn', () {
    test('decimal → octal with 0o prefix', () {
      const text = '8\n64\n0\n';
      final r = convertDecimalToOctalLinesIn(text, 0, text.length);
      expect(r.text, '0o10\n0o100\n0o0\n');
    });

    test('octal → decimal requires 0o prefix', () {
      const text = '0o10\n0o100\n0o0\n';
      final r = convertOctalToDecimalLinesIn(text, 0, text.length);
      expect(r.text, '8\n64\n0\n');
    });

    test('bare digits without 0o prefix stay as-is on octal→decimal', () {
      // "10" without 0o is decimal — leave alone, don't silently
      // reinterpret as octal 8.
      const text = '10\n';
      expect(
        convertOctalToDecimalLinesIn(text, 0, text.length).text,
        text,
      );
    });

    test('non-octal digits (8, 9) inside 0o prefix are rejected', () {
      // 0o89 is not valid octal.
      const text = '0o89\n';
      expect(
        convertOctalToDecimalLinesIn(text, 0, text.length).text,
        text,
      );
    });

    test('round-trip preserves numeric values', () {
      const text = '0\n7\n64\n4095\n';
      final asOct = convertDecimalToOctalLinesIn(text, 0, text.length).text;
      final back = convertOctalToDecimalLinesIn(asOct, 0, asOct.length).text;
      expect(back, text);
    });

    test('negative decimals stay untouched on decimal→octal', () {
      const text = '-5\n';
      expect(
        convertDecimalToOctalLinesIn(text, 0, text.length).text,
        text,
      );
    });
  });

  group('boldLinesIn / italicLinesIn / codeLinesIn', () {
    test('wraps non-blank lines in ** ** ** for bold', () {
      const text = 'foo\nbar\n';
      final r = boldLinesIn(text, 0, text.length);
      expect(r.text, '**foo**\n**bar**\n');
    });

    test('wraps non-blank lines in * * * for italic', () {
      const text = 'foo\nbar\n';
      final r = italicLinesIn(text, 0, text.length);
      expect(r.text, '*foo*\n*bar*\n');
    });

    test('wraps non-blank lines in backticks for code', () {
      const text = 'foo\nbar\n';
      final r = codeLinesIn(text, 0, text.length);
      expect(r.text, '`foo`\n`bar`\n');
    });

    test('blank lines stay blank for all three wrappers', () {
      const text = 'a\n\nb\n';
      expect(boldLinesIn(text, 0, text.length).text, '**a**\n\n**b**\n');
      expect(italicLinesIn(text, 0, text.length).text, '*a*\n\n*b*\n');
      expect(codeLinesIn(text, 0, text.length).text, '`a`\n\n`b`\n');
    });

    test('empty input is a no-op for all three', () {
      expect(boldLinesIn('', 0, 0).text, '');
      expect(italicLinesIn('', 0, 0).text, '');
      expect(codeLinesIn('', 0, 0).text, '');
    });
  });

  group('strikethroughLinesIn / highlightLinesIn', () {
    test('wraps non-blank lines in ~~ ~~ for strikethrough', () {
      const text = 'foo\nbar\n';
      final r = strikethroughLinesIn(text, 0, text.length);
      expect(r.text, '~~foo~~\n~~bar~~\n');
    });

    test('wraps non-blank lines in == == for highlight', () {
      const text = 'foo\nbar\n';
      final r = highlightLinesIn(text, 0, text.length);
      expect(r.text, '==foo==\n==bar==\n');
    });

    test('blank lines stay blank for both wrappers', () {
      const text = 'a\n\nb\n';
      expect(
        strikethroughLinesIn(text, 0, text.length).text,
        '~~a~~\n\n~~b~~\n',
      );
      expect(
        highlightLinesIn(text, 0, text.length).text,
        '==a==\n\n==b==\n',
      );
    });

    test('empty input is a no-op for both', () {
      expect(strikethroughLinesIn('', 0, 0).text, '');
      expect(highlightLinesIn('', 0, 0).text, '');
    });
  });

  group('unwrapInlineFormattingLinesIn', () {
    test('strips bold wrapper', () {
      const text = '**a**\n**b**\n';
      expect(
        unwrapInlineFormattingLinesIn(text, 0, text.length).text,
        'a\nb\n',
      );
    });

    test('strips italic wrapper', () {
      const text = '*a*\n*b*\n';
      expect(
        unwrapInlineFormattingLinesIn(text, 0, text.length).text,
        'a\nb\n',
      );
    });

    test('strips code wrapper', () {
      const text = '`a`\n`b`\n';
      expect(
        unwrapInlineFormattingLinesIn(text, 0, text.length).text,
        'a\nb\n',
      );
    });

    test('strips strikethrough wrapper', () {
      const text = '~~a~~\n~~b~~\n';
      expect(
        unwrapInlineFormattingLinesIn(text, 0, text.length).text,
        'a\nb\n',
      );
    });

    test('strips highlight wrapper', () {
      const text = '==a==\n==b==\n';
      expect(
        unwrapInlineFormattingLinesIn(text, 0, text.length).text,
        'a\nb\n',
      );
    });

    test('strips bold preferentially over italic on **x**', () {
      // `**x**` could lex as `*` + `*x*` + `*` if we went short-first.
      // The pair list places bold ahead of italic, so the full
      // wrapper is removed at once.
      const text = '**hi**\n';
      expect(
        unwrapInlineFormattingLinesIn(text, 0, text.length).text,
        'hi\n',
      );
    });

    test('repeated invocation steps nested wrappers outward', () {
      // `**~~x~~**` → after one pass `~~x~~`, after two `x`.
      const text = '**~~x~~**\n';
      final once = unwrapInlineFormattingLinesIn(text, 0, text.length).text;
      expect(once, '~~x~~\n');
      final twice = unwrapInlineFormattingLinesIn(once, 0, once.length).text;
      expect(twice, 'x\n');
    });

    test('non-wrapped lines pass through untouched', () {
      const text = 'plain text\n';
      expect(
        unwrapInlineFormattingLinesIn(text, 0, text.length).text,
        text,
      );
    });
  });

  group('generatePassword', () {
    test('defaults to 16-char output', () {
      expect(generatePassword(random: Random(1)).length, 16);
    });

    test('explicit length is honoured', () {
      expect(generatePassword(length: 32, random: Random(1)).length, 32);
    });

    test('seeded calls are deterministic', () {
      final a = generatePassword(random: Random(42));
      final b = generatePassword(random: Random(42));
      expect(a, b);
    });

    test('length 0 returns the empty string', () {
      expect(generatePassword(length: 0, random: Random(1)), '');
    });

    test('characters are drawn from the documented pool', () {
      final pw = generatePassword(length: 200, random: Random(99));
      final pool = RegExp(r'[A-Za-z0-9!@#$%^&*()\-_=+\[\]{}<>?]');
      for (final c in pw.split('')) {
        expect(pool.hasMatch(c), isTrue, reason: 'unexpected glyph "$c"');
      }
    });
  });

  group('generateUuidV4', () {
    test('returns a 36-character hyphenated string', () {
      final id = generateUuidV4(random: Random(1));
      expect(id.length, 36);
      expect(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$').hasMatch(id), isTrue,
          reason: 'shape: $id');
    });

    test('version nibble is forced to 4', () {
      final id = generateUuidV4(random: Random(123));
      // Position 14 (0-indexed) is the version digit, right after the
      // third hyphen at position 13.
      expect(id[14], '4');
    });

    test('variant nibble matches RFC 4122 (8, 9, a, or b)', () {
      final id = generateUuidV4(random: Random(123));
      // Position 19 is the variant digit, right after the fourth hyphen.
      expect(['8', '9', 'a', 'b'].contains(id[19]), isTrue,
          reason: 'variant nibble: ${id[19]} in $id');
    });

    test('seeded calls are deterministic', () {
      final a = generateUuidV4(random: Random(42));
      final b = generateUuidV4(random: Random(42));
      expect(a, b);
    });

    test('different seeds produce different UUIDs', () {
      final a = generateUuidV4(random: Random(1));
      final b = generateUuidV4(random: Random(2));
      expect(a, isNot(equals(b)));
    });
  });

  group('urlsToMarkdownLinksIn', () {
    test('wraps http URLs', () {
      const text = 'http://example.com/path\n';
      final r = urlsToMarkdownLinksIn(text, 0, text.length);
      expect(
        r.text,
        '[http://example.com/path](http://example.com/path)\n',
      );
    });

    test('wraps https URLs', () {
      const text = 'https://example.com\n';
      final r = urlsToMarkdownLinksIn(text, 0, text.length);
      expect(r.text, '[https://example.com](https://example.com)\n');
    });

    test('wraps www. URLs without scheme', () {
      const text = 'www.example.com\n';
      final r = urlsToMarkdownLinksIn(text, 0, text.length);
      expect(r.text, '[www.example.com](www.example.com)\n');
    });

    test('non-URL lines pass through unchanged', () {
      const text = 'hello world\nnot a url\n';
      final r = urlsToMarkdownLinksIn(text, 0, text.length);
      expect(r.text, text);
    });

    test('preserves leading and trailing whitespace', () {
      const text = '  http://example.com  \n';
      final r = urlsToMarkdownLinksIn(text, 0, text.length);
      expect(
        r.text,
        '  [http://example.com](http://example.com)  \n',
      );
    });

    test('handles a mixed block — some URLs, some prose', () {
      const text = 'first link:\nhttp://a.com\nsecond link:\nhttps://b.com\n';
      final r = urlsToMarkdownLinksIn(text, 0, text.length);
      expect(
        r.text,
        'first link:\n[http://a.com](http://a.com)\nsecond link:\n[https://b.com](https://b.com)\n',
      );
    });
  });

  group('generateHexColor', () {
    test('returns a 7-char #RRGGBB string', () {
      final hex = generateHexColor(random: Random(1));
      expect(hex.length, 7);
      expect(hex[0], '#');
      expect(RegExp(r'^#[0-9A-F]{6}$').hasMatch(hex), isTrue,
          reason: 'shape: $hex');
    });

    test('seeded calls are deterministic', () {
      final a = generateHexColor(random: Random(42));
      final b = generateHexColor(random: Random(42));
      expect(a, b);
    });

    test('pads short values to 6 hex digits', () {
      // Seed where the integer is small (e.g., < 0x100000) so the
      // raw radix string is shorter than 6 chars. Verify the pad.
      // We can't easily force the small value without knowing the
      // Random's internals, so just sample many seeds and check
      // every output has 6 digits after `#`.
      for (var seed = 0; seed < 50; seed++) {
        final hex = generateHexColor(random: Random(seed));
        expect(hex.length, 7, reason: 'seed $seed → $hex');
      }
    });
  });

  group('csvLinesToMarkdownTableIn', () {
    test('basic conversion: header + body', () {
      const text = 'apple, banana, cherry\n1, 2, 3\n4, 5, 6\n';
      final r = csvLinesToMarkdownTableIn(text, 0, text.length);
      expect(
        r.text,
        '| apple | banana | cherry |\n'
        '| --- | --- | --- |\n'
        '| 1 | 2 | 3 |\n'
        '| 4 | 5 | 6 |\n',
      );
    });

    test('trims each cell', () {
      const text = '  a  ,  b  \n1,2\n';
      final r = csvLinesToMarkdownTableIn(text, 0, text.length);
      expect(
        r.text,
        '| a | b |\n'
        '| --- | --- |\n'
        '| 1 | 2 |\n',
      );
    });

    test('pads short rows to the widest column count', () {
      const text = 'a, b, c\n1\n2, 3\n';
      final r = csvLinesToMarkdownTableIn(text, 0, text.length);
      expect(
        r.text,
        '| a | b | c |\n'
        '| --- | --- | --- |\n'
        '| 1 |  |  |\n'
        '| 2 | 3 |  |\n',
      );
    });

    test('drops blank lines from the body', () {
      const text = 'a, b\n\n1, 2\n';
      final r = csvLinesToMarkdownTableIn(text, 0, text.length);
      expect(
        r.text,
        '| a | b |\n| --- | --- |\n| 1 | 2 |\n',
      );
    });

    test('empty input is a no-op', () {
      expect(csvLinesToMarkdownTableIn('', 0, 0).text, '');
    });
  });

  group('markdownTableToCsvLinesIn', () {
    test('extracts data rows, drops the divider', () {
      const text = '| apple | banana |\n'
          '| --- | --- |\n'
          '| 1 | 2 |\n'
          '| 3 | 4 |\n';
      final r = markdownTableToCsvLinesIn(text, 0, text.length);
      expect(r.text, 'apple, banana\n1, 2\n3, 4\n');
    });

    test('round-trip CSV → table → CSV preserves the data', () {
      const text = 'a, b\n1, 2\n3, 4\n';
      final asTable = csvLinesToMarkdownTableIn(text, 0, text.length).text;
      final back = markdownTableToCsvLinesIn(asTable, 0, asTable.length).text;
      expect(back, text);
    });

    test('handles colon-aligned dividers (`:---:`, `:---`, `---:`)', () {
      const text = '| a | b |\n'
          '|:---:|:---|\n'
          '| 1 | 2 |\n';
      final r = markdownTableToCsvLinesIn(text, 0, text.length);
      expect(r.text, 'a, b\n1, 2\n');
    });

    test('non-table lines pass through', () {
      const text = 'just prose\nstill prose\n';
      final r = markdownTableToCsvLinesIn(text, 0, text.length);
      expect(r.text, text);
    });

    test('empty input is a no-op', () {
      expect(markdownTableToCsvLinesIn('', 0, 0).text, '');
    });
  });

  group('demoteHeadingsIn / promoteHeadingsIn', () {
    test('demote bumps each heading one level deeper', () {
      const text = '# H1\n## H2\n##### H5\n';
      final r = demoteHeadingsIn(text, 0, text.length);
      expect(r.text, '## H1\n### H2\n###### H5\n');
    });

    test('demote leaves H6 unchanged (cap)', () {
      const text = '###### h6\n';
      expect(demoteHeadingsIn(text, 0, text.length).text, text);
    });

    test('promote bumps each heading one level shallower', () {
      const text = '## H2\n### H3\n###### H6\n';
      final r = promoteHeadingsIn(text, 0, text.length);
      expect(r.text, '# H2\n## H3\n##### H6\n');
    });

    test('promote leaves H1 unchanged (cap)', () {
      const text = '# h1\n';
      expect(promoteHeadingsIn(text, 0, text.length).text, text);
    });

    test('non-heading lines pass through both transforms', () {
      const text = 'plain text\nstill plain\n';
      expect(demoteHeadingsIn(text, 0, text.length).text, text);
      expect(promoteHeadingsIn(text, 0, text.length).text, text);
    });

    test('demote then promote is identity for H2–H5', () {
      const text = '## H2\n### H3\n#### H4\n##### H5\n';
      final demoted = demoteHeadingsIn(text, 0, text.length).text;
      final back = promoteHeadingsIn(demoted, 0, demoted.length).text;
      expect(back, text);
    });

    test('requires the space after # — `#hash` is not a heading', () {
      const text = '#hashtag\n';
      expect(demoteHeadingsIn(text, 0, text.length).text, text);
    });
  });

  group('collapseSpacesIn', () {
    test('collapses internal runs of spaces to one', () {
      const text = 'a   b    c\nd  e\n';
      final r = collapseSpacesIn(text, 0, text.length);
      expect(r.text, 'a b c\nd e\n');
    });

    test('collapses internal tabs and mixed tab/space runs', () {
      const text = 'a\t\tb\nc \t d\n';
      final r = collapseSpacesIn(text, 0, text.length);
      expect(r.text, 'a b\nc d\n');
    });

    test('preserves leading whitespace (list indent etc.)', () {
      const text = '  - item   one\n';
      final r = collapseSpacesIn(text, 0, text.length);
      expect(r.text, '  - item one\n');
    });

    test('single-space runs pass through', () {
      const text = 'a b c\n';
      expect(collapseSpacesIn(text, 0, text.length).text, text);
    });

    test('empty input is a no-op', () {
      expect(collapseSpacesIn('', 0, 0).text, '');
    });
  });

  group('collapseBlankLinesIn / dropBlankLinesIn', () {
    test('collapse keeps one blank between 2+ consecutive blanks', () {
      const text = 'a\n\n\n\nb\n';
      final r = collapseBlankLinesIn(text, 0, text.length);
      expect(r.text, 'a\n\nb\n');
    });

    test('collapse leaves single blanks alone', () {
      const text = 'a\n\nb\n';
      expect(collapseBlankLinesIn(text, 0, text.length).text, text);
    });

    test('drop removes every blank line', () {
      const text = 'a\n\n\nb\n\nc\n';
      final r = dropBlankLinesIn(text, 0, text.length);
      expect(r.text, 'a\nb\nc\n');
    });

    test('drop is a no-op when there are no blank lines', () {
      const text = 'a\nb\nc\n';
      expect(dropBlankLinesIn(text, 0, text.length).text, text);
    });

    test('whitespace-only lines are treated as blank', () {
      const text = 'a\n   \n\t\nb\n';
      expect(collapseBlankLinesIn(text, 0, text.length).text, 'a\n   \nb\n');
      expect(dropBlankLinesIn(text, 0, text.length).text, 'a\nb\n');
    });

    test('empty input is a no-op for both', () {
      expect(collapseBlankLinesIn('', 0, 0).text, '');
      expect(dropBlankLinesIn('', 0, 0).text, '');
    });
  });

  group('commentLinesIn / uncommentLinesIn', () {
    test('comment prefixes every non-blank line', () {
      const text = 'one\ntwo\n';
      final r = commentLinesIn(text, 0, text.length);
      expect(r.text, '// one\n// two\n');
    });

    test('comment preserves blank lines', () {
      const text = 'a\n\nb\n';
      final r = commentLinesIn(text, 0, text.length);
      expect(r.text, '// a\n\n// b\n');
    });

    test('uncomment strips `// ` from each commented line', () {
      const text = '// one\n// two\n';
      final r = uncommentLinesIn(text, 0, text.length);
      expect(r.text, 'one\ntwo\n');
    });

    test('uncomment handles `//foo` (no space)', () {
      const text = '//foo\n';
      expect(uncommentLinesIn(text, 0, text.length).text, 'foo\n');
    });

    test('uncomment passes through non-commented lines', () {
      const text = 'plain\n';
      expect(uncommentLinesIn(text, 0, text.length).text, text);
    });

    test('comment then uncomment is identity', () {
      const text = 'one\ntwo\nthree\n';
      final commented = commentLinesIn(text, 0, text.length).text;
      final back = uncommentLinesIn(commented, 0, commented.length).text;
      expect(back, text);
    });
  });

  group('htmlCommentLinesIn / htmlUncommentLinesIn', () {
    test('wraps each non-blank line', () {
      const text = 'one\ntwo\n';
      final r = htmlCommentLinesIn(text, 0, text.length);
      expect(r.text, '<!-- one -->\n<!-- two -->\n');
    });

    test('preserves blank lines', () {
      const text = 'a\n\nb\n';
      final r = htmlCommentLinesIn(text, 0, text.length);
      expect(r.text, '<!-- a -->\n\n<!-- b -->\n');
    });

    test('uncomment strips the wrapper', () {
      const text = '<!-- one -->\n<!-- two -->\n';
      final r = htmlUncommentLinesIn(text, 0, text.length);
      expect(r.text, 'one\ntwo\n');
    });

    test('uncomment handles no-space form', () {
      const text = '<!--foo-->\n';
      expect(htmlUncommentLinesIn(text, 0, text.length).text, 'foo\n');
    });

    test('uncomment passes through non-wrapped lines', () {
      const text = 'plain\n';
      expect(htmlUncommentLinesIn(text, 0, text.length).text, text);
    });

    test('comment then uncomment is identity', () {
      const text = 'one\ntwo\nthree\n';
      final c = htmlCommentLinesIn(text, 0, text.length).text;
      expect(htmlUncommentLinesIn(c, 0, c.length).text, text);
    });
  });

  group('date / time formatters', () {
    test('formatTodayPill emits @YYYY-MM-DD', () {
      final when = DateTime(2026, 5, 16);
      expect(formatTodayPill(when), '@2026-05-16');
    });

    test('formatTodayPill zero-pads single-digit months and days', () {
      final when = DateTime(2026, 1, 3);
      expect(formatTodayPill(when), '@2026-01-03');
    });

    test('formatTimestamp emits YYYY-MM-DD HH:MM', () {
      final when = DateTime(2026, 5, 16, 14, 23);
      expect(formatTimestamp(when), '2026-05-16 14:23');
    });

    test('formatTimestamp zero-pads single-digit times', () {
      final when = DateTime(2026, 5, 16, 4, 5);
      expect(formatTimestamp(when), '2026-05-16 04:05');
    });

    test('formatIsoDateTime emits YYYY-MM-DDTHH:MM:SS', () {
      final when = DateTime(2026, 5, 16, 14, 23, 45);
      expect(formatIsoDateTime(when), '2026-05-16T14:23:45');
    });

    test('formatIsoDateTime zero-pads seconds', () {
      final when = DateTime(2026, 5, 16, 14, 23, 7);
      expect(formatIsoDateTime(when), '2026-05-16T14:23:07');
    });

    test('formatEpochTimestamp matches millisecondsSinceEpoch ÷ 1000', () {
      final when = DateTime.fromMillisecondsSinceEpoch(1_747_345_200_000);
      expect(formatEpochTimestamp(when), '1747345200');
    });

    test('formatEpochTimestamp truncates sub-second precision', () {
      final when = DateTime.fromMillisecondsSinceEpoch(1_747_345_200_999);
      expect(formatEpochTimestamp(when), '1747345200');
    });
  });

  group('renumberListLinesIn', () {
    test('renumbers a numbered block from 1', () {
      const text = '7. apple\n42. banana\n3. cherry\n';
      final r = renumberListLinesIn(text, 0, text.length);
      expect(r.text, '1. apple\n2. banana\n3. cherry\n');
    });

    test('non-numbered lines pass through', () {
      const text = '1. apple\nintro\n2. banana\n';
      final r = renumberListLinesIn(text, 0, text.length);
      // Non-numbered line in the middle keeps the renumbering going.
      expect(r.text, '1. apple\nintro\n2. banana\n');
    });

    test('preserves leading indent', () {
      const text = '  5. one\n  9. two\n';
      final r = renumberListLinesIn(text, 0, text.length);
      expect(r.text, '  1. one\n  2. two\n');
    });

    test('blank lines do not consume a number', () {
      const text = '5. one\n\n7. two\n';
      final r = renumberListLinesIn(text, 0, text.length);
      expect(r.text, '1. one\n\n2. two\n');
    });

    test('non-list block is a no-op', () {
      const text = 'plain\nprose\n';
      expect(renumberListLinesIn(text, 0, text.length).text, text);
    });
  });

  group('quoteLinesIn / unquoteLinesIn', () {
    test('quote wraps non-blank lines', () {
      const text = 'apple\nbanana\n';
      final r = quoteLinesIn(text, 0, text.length);
      expect(r.text, '"apple"\n"banana"\n');
    });

    test('quote preserves blanks', () {
      const text = 'a\n\nb\n';
      final r = quoteLinesIn(text, 0, text.length);
      expect(r.text, '"a"\n\n"b"\n');
    });

    test('unquote strips paired outer quotes', () {
      const text = '"apple"\n"banana"\n';
      final r = unquoteLinesIn(text, 0, text.length);
      expect(r.text, 'apple\nbanana\n');
    });

    test('unquote leaves single-sided quotes alone', () {
      const text = '"foo\n';
      expect(unquoteLinesIn(text, 0, text.length).text, text);
    });

    test('unquote leaves lines with no outer quotes alone', () {
      const text = 'plain\n';
      expect(unquoteLinesIn(text, 0, text.length).text, text);
    });

    test('quote then unquote is identity for non-blank input', () {
      const text = 'one\ntwo\nthree\n';
      final q = quoteLinesIn(text, 0, text.length).text;
      expect(unquoteLinesIn(q, 0, q.length).text, text);
    });
  });

  group('linesToJsonArrayIn', () {
    test('basic conversion', () {
      const text = 'apple\nbanana\ncherry\n';
      final r = linesToJsonArrayIn(text, 0, text.length);
      expect(r.text, '["apple", "banana", "cherry"]\n');
    });

    test('trims each cell', () {
      const text = '  apple  \nbanana\n';
      final r = linesToJsonArrayIn(text, 0, text.length);
      expect(r.text, '["apple", "banana"]\n');
    });

    test('drops blank lines', () {
      const text = 'a\n\nb\n';
      final r = linesToJsonArrayIn(text, 0, text.length);
      expect(r.text, '["a", "b"]\n');
    });

    test('escapes internal double quotes', () {
      const text = 'say "hi"\nplain\n';
      final r = linesToJsonArrayIn(text, 0, text.length);
      expect(r.text, '["say \\"hi\\"", "plain"]\n');
    });

    test('escapes backslashes', () {
      const text = r'C:\path\file' '\n';
      final r = linesToJsonArrayIn(text, 0, text.length);
      expect(r.text, r'["C:\\path\\file"]' '\n');
    });

    test('output parses as valid JSON via dart:convert', () {
      const text = 'one\ntwo\nthree\n';
      final json = linesToJsonArrayIn(text, 0, text.length).text.trim();
      // We can't import dart:convert at the top because that bloats
      // the test imports for one assertion; do a quick local parse.
      final decoded = jsonDecode(json);
      expect(decoded, ['one', 'two', 'three']);
    });

    test('block with no non-blank lines is a no-op', () {
      const text = '\n\n';
      expect(linesToJsonArrayIn(text, 0, text.length).text, text);
    });
  });

  group('jsonArrayToLinesIn', () {
    test('explodes a one-line array into per-element lines', () {
      const text = '["apple","banana","cherry"]\n';
      final r = jsonArrayToLinesIn(text, 0, text.length);
      expect(r.text, 'apple\nbanana\ncherry\n');
    });

    test('round-trip lines → array → lines preserves the data', () {
      const text = 'one\ntwo\nthree\n';
      final asJson = linesToJsonArrayIn(text, 0, text.length).text;
      final back = jsonArrayToLinesIn(asJson, 0, asJson.length).text;
      expect(back, text);
    });

    test('un-escapes internal double quotes', () {
      const text = r'["say \"hi\"","plain"]' '\n';
      final r = jsonArrayToLinesIn(text, 0, text.length);
      expect(r.text, 'say "hi"\nplain\n');
    });

    test('non-string elements stringify (numbers, bools)', () {
      const text = '[1, 2, true]\n';
      final r = jsonArrayToLinesIn(text, 0, text.length);
      expect(r.text, '1\n2\ntrue\n');
    });

    test('malformed JSON passes through untouched', () {
      const text = '[oops\n';
      expect(jsonArrayToLinesIn(text, 0, text.length).text, text);
    });

    test('multi-line array input still parses', () {
      const text = '[\n  "a",\n  "b"\n]\n';
      final r = jsonArrayToLinesIn(text, 0, text.length);
      expect(r.text, 'a\nb\n');
    });
  });

  group('sumNumericLinesIn', () {
    test('sums simple integers into a single integer line', () {
      const text = '1\n2\n3\n';
      final r = sumNumericLinesIn(text, 0, text.length);
      expect(r.text, '6\n');
    });

    test('sums doubles and emits a decimal', () {
      const text = '1.5\n2.5\n';
      final r = sumNumericLinesIn(text, 0, text.length);
      expect(r.text, '4.0\n');
    });

    test('mixed int + double totals as decimal when any input is fractional', () {
      const text = '3\n0.5\n';
      final r = sumNumericLinesIn(text, 0, text.length);
      expect(r.text, '3.5\n');
    });

    test('skips non-numeric lines', () {
      const text = '1\nhello\n2\nworld\n';
      final r = sumNumericLinesIn(text, 0, text.length);
      expect(r.text, '3\n');
    });

    test('block with zero numeric lines is a no-op', () {
      const text = 'hello\nworld\n';
      expect(sumNumericLinesIn(text, 0, text.length).text, text);
    });

    test('negative numbers are supported', () {
      const text = '10\n-3\n-2\n';
      final r = sumNumericLinesIn(text, 0, text.length);
      expect(r.text, '5\n');
    });

    test('decimals that algebraically cancel render with .0', () {
      const text = '1.5\n-1.5\n';
      // Both inputs were fractional, so emit the .0 form rather than
      // hiding that we did decimal arithmetic.
      final r = sumNumericLinesIn(text, 0, text.length);
      expect(r.text, '0.0\n');
    });
  });

  group('averageNumericLinesIn', () {
    test('mean of three integers', () {
      const text = '1\n2\n3\n';
      final r = averageNumericLinesIn(text, 0, text.length);
      expect(r.text, '2.0\n');
    });

    test('mean skips non-numeric lines', () {
      const text = '10\nlabel\n20\n';
      final r = averageNumericLinesIn(text, 0, text.length);
      expect(r.text, '15.0\n');
    });

    test('no numeric lines is a no-op', () {
      const text = 'a\nb\n';
      expect(averageNumericLinesIn(text, 0, text.length).text, text);
    });
  });

  group('maxNumericLinesIn / minNumericLinesIn', () {
    test('max picks the biggest', () {
      const text = '1\n5\n3\n';
      expect(maxNumericLinesIn(text, 0, text.length).text, '5\n');
    });

    test('min picks the smallest', () {
      const text = '1\n5\n3\n';
      expect(minNumericLinesIn(text, 0, text.length).text, '1\n');
    });

    test('all-integer input renders integer output', () {
      const text = '4\n8\n';
      expect(maxNumericLinesIn(text, 0, text.length).text, '8\n');
    });

    test('any decimal input renders decimal output', () {
      const text = '4\n8.5\n';
      expect(maxNumericLinesIn(text, 0, text.length).text, '8.5\n');
    });

    test('negative numbers are supported', () {
      const text = '-5\n-1\n-9\n';
      expect(maxNumericLinesIn(text, 0, text.length).text, '-1\n');
      expect(minNumericLinesIn(text, 0, text.length).text, '-9\n');
    });

    test('no numeric lines is a no-op for both', () {
      const text = 'a\nb\n';
      expect(maxNumericLinesIn(text, 0, text.length).text, text);
      expect(minNumericLinesIn(text, 0, text.length).text, text);
    });
  });

  group('medianNumericLinesIn', () {
    test('odd count returns the middle element', () {
      const text = '1\n5\n3\n';
      final r = medianNumericLinesIn(text, 0, text.length);
      expect(r.text, '3\n');
    });

    test('even count returns the mean of the two middles', () {
      const text = '1\n2\n3\n4\n';
      final r = medianNumericLinesIn(text, 0, text.length);
      // (2 + 3) / 2 = 2.5
      expect(r.text, '2.5\n');
    });

    test('all-integer odd count renders integer', () {
      const text = '10\n20\n30\n';
      expect(medianNumericLinesIn(text, 0, text.length).text, '20\n');
    });

    test('decimal input renders decimal', () {
      const text = '1.0\n3.0\n5.0\n';
      expect(medianNumericLinesIn(text, 0, text.length).text, '3.0\n');
    });

    test('skips non-numeric lines', () {
      const text = '1\nlabel\n5\n3\n';
      // numeric set {1, 5, 3} → sorted {1, 3, 5} → median 3
      expect(medianNumericLinesIn(text, 0, text.length).text, '3\n');
    });

    test('no numeric lines is a no-op', () {
      const text = 'a\nb\n';
      expect(medianNumericLinesIn(text, 0, text.length).text, text);
    });

    test('negative values are supported', () {
      const text = '-5\n0\n5\n';
      expect(medianNumericLinesIn(text, 0, text.length).text, '0\n');
    });
  });

  group('countLinesIn', () {
    test('counts non-blank lines', () {
      const text = 'a\nb\nc\n';
      expect(countLinesIn(text, 0, text.length).text, '3\n');
    });

    test('blank lines do not count', () {
      const text = 'a\n\nb\n\n\nc\n';
      expect(countLinesIn(text, 0, text.length).text, '3\n');
    });

    test('whitespace-only lines are treated as blank', () {
      const text = 'a\n   \n\t\nb\n';
      expect(countLinesIn(text, 0, text.length).text, '2\n');
    });

    test('empty input yields 0', () {
      expect(countLinesIn('', 0, 0).text, '');
    });

    test('all-blank input yields 0', () {
      const text = '\n\n\n';
      expect(countLinesIn(text, 0, text.length).text, '0\n');
    });
  });

  group('productNumericLinesIn', () {
    test('product of three integers', () {
      const text = '2\n3\n4\n';
      final r = productNumericLinesIn(text, 0, text.length);
      expect(r.text, '24\n');
    });

    test('product of decimal inputs renders decimal', () {
      const text = '0.5\n2.0\n';
      final r = productNumericLinesIn(text, 0, text.length);
      expect(r.text, '1.0\n');
    });

    test('integer inputs with decimal product render decimal', () {
      // Can't easily produce this with pure ints, so use one .0 input
      // to mark "decimal style"; mixed input → decimal-form output.
      const text = '3\n0.5\n';
      expect(productNumericLinesIn(text, 0, text.length).text, '1.5\n');
    });

    test('skips non-numeric lines', () {
      const text = '2\nlabel\n3\n';
      expect(productNumericLinesIn(text, 0, text.length).text, '6\n');
    });

    test('zero shorts the product to zero', () {
      const text = '5\n0\n10\n';
      expect(productNumericLinesIn(text, 0, text.length).text, '0\n');
    });

    test('negative values flip the sign correctly', () {
      const text = '-2\n3\n';
      expect(productNumericLinesIn(text, 0, text.length).text, '-6\n');
    });

    test('no numeric lines is a no-op', () {
      const text = 'a\nb\n';
      expect(productNumericLinesIn(text, 0, text.length).text, text);
    });
  });

  group('frequencyLinesIn', () {
    test('counts and emits "Nx line" sorted by descending count', () {
      const text = 'apple\nbanana\napple\ncherry\napple\nbanana\n';
      final r = frequencyLinesIn(text, 0, text.length);
      expect(r.text, '3× apple\n2× banana\n1× cherry\n');
    });

    test('alphabetic tie-break is case-insensitive ascending', () {
      const text = 'zebra\napple\nzebra\napple\n';
      final r = frequencyLinesIn(text, 0, text.length);
      // Both at count 2; tie → apple before zebra.
      expect(r.text, '2× apple\n2× zebra\n');
    });

    test('skips blank lines', () {
      const text = 'a\n\nb\n\na\n';
      final r = frequencyLinesIn(text, 0, text.length);
      expect(r.text, '2× a\n1× b\n');
    });

    test('no non-blank lines is a no-op', () {
      const text = '\n\n';
      expect(frequencyLinesIn(text, 0, text.length).text, text);
    });

    test('single occurrence still gets the count prefix', () {
      const text = 'only one\n';
      expect(frequencyLinesIn(text, 0, text.length).text, '1× only one\n');
    });
  });

  group('rangeNumericLinesIn', () {
    test('range is max minus min', () {
      const text = '1\n5\n3\n';
      expect(rangeNumericLinesIn(text, 0, text.length).text, '4\n');
    });

    test('single numeric line yields 0', () {
      const text = '42\n';
      expect(rangeNumericLinesIn(text, 0, text.length).text, '0\n');
    });

    test('decimal input renders decimal', () {
      const text = '1.5\n3.5\n';
      expect(rangeNumericLinesIn(text, 0, text.length).text, '2.0\n');
    });

    test('negative values are supported', () {
      const text = '-5\n0\n5\n';
      expect(rangeNumericLinesIn(text, 0, text.length).text, '10\n');
    });

    test('skips non-numeric lines', () {
      const text = '10\nlabel\n5\n';
      expect(rangeNumericLinesIn(text, 0, text.length).text, '5\n');
    });

    test('no numeric lines is a no-op', () {
      const text = 'a\nb\n';
      expect(rangeNumericLinesIn(text, 0, text.length).text, text);
    });
  });

  group('cumulativeSumLinesIn', () {
    test('basic running total', () {
      const text = '1\n2\n3\n';
      final r = cumulativeSumLinesIn(text, 0, text.length);
      expect(r.text, '1\n3\n6\n');
    });

    test('non-numeric lines pass through without advancing', () {
      const text = '1\nlabel\n2\n';
      final r = cumulativeSumLinesIn(text, 0, text.length);
      expect(r.text, '1\nlabel\n3\n');
    });

    test('decimal inputs render decimal', () {
      const text = '1.5\n2.5\n';
      final r = cumulativeSumLinesIn(text, 0, text.length);
      expect(r.text, '1.5\n4.0\n');
    });

    test('negative values supported', () {
      const text = '10\n-3\n-2\n';
      final r = cumulativeSumLinesIn(text, 0, text.length);
      expect(r.text, '10\n7\n5\n');
    });

    test('no numeric lines is a no-op', () {
      const text = 'a\nb\n';
      expect(cumulativeSumLinesIn(text, 0, text.length).text, text);
    });

    test('last running total equals the M938 sum', () {
      const text = '3\n7\n5\n';
      final cum = cumulativeSumLinesIn(text, 0, text.length).text;
      final sum = sumNumericLinesIn(text, 0, text.length).text;
      // Last line of cum should match the sum output (modulo trailing
      // newline).
      final lastCum = cum.split('\n').where((l) => l.isNotEmpty).last;
      final sumLine = sum.split('\n').where((l) => l.isNotEmpty).single;
      expect(lastCum, sumLine);
    });
  });

  group('deltaNumericLinesIn', () {
    test('basic consecutive deltas with + prefix on positives', () {
      const text = '1\n5\n10\n';
      final r = deltaNumericLinesIn(text, 0, text.length);
      expect(r.text, '+4\n+5\n');
    });

    test('negative deltas use the native - sign', () {
      const text = '10\n3\n0\n';
      final r = deltaNumericLinesIn(text, 0, text.length);
      expect(r.text, '-7\n-3\n');
    });

    test('non-numeric line breaks the run', () {
      const text = '1\n5\ndivider\n10\n12\n';
      final r = deltaNumericLinesIn(text, 0, text.length);
      // Deltas: 5-1=+4; divider breaks; 12-10=+2.
      expect(r.text, '+4\ndivider\n+2\n');
    });

    test('single numeric line yields no deltas', () {
      const text = '42\n';
      final r = deltaNumericLinesIn(text, 0, text.length);
      // Only one number → no deltas to emit; the trailing newline
      // from the source is preserved by _transformLinesIn so output
      // is just '\n'.
      expect(r.text, '\n');
    });

    test('decimal deltas render decimal', () {
      const text = '1.0\n3.5\n';
      final r = deltaNumericLinesIn(text, 0, text.length);
      expect(r.text, '+2.5\n');
    });

    test('no numeric lines is a no-op', () {
      const text = 'a\nb\n';
      expect(deltaNumericLinesIn(text, 0, text.length).text, text);
    });
  });

  group('percentageOfTotalLinesIn', () {
    test('basic conversion to percentage', () {
      const text = '10\n30\n';
      final r = percentageOfTotalLinesIn(text, 0, text.length);
      expect(r.text, '25.0%\n75.0%\n');
    });

    test('decimal places kept to 1', () {
      const text = '1\n2\n';
      final r = percentageOfTotalLinesIn(text, 0, text.length);
      // 1/3 ≈ 0.3333… → 33.3%; 2/3 → 66.7%.
      expect(r.text, '33.3%\n66.7%\n');
    });

    test('non-numeric lines pass through', () {
      const text = '10\nlabel\n30\n';
      final r = percentageOfTotalLinesIn(text, 0, text.length);
      expect(r.text, '25.0%\nlabel\n75.0%\n');
    });

    test('column total of 0 is a no-op (no divide by zero)', () {
      const text = '5\n-5\n';
      expect(percentageOfTotalLinesIn(text, 0, text.length).text, text);
    });

    test('no numeric lines is a no-op', () {
      const text = 'a\nb\n';
      expect(percentageOfTotalLinesIn(text, 0, text.length).text, text);
    });

    test('sum of percentages equals 100', () {
      const text = '17\n23\n60\n';
      final r = percentageOfTotalLinesIn(text, 0, text.length).text;
      final total = r
          .split('\n')
          .where((l) => l.endsWith('%'))
          .map((l) => double.parse(l.substring(0, l.length - 1)))
          .reduce((a, b) => a + b);
      // Rounding may produce 99.9 or 100.1; assert "approximately 100".
      expect((total - 100).abs() < 0.2, isTrue,
          reason: 'sum was $total');
    });
  });

  group('stdDevNumericLinesIn', () {
    test('std dev of [2, 4, 4, 4, 5, 5, 7, 9] is 2.0', () {
      // Classic textbook example with a known population std dev of 2.
      const text = '2\n4\n4\n4\n5\n5\n7\n9\n';
      expect(stdDevNumericLinesIn(text, 0, text.length).text, '2.0\n');
    });

    test('single value has zero std dev', () {
      const text = '42\n';
      expect(stdDevNumericLinesIn(text, 0, text.length).text, '0.0\n');
    });

    test('two identical values have zero std dev', () {
      const text = '5\n5\n';
      expect(stdDevNumericLinesIn(text, 0, text.length).text, '0.0\n');
    });

    test('skips non-numeric lines', () {
      const text = '4\nlabel\n4\n';
      expect(stdDevNumericLinesIn(text, 0, text.length).text, '0.0\n');
    });

    test('no numeric lines is a no-op', () {
      const text = 'a\nb\n';
      expect(stdDevNumericLinesIn(text, 0, text.length).text, text);
    });
  });

  group('rankNumericLinesIn', () {
    test('ascending ranks preserve input position', () {
      const text = '30\n10\n20\n';
      final r = rankNumericLinesIn(text, 0, text.length);
      expect(r.text, '3\n1\n2\n');
    });

    test('ties share rank and the next rank skips (competition)', () {
      // 1, 3, 3, 7 → ranks 1, 2, 2, 4 (not 1, 2, 2, 3).
      const text = '3\n1\n3\n7\n';
      final r = rankNumericLinesIn(text, 0, text.length);
      expect(r.text, '2\n1\n2\n4\n');
    });

    test('label lines pass through unchanged', () {
      const text = 'score\n10\n20\n';
      final r = rankNumericLinesIn(text, 0, text.length);
      final lines = r.text.split('\n');
      expect(lines[0], 'score');
      expect(lines[1], '1');
      expect(lines[2], '2');
    });

    test('single numeric line gets rank 1', () {
      const text = '42\n';
      expect(rankNumericLinesIn(text, 0, text.length).text, '1\n');
    });

    test('no numeric lines is a no-op', () {
      const text = 'a\nb\n';
      expect(rankNumericLinesIn(text, 0, text.length).text, text);
    });

    test('negative values rank below positives', () {
      const text = '5\n-3\n0\n';
      final r = rankNumericLinesIn(text, 0, text.length);
      expect(r.text, '3\n1\n2\n');
    });
  });

  group('normalizeNumericLinesIn', () {
    test('three values across a 0..100 range scale into [0, 1]', () {
      const text = '0\n25\n100\n';
      final r = normalizeNumericLinesIn(text, 0, text.length);
      final lines = r.text.split('\n');
      expect(double.parse(lines[0]), closeTo(0.0, 1e-9));
      expect(double.parse(lines[1]), closeTo(0.25, 1e-9));
      expect(double.parse(lines[2]), closeTo(1.0, 1e-9));
    });

    test('label lines pass through unchanged', () {
      const text = 'score\n10\n20\n';
      final r = normalizeNumericLinesIn(text, 0, text.length);
      final lines = r.text.split('\n');
      expect(lines[0], 'score');
      expect(double.parse(lines[1]), closeTo(0.0, 1e-9));
      expect(double.parse(lines[2]), closeTo(1.0, 1e-9));
    });

    test('all-identical values is a no-op (avoids /0)', () {
      const text = '7\n7\n7\n';
      expect(normalizeNumericLinesIn(text, 0, text.length).text, text);
    });

    test('single numeric line is a no-op', () {
      const text = '42\n';
      expect(normalizeNumericLinesIn(text, 0, text.length).text, text);
    });

    test('no numeric lines is a no-op', () {
      const text = 'a\nb\n';
      expect(normalizeNumericLinesIn(text, 0, text.length).text, text);
    });

    test('negative values shift so min becomes 0', () {
      // [-5, 0, 5] has min -5, max 5, span 10 → 0.0, 0.5, 1.0.
      const text = '-5\n0\n5\n';
      final r = normalizeNumericLinesIn(text, 0, text.length);
      final lines = r.text.split('\n');
      expect(double.parse(lines[0]), closeTo(0.0, 1e-9));
      expect(double.parse(lines[1]), closeTo(0.5, 1e-9));
      expect(double.parse(lines[2]), closeTo(1.0, 1e-9));
    });
  });

  group('zScoreNumericLinesIn', () {
    test('symmetric run around the mean yields signed z-scores', () {
      // [10, 20, 30] has μ = 20, σ = sqrt(200/3) ≈ 8.1649658...
      // → z = -1.2247..., 0.0, 1.2247...
      const text = '10\n20\n30\n';
      final r = zScoreNumericLinesIn(text, 0, text.length);
      final lines = r.text.split('\n');
      expect(double.parse(lines[0]), closeTo(-1.2247, 1e-4));
      expect(double.parse(lines[1]), closeTo(0.0, 1e-9));
      expect(double.parse(lines[2]), closeTo(1.2247, 1e-4));
    });

    test('label lines pass through unchanged', () {
      const text = 'score\n10\n20\n30\n';
      final r = zScoreNumericLinesIn(text, 0, text.length);
      final lines = r.text.split('\n');
      expect(lines[0], 'score');
      expect(double.parse(lines[2]), closeTo(0.0, 1e-9));
    });

    test('all-identical values is a no-op (avoids /0)', () {
      const text = '7\n7\n7\n';
      expect(zScoreNumericLinesIn(text, 0, text.length).text, text);
    });

    test('single numeric line is a no-op', () {
      const text = '42\n';
      expect(zScoreNumericLinesIn(text, 0, text.length).text, text);
    });

    test('no numeric lines is a no-op', () {
      const text = 'a\nb\n';
      expect(zScoreNumericLinesIn(text, 0, text.length).text, text);
    });

    test('z-scores sum to 0 over the column', () {
      const text = '1\n2\n3\n4\n5\n';
      final r = zScoreNumericLinesIn(text, 0, text.length);
      final sum = r.text
          .split('\n')
          .where((l) => l.isNotEmpty)
          .map(double.parse)
          .reduce((a, b) => a + b);
      expect(sum, closeTo(0.0, 1e-9));
    });
  });

  group('varianceNumericLinesIn', () {
    test('variance of textbook example is std-dev squared (4)', () {
      // [2,4,4,4,5,5,7,9] has σ = 2, so variance = 4.
      const text = '2\n4\n4\n4\n5\n5\n7\n9\n';
      expect(varianceNumericLinesIn(text, 0, text.length).text, '4.0\n');
    });

    test('single value has zero variance', () {
      const text = '42\n';
      expect(varianceNumericLinesIn(text, 0, text.length).text, '0.0\n');
    });

    test('skips non-numeric lines', () {
      const text = '5\nlabel\n5\n';
      expect(varianceNumericLinesIn(text, 0, text.length).text, '0.0\n');
    });

    test('no numeric lines is a no-op', () {
      const text = 'a\nb\n';
      expect(varianceNumericLinesIn(text, 0, text.length).text, text);
    });
  });

  group('roundNumericLinesIn', () {
    test('default 2-decimal rounding', () {
      const text = '3.14159\n2.71828\n';
      final r = roundNumericLinesIn(text, 0, text.length);
      expect(r.text, '3.14\n2.72\n');
    });

    test('configurable precision', () {
      const text = '3.14159\n';
      expect(
        roundNumericLinesIn(text, 0, text.length, decimals: 4).text,
        '3.1416\n',
      );
    });

    test('precision 0 truncates the fractional part', () {
      const text = '3.7\n4.2\n';
      final r = roundNumericLinesIn(text, 0, text.length, decimals: 0);
      // Default toStringAsFixed(0) rounds-half-away-from-zero.
      expect(r.text, '4\n4\n');
    });

    test('integer input renders with the decimal places', () {
      const text = '5\n';
      // 5 → "5.00" with default precision.
      expect(roundNumericLinesIn(text, 0, text.length).text, '5.00\n');
    });

    test('non-numeric lines pass through', () {
      const text = '3.14\nlabel\n';
      expect(roundNumericLinesIn(text, 0, text.length).text, '3.14\nlabel\n');
    });
  });

  group('absNumericLinesIn / negateNumericLinesIn', () {
    test('abs flips negative to positive', () {
      const text = '-5\n3\n-7\n';
      final r = absNumericLinesIn(text, 0, text.length);
      expect(r.text, '5\n3\n7\n');
    });

    test('abs preserves positives untouched', () {
      const text = '5\n0\n3.5\n';
      final r = absNumericLinesIn(text, 0, text.length);
      expect(r.text, '5\n0\n3.5\n');
    });

    test('negate flips every sign', () {
      const text = '5\n-3\n0\n';
      final r = negateNumericLinesIn(text, 0, text.length);
      // Dart prints `-0` as `0` for ints; assert real-life rendering.
      expect(r.text, '-5\n3\n0\n');
    });

    test('negate twice is identity for non-zero values', () {
      const text = '5\n-3\n7\n';
      final once = negateNumericLinesIn(text, 0, text.length);
      final twice = negateNumericLinesIn(once.text, 0, once.text.length);
      expect(twice.text, text);
    });

    test('non-numeric lines pass through both transforms', () {
      const text = '-5\nlabel\n';
      expect(absNumericLinesIn(text, 0, text.length).text, '5\nlabel\n');
      expect(negateNumericLinesIn(text, 0, text.length).text, '5\nlabel\n');
    });

    test('decimal input renders decimal', () {
      const text = '-3.5\n';
      expect(absNumericLinesIn(text, 0, text.length).text, '3.5\n');
      expect(negateNumericLinesIn(text, 0, text.length).text, '3.5\n');
    });
  });

  group('floorNumericLinesIn / ceilNumericLinesIn / truncateNumericLinesIn', () {
    test('floor rounds toward -∞ (also negative inputs)', () {
      const text = '3.7\n-3.7\n0\n';
      final r = floorNumericLinesIn(text, 0, text.length);
      expect(r.text, '3\n-4\n0\n');
    });

    test('ceil rounds toward +∞', () {
      const text = '3.2\n-3.2\n0\n';
      final r = ceilNumericLinesIn(text, 0, text.length);
      expect(r.text, '4\n-3\n0\n');
    });

    test('truncate rounds toward zero — differs from floor on negatives', () {
      const text = '3.7\n-3.7\n';
      final r = truncateNumericLinesIn(text, 0, text.length);
      expect(r.text, '3\n-3\n');
    });

    test('non-numeric lines pass through all three transforms', () {
      const text = '3.5\nlabel\n';
      expect(floorNumericLinesIn(text, 0, text.length).text, '3\nlabel\n');
      expect(ceilNumericLinesIn(text, 0, text.length).text, '4\nlabel\n');
      expect(truncateNumericLinesIn(text, 0, text.length).text,
          '3\nlabel\n');
    });

    test('integer input is invariant under all three', () {
      const text = '5\n-2\n';
      expect(floorNumericLinesIn(text, 0, text.length).text, text);
      expect(ceilNumericLinesIn(text, 0, text.length).text, text);
      expect(truncateNumericLinesIn(text, 0, text.length).text, text);
    });
  });

  group('signNumericLinesIn', () {
    test('emits +, -, or 0 per numeric line', () {
      const text = '5\n-3\n0\n7.5\n-0.0\n';
      final r = signNumericLinesIn(text, 0, text.length);
      // Note: -0.0 parses as 0 numerically.
      expect(r.text, '+\n-\n0\n+\n0\n');
    });

    test('non-numeric lines pass through', () {
      const text = '5\nlabel\n-3\n';
      final r = signNumericLinesIn(text, 0, text.length);
      expect(r.text, '+\nlabel\n-\n');
    });

    test('empty input is a no-op', () {
      expect(signNumericLinesIn('', 0, 0).text, '');
    });
  });

  group('withThousandSeparatorsLinesIn', () {
    test('groups large integers with commas', () {
      const text = '1234567\n42\n';
      final r = withThousandSeparatorsLinesIn(text, 0, text.length);
      expect(r.text, '1,234,567\n42\n');
    });

    test('numbers under 1000 are untouched', () {
      const text = '999\n100\n0\n';
      expect(
        withThousandSeparatorsLinesIn(text, 0, text.length).text,
        text,
      );
    });

    test('preserves the decimal portion verbatim', () {
      const text = '1234567.89\n1000.50\n';
      final r = withThousandSeparatorsLinesIn(text, 0, text.length);
      expect(r.text, '1,234,567.89\n1,000.50\n');
    });

    test('negative numbers keep the leading minus', () {
      const text = '-1234567\n';
      expect(
        withThousandSeparatorsLinesIn(text, 0, text.length).text,
        '-1,234,567\n',
      );
    });

    test('non-numeric lines pass through', () {
      const text = '1234\nlabel\n5678\n';
      final r = withThousandSeparatorsLinesIn(text, 0, text.length);
      expect(r.text, '1,234\nlabel\n5,678\n');
    });
  });

  group('scientificNotationLinesIn', () {
    // Note: Dart's toStringAsExponential always emits a signed
    // exponent (`e+3` / `e-4`), so all expectations match that.
    test('default 3-digit mantissa', () {
      const text = '1234\n';
      expect(
        scientificNotationLinesIn(text, 0, text.length).text,
        '1.234e+3\n',
      );
    });

    test('small numbers get negative exponent', () {
      const text = '0.000567\n';
      expect(
        scientificNotationLinesIn(text, 0, text.length).text,
        '5.670e-4\n',
      );
    });

    test('zero renders consistently', () {
      const text = '0\n';
      expect(
        scientificNotationLinesIn(text, 0, text.length).text,
        '0.000e+0\n',
      );
    });

    test('configurable mantissa width', () {
      const text = '1234\n';
      expect(
        scientificNotationLinesIn(text, 0, text.length, digits: 5).text,
        '1.23400e+3\n',
      );
    });

    test('non-numeric lines pass through', () {
      const text = '1234\nlabel\n';
      expect(
        scientificNotationLinesIn(text, 0, text.length).text,
        '1.234e+3\nlabel\n',
      );
    });
  });

  group('cumulativeProductLinesIn', () {
    test('basic running product', () {
      const text = '2\n3\n4\n';
      final r = cumulativeProductLinesIn(text, 0, text.length);
      expect(r.text, '2\n6\n24\n');
    });

    test('non-numeric lines pass through', () {
      const text = '2\nlabel\n3\n';
      final r = cumulativeProductLinesIn(text, 0, text.length);
      expect(r.text, '2\nlabel\n6\n');
    });

    test('decimal input renders decimal', () {
      const text = '2.0\n3.0\n';
      final r = cumulativeProductLinesIn(text, 0, text.length);
      expect(r.text, '2.0\n6.0\n');
    });

    test('zero in the middle shorts subsequent rows to zero', () {
      const text = '5\n0\n10\n';
      final r = cumulativeProductLinesIn(text, 0, text.length);
      expect(r.text, '5\n0\n0\n');
    });

    test('last running product equals the M942 product', () {
      const text = '3\n7\n5\n';
      final cum = cumulativeProductLinesIn(text, 0, text.length).text;
      final prod = productNumericLinesIn(text, 0, text.length).text;
      final lastCum = cum.split('\n').where((l) => l.isNotEmpty).last;
      final prodLine = prod.split('\n').where((l) => l.isNotEmpty).single;
      expect(lastCum, prodLine);
    });

    test('no numeric lines is a no-op', () {
      const text = 'a\nb\n';
      expect(cumulativeProductLinesIn(text, 0, text.length).text, text);
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
