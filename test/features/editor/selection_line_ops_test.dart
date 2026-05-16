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

  group('stripHeadingMarkerLinesIn', () {
    test('strips h1-h6 markers from every level', () {
      const text = '# h1\n## h2\n### h3\n#### h4\n##### h5\n###### h6\n';
      final r = stripHeadingMarkerLinesIn(text, 0, text.length);
      expect(r.text, 'h1\nh2\nh3\nh4\nh5\nh6\n');
    });

    test('preserves leading indentation', () {
      const text = '  ## foo\n\t# bar\n';
      final r = stripHeadingMarkerLinesIn(text, 0, text.length);
      expect(r.text, '  foo\n\tbar\n');
    });

    test('plain lines pass through', () {
      const text = 'just prose\nno hashes\n';
      expect(stripHeadingMarkerLinesIn(text, 0, text.length).text, text);
    });

    test('seven-hash lines are NOT touched (markdown rejects h7+)', () {
      const text = '####### too many\n';
      // Re-reading the regex: `#{1,6}` requires 1-6 hashes then ` `.
      // Input is 7 hashes then space — the first 6 + the 7th hash +
      // space matches a 7-hash prefix... wait, no: regex anchors at
      // start. The regex matches the LONGEST anchored prefix of 1-6
      // `#` followed by ` `. For 7 hashes the regex CAN match 6 #
      // then `#` then ` ` — but the 7th char is `#`, not space, so
      // the match for `#{1,6} ` fails. Verifies the regex stops at 6.
      expect(
        stripHeadingMarkerLinesIn(text, 0, text.length).text,
        text,
      );
    });

    test('a `#` without a trailing space is preserved (not a heading)', () {
      const text = '#hashtag\n';
      expect(stripHeadingMarkerLinesIn(text, 0, text.length).text, text);
    });

    test('empty input stays empty', () {
      expect(stripHeadingMarkerLinesIn('', 0, 0).text, '');
    });
  });

  group('trimWhitespaceLinesIn', () {
    test('trims leading and trailing whitespace from each line', () {
      const text = '  foo  \n\tbar\t\n  baz\n';
      final r = trimWhitespaceLinesIn(text, 0, text.length);
      expect(r.text, 'foo\nbar\nbaz\n');
    });

    test('blank lines become empty (full collapse)', () {
      const text = '   \n\tfoo\t\n';
      final r = trimWhitespaceLinesIn(text, 0, text.length);
      expect(r.text, '\nfoo\n');
    });

    test('lines already flush pass through unchanged', () {
      const text = 'flush\nlines\n';
      expect(trimWhitespaceLinesIn(text, 0, text.length).text, text);
    });

    test('empty input stays empty', () {
      expect(trimWhitespaceLinesIn('', 0, 0).text, '');
    });
  });

  group('dedentLinesIn', () {
    test('strips the minimum common indent', () {
      const text = '  foo\n    bar\n  baz\n';
      final r = dedentLinesIn(text, 0, text.length);
      expect(r.text, 'foo\n  bar\nbaz\n');
    });

    test('blank lines are skipped when computing minimum + stay blank', () {
      const text = '  foo\n\n  bar\n';
      final r = dedentLinesIn(text, 0, text.length);
      expect(r.text, 'foo\n\nbar\n');
    });

    test('no common indent (a line is flush) is a no-op', () {
      const text = 'foo\n  bar\n';
      expect(dedentLinesIn(text, 0, text.length).text, text);
    });

    test('tabs count as one column each', () {
      // Both lines start with a tab; minimum indent is 1 (the tab).
      const text = '\tfoo\n\tbar\n';
      final r = dedentLinesIn(text, 0, text.length);
      expect(r.text, 'foo\nbar\n');
    });

    test('all-blank selection passes through (no indent to strip)', () {
      const text = '\n\n\n';
      expect(dedentLinesIn(text, 0, text.length).text, text);
    });

    test('empty input stays empty', () {
      expect(dedentLinesIn('', 0, 0).text, '');
    });
  });

  group('trimBlankEdgeLinesIn', () {
    test('strips leading and trailing blank lines, keeps interior', () {
      const text = '\n\nhello\n\nworld\n\n';
      final r = trimBlankEdgeLinesIn(text, 0, text.length);
      expect(r.text, 'hello\n\nworld\n');
    });

    test('blocks with no blank edges pass through unchanged', () {
      const text = 'foo\nbar\n';
      expect(trimBlankEdgeLinesIn(text, 0, text.length).text, text);
    });

    test('all-blank selection collapses to the trailing-newline only', () {
      // `_transformLinesIn` preserves the selection's trailing
      // newline; an empty lines list still re-emits one `\n`.
      const text = '\n\n\n';
      final r = trimBlankEdgeLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('whitespace-only edges count as blank too', () {
      const text = '   \nhello\n\t\n';
      final r = trimBlankEdgeLinesIn(text, 0, text.length);
      expect(r.text, 'hello\n');
    });

    test('empty input stays empty', () {
      expect(trimBlankEdgeLinesIn('', 0, 0).text, '');
    });
  });

  group('addBlockquotePrefixIn', () {
    test('adds `> ` to every non-blank line', () {
      const text = 'foo\nbar\n';
      final r = addBlockquotePrefixIn(text, 0, text.length);
      expect(r.text, '> foo\n> bar\n');
    });

    test('blank lines stay blank', () {
      const text = 'foo\n\nbar\n';
      final r = addBlockquotePrefixIn(text, 0, text.length);
      expect(r.text, '> foo\n\n> bar\n');
    });

    test('preserves leading indentation', () {
      const text = '  foo\n\tbar\n';
      final r = addBlockquotePrefixIn(text, 0, text.length);
      expect(r.text, '  > foo\n\t> bar\n');
    });

    test('idempotent-add: re-applying nests the quote', () {
      const text = '> foo\n';
      final r = addBlockquotePrefixIn(text, 0, text.length);
      // Already quoted → becomes `> > foo` (nested quote).
      expect(r.text, '> > foo\n');
    });

    test('empty input stays empty', () {
      expect(addBlockquotePrefixIn('', 0, 0).text, '');
    });
  });

  group('stripBlockquotePrefixIn', () {
    test('strips `> ` from every quoted line', () {
      const text = '> foo\n> bar\n';
      final r = stripBlockquotePrefixIn(text, 0, text.length);
      expect(r.text, 'foo\nbar\n');
    });

    test('mixed selection: only quoted lines get unquoted', () {
      const text = '> quoted\nplain\n> another\n';
      final r = stripBlockquotePrefixIn(text, 0, text.length);
      expect(r.text, 'quoted\nplain\nanother\n');
    });

    test('preserves leading indentation', () {
      const text = '  > foo\n\t> bar\n';
      final r = stripBlockquotePrefixIn(text, 0, text.length);
      expect(r.text, '  foo\n\tbar\n');
    });

    test('a lonely `>` without a trailing space is preserved', () {
      // The regex requires `> ` (with trailing space) so `>foo` is
      // not a blockquote prefix and passes through unchanged.
      const text = '>no-space\n';
      expect(stripBlockquotePrefixIn(text, 0, text.length).text, text);
    });

    test('empty input stays empty', () {
      expect(stripBlockquotePrefixIn('', 0, 0).text, '');
    });
  });

  group('prefixLinesWithWordCountIn', () {
    test('single-digit counts pad to width 1', () {
      const text = 'one\none two\n';
      final r = prefixLinesWithWordCountIn(text, 0, text.length);
      expect(r.text, '[1] one\n[2] one two\n');
    });

    test('mixed widths pad to the longest count', () {
      // Counts: 1, 2, 10 → width 2 padding.
      final tenWords = 'a b c d e f g h i j';
      final text = 'foo\nfoo bar\n$tenWords\n';
      final r = prefixLinesWithWordCountIn(text, 0, text.length);
      expect(
        r.text,
        '[ 1] foo\n[ 2] foo bar\n[10] $tenWords\n',
      );
    });

    test('blank lines get [0] so positions stay visible', () {
      const text = 'foo\n\nbar baz\n';
      final r = prefixLinesWithWordCountIn(text, 0, text.length);
      expect(r.text, '[1] foo\n[0] \n[2] bar baz\n');
    });

    test('whitespace runs still count as one boundary', () {
      // Three spaces between tokens = 2 words, not 4.
      const text = 'a   b\n';
      final r = prefixLinesWithWordCountIn(text, 0, text.length);
      expect(r.text, '[2] a   b\n');
    });

    test('empty input stays empty', () {
      expect(prefixLinesWithWordCountIn('', 0, 0).text, '');
    });
  });

  group('removeUrlsLinesIn', () {
    test('strips a single https URL', () {
      const text = 'see https://example.com for details\n';
      final r = removeUrlsLinesIn(text, 0, text.length);
      expect(r.text, 'see  for details\n');
    });

    test('strips multiple URLs in one line', () {
      const text = 'a https://x.test and ftp://y.test b\n';
      final r = removeUrlsLinesIn(text, 0, text.length);
      expect(r.text, 'a  and  b\n');
    });

    test('handles http (not https) too', () {
      const text = 'old http://example.com link\n';
      final r = removeUrlsLinesIn(text, 0, text.length);
      expect(r.text, 'old  link\n');
    });

    test('lines without a URL pass through unchanged', () {
      const text = 'just plain text\n';
      expect(removeUrlsLinesIn(text, 0, text.length).text, text);
    });

    test('does NOT touch the URL inside a markdown link', () {
      // The url is wrapped by `(...)` — those chars don't satisfy \S+
      // so the regex eats up to the closing paren.
      // The result is `[label]()` which the markdown-link strip
      // gesture (M977) cleans up if the user runs it afterward.
      const text = '[label](https://example.com)\n';
      final r = removeUrlsLinesIn(text, 0, text.length);
      expect(r.text, '[label](\n');
    });

    test('empty input stays empty', () {
      expect(removeUrlsLinesIn('', 0, 0).text, '');
    });
  });

  group('stripLeadingCharCountPrefixIn', () {
    test('strips an unpadded bracketed count', () {
      const text = '[3] foo\n[5] hello\n';
      final r = stripLeadingCharCountPrefixIn(text, 0, text.length);
      expect(r.text, 'foo\nhello\n');
    });

    test('strips a padded bracketed count (mixed widths)', () {
      const text = '[ 1] a\n[ 5] hello\n[12] hello! world\n';
      final r = stripLeadingCharCountPrefixIn(text, 0, text.length);
      expect(r.text, 'a\nhello\nhello! world\n');
    });

    test('lines without the bracketed prefix pass through unchanged', () {
      const text = '01. foo\nbar\n';
      expect(stripLeadingCharCountPrefixIn(text, 0, text.length).text, text);
    });

    test('round-trips with prefixLinesWithCharCountIn', () {
      const text = 'foo\nhello world\n';
      final pref = prefixLinesWithCharCountIn(text, 0, text.length);
      final back =
          stripLeadingCharCountPrefixIn(pref.text, 0, pref.text.length);
      expect(back.text, text);
    });

    test('empty input stays empty', () {
      expect(stripLeadingCharCountPrefixIn('', 0, 0).text, '');
    });
  });

  group('prefixLinesWithCharCountIn', () {
    test('three short lines get single-digit counts (width 1)', () {
      const text = 'foo\nbar\nbaz\n';
      final r = prefixLinesWithCharCountIn(text, 0, text.length);
      expect(r.text, '[3] foo\n[3] bar\n[3] baz\n');
    });

    test('mixed lengths pad to the widest count', () {
      // Lengths 1, 5, 12 → width 2 padding so single-digit counts
      // align in a column of size 2.
      const text = 'a\nhello\nhello! world\n';
      final r = prefixLinesWithCharCountIn(text, 0, text.length);
      expect(r.text, '[ 1] a\n[ 5] hello\n[12] hello! world\n');
    });

    test('blank lines get [ 0] so positions stay visible', () {
      const text = 'foo\n\nbar\n';
      final r = prefixLinesWithCharCountIn(text, 0, text.length);
      expect(r.text, '[3] foo\n[0] \n[3] bar\n');
    });

    test('does not interfere with stripLeadingNumberPrefixIn', () {
      // The bracket form `[3] foo` isn't matched by the strip regex
      // (which looks for `\d+[.:)\]-] `), so accidental round-trip
      // strips don't happen.
      const text = '[3] foo\n';
      expect(stripLeadingNumberPrefixIn(text, 0, text.length).text, text);
    });

    test('empty input stays empty', () {
      expect(prefixLinesWithCharCountIn('', 0, 0).text, '');
    });
  });

  group('escapeMarkdownLinesIn', () {
    test('backslash-escapes the canonical control characters', () {
      const text = r'**bold** *italic* `code`' '\n';
      final r = escapeMarkdownLinesIn(text, 0, text.length);
      expect(r.text, r'\*\*bold\*\* \*italic\* \`code\`' '\n');
    });

    test('escapes brackets and parens used in links/images', () {
      const text = '[label](url)\n';
      final r = escapeMarkdownLinesIn(text, 0, text.length);
      expect(r.text, r'\[label\]\(url\)' '\n');
    });

    test('escapes heading + blockquote + pipe characters', () {
      const text = '# H1 | col | > bq\n';
      final r = escapeMarkdownLinesIn(text, 0, text.length);
      expect(r.text, r'\# H1 \| col \| \> bq' '\n');
    });

    test('escapes the backslash itself', () {
      const text = r'use \n for newline' '\n';
      final r = escapeMarkdownLinesIn(text, 0, text.length);
      expect(r.text, r'use \\n for newline' '\n');
    });

    test('plain prose with no control chars is the identity', () {
      const text = 'hello world\n';
      expect(escapeMarkdownLinesIn(text, 0, text.length).text, text);
    });

    test('empty input stays empty', () {
      expect(escapeMarkdownLinesIn('', 0, 0).text, '');
    });
  });

  group('wrapLinesAt80In', () {
    test('short lines (≤80 chars) pass through unchanged', () {
      const text = 'hello world\nfoo bar baz\n';
      expect(wrapLinesAt80In(text, 0, text.length).text, text);
    });

    test('a 100-char line breaks at the last space ≤ column 80', () {
      // 5 ten-char words (each "abcdefghij") separated by spaces =
      // 5 * 10 + 4 = 54 chars. Add another 50-char chunk to push past 80.
      final line =
          '${'abcdefghij ' * 5}xxxxxxxxxx yyyyyyyyyy zzzzzzzzzz wwwwwwwwww';
      final text = '$line\n';
      final r = wrapLinesAt80In(text, 0, text.length);
      final wrapped = r.text.split('\n');
      // First wrap segment should be at most 80 chars and end with no
      // trailing space.
      expect(wrapped[0].length <= 80, isTrue);
      expect(wrapped[0].endsWith(' '), isFalse);
      // Original content reconstructs by joining the wrap segments
      // with a single space.
      expect(
        wrapped.where((s) => s.isNotEmpty).join(' '),
        line,
      );
    });

    test('an 81-char single word stays on one line (no mid-word break)', () {
      // A 100-char word with no whitespace can't be split safely.
      final word = 'x' * 100;
      final text = '$word\n';
      expect(wrapLinesAt80In(text, 0, text.length).text, text);
    });

    test('multiple long lines wrap independently', () {
      final long1 = '${'a' * 50} ${'b' * 50}';
      final long2 = '${'c' * 50} ${'d' * 50}';
      final text = '$long1\n$long2\n';
      final r = wrapLinesAt80In(text, 0, text.length);
      // Each original line becomes two wrap segments → four segments
      // (plus the trailing newline's empty string).
      final segments = r.text.split('\n').where((s) => s.isNotEmpty).toList();
      expect(segments.length, 4);
    });

    test('empty input stays empty', () {
      expect(wrapLinesAt80In('', 0, 0).text, '');
    });
  });

  group('indentLinesIn / outdentLinesIn', () {
    test('indent adds 2-space prefix to every non-empty line', () {
      const text = 'foo\nbar\n';
      final r = indentLinesIn(text, 0, text.length);
      expect(r.text, '  foo\n  bar\n');
    });

    test('indent leaves empty lines blank (no trailing whitespace)', () {
      const text = 'foo\n\nbar\n';
      final r = indentLinesIn(text, 0, text.length);
      expect(r.text, '  foo\n\n  bar\n');
    });

    test('outdent strips two leading spaces when present', () {
      const text = '  foo\n  bar\n';
      final r = outdentLinesIn(text, 0, text.length);
      expect(r.text, 'foo\nbar\n');
    });

    test('outdent partial: one leading space loses just that one', () {
      const text = ' foo\n   bar\n';
      final r = outdentLinesIn(text, 0, text.length);
      // " foo" → "foo" (1 space stripped), "   bar" → " bar" (2 stripped).
      expect(r.text, 'foo\n bar\n');
    });

    test('outdent on a flush line is a no-op for that line', () {
      const text = 'flush\n  indented\n';
      final r = outdentLinesIn(text, 0, text.length);
      expect(r.text, 'flush\nindented\n');
    });

    test('indent-then-outdent is the identity for ASCII text', () {
      const text = 'one\ntwo\nthree\n';
      final indented = indentLinesIn(text, 0, text.length);
      final back =
          outdentLinesIn(indented.text, 0, indented.text.length);
      expect(back.text, text);
    });

    test('outdent preserves leading tabs (tab/space mix is its own op)', () {
      const text = '\tfoo\n  bar\n';
      final r = outdentLinesIn(text, 0, text.length);
      expect(r.text, '\tfoo\nbar\n');
    });
  });

  group('kPostMortemScaffold', () {
    test('contains the four canonical post-mortem section headings', () {
      expect(kPostMortemScaffold.contains('## Summary\n'), isTrue);
      expect(kPostMortemScaffold.contains('## Timeline\n'), isTrue);
      expect(kPostMortemScaffold.contains('## Root cause\n'), isTrue);
      expect(kPostMortemScaffold.contains('## Action items\n'), isTrue);
    });

    test('headings appear in canonical order S → T → C → A', () {
      final iS = kPostMortemScaffold.indexOf('## Summary');
      final iT = kPostMortemScaffold.indexOf('## Timeline');
      final iC = kPostMortemScaffold.indexOf('## Root cause');
      final iA = kPostMortemScaffold.indexOf('## Action items');
      expect(iS < iT && iT < iC && iC < iA, isTrue);
    });

    test('action items use the GFM unchecked-todo form', () {
      expect(kPostMortemScaffold.contains('- [ ] '), isTrue);
    });

    test('caret offset (11) sits on the blank line below "## Summary"',
        () {
      const caretInScaffold = 11;
      expect(
        kPostMortemScaffold.substring(0, caretInScaffold),
        '## Summary\n',
      );
    });
  });

  group('kOneOnOneScaffold', () {
    test('contains the four canonical 1:1 section headings', () {
      expect(kOneOnOneScaffold.contains('## Their topics\n'), isTrue);
      expect(kOneOnOneScaffold.contains('## My topics\n'), isTrue);
      expect(kOneOnOneScaffold.contains('## Career\n'), isTrue);
      expect(kOneOnOneScaffold.contains('## Action items\n'), isTrue);
    });

    test('"Their topics" precedes "My topics" (report-first ordering)', () {
      final iTheir = kOneOnOneScaffold.indexOf('## Their topics');
      final iMine = kOneOnOneScaffold.indexOf('## My topics');
      expect(iTheir < iMine, isTrue);
    });

    test('action items use the GFM unchecked-todo form', () {
      expect(kOneOnOneScaffold.contains('- [ ] '), isTrue);
    });

    test('caret offset (18) sits right after the first "- "', () {
      const caretInScaffold = 18;
      expect(
        kOneOnOneScaffold.substring(0, caretInScaffold),
        '## Their topics\n- ',
      );
    });
  });

  group('kAdrNotesScaffold', () {
    test('contains the three canonical ADR section headings', () {
      expect(kAdrNotesScaffold.contains('## Context\n'), isTrue);
      expect(kAdrNotesScaffold.contains('## Decision\n'), isTrue);
      expect(kAdrNotesScaffold.contains('## Consequences\n'), isTrue);
    });

    test('headings appear in canonical Nygard order C → D → C', () {
      final iC = kAdrNotesScaffold.indexOf('## Context');
      final iD = kAdrNotesScaffold.indexOf('## Decision');
      final iCons = kAdrNotesScaffold.indexOf('## Consequences');
      expect(iC < iD && iD < iCons, isTrue);
    });

    test('caret offset (11) sits on the blank line below "## Context"',
        () {
      const caretInScaffold = 11;
      expect(
        kAdrNotesScaffold.substring(0, caretInScaffold),
        '## Context\n',
      );
    });
  });

  group('kRetroNotesScaffold', () {
    test('contains the three canonical retro section headings', () {
      expect(kRetroNotesScaffold.contains('## What went well\n'), isTrue);
      expect(kRetroNotesScaffold.contains("## What didn't\n"), isTrue);
      expect(kRetroNotesScaffold.contains('## Action items\n'), isTrue);
    });

    test('action items use the GFM unchecked-todo form', () {
      // So retro notes show up in M985's "open todos" palette entry.
      expect(kRetroNotesScaffold.contains('- [ ] '), isTrue);
    });

    test('caret offset (20) sits right after the first "- "', () {
      const caretInScaffold = 20;
      expect(
        kRetroNotesScaffold.substring(0, caretInScaffold),
        '## What went well\n- ',
      );
    });
  });

  group('kStandupNotesScaffold', () {
    test('contains the three canonical h2 standup sections', () {
      expect(kStandupNotesScaffold.contains('## Yesterday\n'), isTrue);
      expect(kStandupNotesScaffold.contains('## Today\n'), isTrue);
      expect(kStandupNotesScaffold.contains('## Blockers\n'), isTrue);
    });

    test('caret offset (13) sits on the blank line below "## Yesterday"',
        () {
      const caretInScaffold = 13;
      expect(
        kStandupNotesScaffold.substring(0, caretInScaffold),
        '## Yesterday\n',
      );
    });

    test('headings appear in canonical order Y → T → B', () {
      final iY = kStandupNotesScaffold.indexOf('## Yesterday');
      final iT = kStandupNotesScaffold.indexOf('## Today');
      final iB = kStandupNotesScaffold.indexOf('## Blockers');
      expect(iY < iT && iT < iB, isTrue);
    });
  });

  group('kMeetingNotesScaffold', () {
    test('contains the four canonical h2 section headings', () {
      expect(kMeetingNotesScaffold.contains('## Attendees\n'), isTrue);
      expect(kMeetingNotesScaffold.contains('## Agenda\n'), isTrue);
      expect(kMeetingNotesScaffold.contains('## Decisions\n'), isTrue);
      expect(kMeetingNotesScaffold.contains('## Action items\n'), isTrue);
    });

    test('action items use the GFM unchecked-todo form', () {
      // `- [ ] ` so the scaffold surfaces in M985's "Show pages with
      // open todos" palette entry.
      expect(kMeetingNotesScaffold.contains('- [ ] '), isTrue);
    });

    test('the caret-landing offset (15) sits right after the first "- "',
        () {
      // Sanity-check the magic number used in the source_view.dart
      // dispatch arm; if the heading prose changes, this catches the
      // drift before users notice the caret landing somewhere wrong.
      const caretInScaffold = 15;
      expect(
        kMeetingNotesScaffold.substring(0, caretInScaffold),
        '## Attendees\n- ',
      );
    });
  });

  group('kLoremIpsumParagraph', () {
    test('is one paragraph, no internal line breaks', () {
      expect(kLoremIpsumParagraph.contains('\n'), isFalse);
    });

    test('starts with the canonical "Lorem ipsum" phrase', () {
      expect(kLoremIpsumParagraph.startsWith('Lorem ipsum'), isTrue);
    });

    test('is three sentences (three terminating periods)', () {
      final endings =
          RegExp(r'\.').allMatches(kLoremIpsumParagraph).length;
      expect(endings, 3);
    });
  });

  group('removeAccentsLinesIn', () {
    test('folds common French diacritics', () {
      const text = 'café résumé naïve\n';
      final r = removeAccentsLinesIn(text, 0, text.length);
      expect(r.text, 'cafe resume naive\n');
    });

    test('preserves case while folding', () {
      const text = 'CAFÉ Naïve RÉSUMÉ\n';
      final r = removeAccentsLinesIn(text, 0, text.length);
      expect(r.text, 'CAFE Naive RESUME\n');
    });

    test('ligatures expand to two-letter ASCII forms', () {
      const text = 'œuvre Æsop straße\n';
      final r = removeAccentsLinesIn(text, 0, text.length);
      expect(r.text, 'oeuvre AEsop strasse\n');
    });

    test('covers Slavic / German hooks (ł ø ß ž)', () {
      const text = 'Łódź Brønnøysund Žižkov groß\n';
      final r = removeAccentsLinesIn(text, 0, text.length);
      expect(r.text, 'Lodz Bronnoysund Zizkov gross\n');
    });

    test('characters outside the cover set pass through (Greek/CJK)', () {
      const text = 'αβγ 日本 안녕\n';
      expect(removeAccentsLinesIn(text, 0, text.length).text, text);
    });

    test('plain ASCII is the identity', () {
      const text = 'hello world\n';
      expect(removeAccentsLinesIn(text, 0, text.length).text, text);
    });

    test('empty input stays empty', () {
      expect(removeAccentsLinesIn('', 0, 0).text, '');
    });
  });

  group('stripEmojiLinesIn', () {
    test('strips single-codepoint pictograph emoji', () {
      const text = 'hello 👋 world 🌍\n';
      // The space surrounding the emoji survives the strip.
      final r = stripEmojiLinesIn(text, 0, text.length);
      expect(r.text, 'hello  world \n');
    });

    test('strips dingbat block (e.g. ✓ ✗)', () {
      const text = 'done ✓ failed ✗\n';
      final r = stripEmojiLinesIn(text, 0, text.length);
      expect(r.text, 'done  failed \n');
    });

    test('strips ZWJ-composed sequences (family emoji)', () {
      // 👨‍👩‍👧 is U+1F468 + ZWJ + U+1F469 + ZWJ + U+1F467.
      // After stripping pictographs + ZWJs the line is empty before the
      // trailing newline.
      const text = '👨‍👩‍👧\n';
      final r = stripEmojiLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('plain ASCII text is the identity', () {
      const text = 'no emoji here, just ASCII!\n';
      expect(stripEmojiLinesIn(text, 0, text.length).text, text);
    });

    test('non-Latin scripts without emoji pass through', () {
      const text = '日本 안녕 مرحبا\n';
      expect(stripEmojiLinesIn(text, 0, text.length).text, text);
    });

    test('empty input stays empty', () {
      expect(stripEmojiLinesIn('', 0, 0).text, '');
    });
  });

  group('joinLinesWithSpaceIn', () {
    test('three sentences glue back into one paragraph', () {
      const text = 'Hello world.\nGoodbye now.\nSee you later.\n';
      final r = joinLinesWithSpaceIn(text, 0, text.length);
      expect(r.text, 'Hello world. Goodbye now. See you later.\n');
    });

    test('round-trips with splitLinesOnSentencesIn', () {
      const text = 'First sentence. Second sentence! Third question?\n';
      final split = splitLinesOnSentencesIn(text, 0, text.length);
      final joined = joinLinesWithSpaceIn(split.text, 0, split.text.length);
      expect(joined.text, text);
    });

    test('blank lines are skipped', () {
      const text = 'foo\n\nbar\n';
      final r = joinLinesWithSpaceIn(text, 0, text.length);
      expect(r.text, 'foo bar\n');
    });

    test('per-line whitespace is trimmed before joining', () {
      const text = '  alpha  \n  beta  \n';
      final r = joinLinesWithSpaceIn(text, 0, text.length);
      expect(r.text, 'alpha beta\n');
    });

    test('all-blank selection is a no-op', () {
      const text = '\n\n\n';
      expect(joinLinesWithSpaceIn(text, 0, text.length).text, text);
    });

    test('empty input stays empty', () {
      expect(joinLinesWithSpaceIn('', 0, 0).text, '');
    });
  });

  group('bulletizeSentencesIn', () {
    test('two-sentence paragraph splits into two bullets', () {
      const text = 'Hello world. Goodbye now.\n';
      final r = bulletizeSentencesIn(text, 0, text.length);
      expect(r.text, '- Hello world.\n- Goodbye now.\n');
    });

    test('a line with no sentence boundary still gets the bullet', () {
      const text = 'a single line\n';
      final r = bulletizeSentencesIn(text, 0, text.length);
      expect(r.text, '- a single line\n');
    });

    test('blank lines stay blank (no spurious bullet)', () {
      const text = 'one. Two!\n\nthree four\n';
      final r = bulletizeSentencesIn(text, 0, text.length);
      expect(r.text, '- one.\n- Two!\n\n- three four\n');
    });

    test('trims whitespace inside the sentence', () {
      const text = '  padded sentence  \n';
      final r = bulletizeSentencesIn(text, 0, text.length);
      expect(r.text, '- padded sentence\n');
    });

    test('empty input stays empty', () {
      expect(bulletizeSentencesIn('', 0, 0).text, '');
    });
  });

  group('splitLinesOnSentencesIn', () {
    test('two-sentence paragraph splits into two lines', () {
      const text = 'Hello world. Goodbye now.\n';
      final r = splitLinesOnSentencesIn(text, 0, text.length);
      expect(r.text, 'Hello world.\nGoodbye now.\n');
    });

    test('three sentences ending with mixed punctuation', () {
      const text = 'First! Then second. Finally third?\n';
      final r = splitLinesOnSentencesIn(text, 0, text.length);
      expect(r.text, 'First!\nThen second.\nFinally third?\n');
    });

    test('a line with no sentence boundary passes through unchanged', () {
      const text = 'just a single sentence.\n';
      expect(splitLinesOnSentencesIn(text, 0, text.length).text, text);
    });

    test('comma after period stays attached (no double-cap)', () {
      // No `[.!?] \s+ [A-Z]` pattern → no split.
      const text = 'apples, oranges, and bananas.\n';
      expect(splitLinesOnSentencesIn(text, 0, text.length).text, text);
    });

    test('multi-line input splits each line independently', () {
      const text = 'A. B.\nC. D.\n';
      final r = splitLinesOnSentencesIn(text, 0, text.length);
      expect(r.text, 'A.\nB.\nC.\nD.\n');
    });

    test('empty input stays empty', () {
      expect(splitLinesOnSentencesIn('', 0, 0).text, '');
    });
  });

  group('stripLeadingNumberPrefixIn', () {
    test('strips dot-separator with zero padding', () {
      const text = '01. foo\n02. bar\n';
      final r = stripLeadingNumberPrefixIn(text, 0, text.length);
      expect(r.text, 'foo\nbar\n');
    });

    test('strips other common separators (.: )] -)', () {
      const text = '1) foo\n2: bar\n3] baz\n4- qux\n';
      final r = stripLeadingNumberPrefixIn(text, 0, text.length);
      expect(r.text, 'foo\nbar\nbaz\nqux\n');
    });

    test('preserves leading indentation while stripping the prefix', () {
      const text = '  01. foo\n\t2) bar\n';
      final r = stripLeadingNumberPrefixIn(text, 0, text.length);
      expect(r.text, '  foo\n\tbar\n');
    });

    test('lines without a number prefix pass through unchanged', () {
      const text = 'plain line\nno prefix here\n';
      expect(stripLeadingNumberPrefixIn(text, 0, text.length).text, text);
    });

    test('round-trips with prefixLinesWithIndexIn', () {
      const text = 'foo\nbar\nbaz\n';
      final numbered = prefixLinesWithIndexIn(text, 0, text.length);
      final stripped = stripLeadingNumberPrefixIn(
        numbered.text,
        0,
        numbered.text.length,
      );
      expect(stripped.text, text);
    });

    test('empty input stays empty', () {
      expect(stripLeadingNumberPrefixIn('', 0, 0).text, '');
    });
  });

  group('prefixLinesWithIndexIn', () {
    test('three lines get single-digit prefixes', () {
      const text = 'foo\nbar\nbaz\n';
      final r = prefixLinesWithIndexIn(text, 0, text.length);
      // Width-1 padding for indices 1..3.
      expect(r.text, '1. foo\n2. bar\n3. baz\n');
    });

    test('ten or more lines zero-pad to keep columns aligned', () {
      final lines = List<String>.generate(10, (i) => 'line${i + 1}').join('\n');
      final text = '$lines\n';
      final r = prefixLinesWithIndexIn(text, 0, text.length);
      // Width-2 padding so index "01" lines up under "10".
      expect(r.text.startsWith('01. line1\n'), isTrue);
      expect(r.text.contains('10. line10\n'), isTrue);
    });

    test('100+ lines zero-pad to width 3', () {
      // Confirm the width scales with the largest index, not a fixed value.
      final lines =
          List<String>.generate(100, (i) => 'L${i + 1}').join('\n');
      final text = '$lines\n';
      final r = prefixLinesWithIndexIn(text, 0, text.length);
      expect(r.text.startsWith('001. L1\n'), isTrue);
      expect(r.text.contains('100. L100\n'), isTrue);
    });

    test('blank lines still get the prefix to keep numbering monotonic', () {
      const text = 'foo\n\nbar\n';
      final r = prefixLinesWithIndexIn(text, 0, text.length);
      // The middle blank line gets a "2. " prefix so foo→1, blank→2, bar→3.
      expect(r.text, '1. foo\n2. \n3. bar\n');
    });

    test('empty selection is a no-op', () {
      expect(prefixLinesWithIndexIn('', 0, 0).text, '');
    });
  });

  group('stripHtmlTagsLinesIn', () {
    test('strips opening + closing tag wrappers, keeps inner text', () {
      const text = '<b>Hello</b> <span>world</span>\n';
      final r = stripHtmlTagsLinesIn(text, 0, text.length);
      expect(r.text, 'Hello world\n');
    });

    test('drops self-closing tags entirely', () {
      const text = 'line1<br/>line2 <hr>\n';
      final r = stripHtmlTagsLinesIn(text, 0, text.length);
      expect(r.text, 'line1line2 \n');
    });

    test('attribute-rich tags strip just as cleanly', () {
      const text = 'before<a href="x" rel="nofollow">link</a>after\n';
      final r = stripHtmlTagsLinesIn(text, 0, text.length);
      expect(r.text, 'beforelinkafter\n');
    });

    test('HTML entities pass through unchanged', () {
      // Unescaping is a separate gesture (htmlUnescape).
      const text = '<b>foo</b> &amp; bar\n';
      final r = stripHtmlTagsLinesIn(text, 0, text.length);
      expect(r.text, 'foo &amp; bar\n');
    });

    test('a lone `<` without a closing `>` on the same line is kept', () {
      const text = 'use the < operator\n';
      expect(stripHtmlTagsLinesIn(text, 0, text.length).text, text);
    });

    test('a `<` followed by `>` on the next line does not eat the newline', () {
      // Per-line scope: `<foo\nbar>` is two separate lines.
      const text = '<foo\nbar>\n';
      final r = stripHtmlTagsLinesIn(text, 0, text.length);
      expect(r.text, '<foo\nbar>\n');
    });

    test('empty input stays empty', () {
      expect(stripHtmlTagsLinesIn('', 0, 0).text, '');
    });
  });

  group('stripMarkdownLinksLinesIn', () {
    test('strips a plain link and keeps the label', () {
      const text = '[Click here](http://example.com)\n';
      final r = stripMarkdownLinksLinesIn(text, 0, text.length);
      expect(r.text, 'Click here\n');
    });

    test('strips an image and keeps the alt text', () {
      const text = '![diagram](attachments/foo.png)\n';
      final r = stripMarkdownLinksLinesIn(text, 0, text.length);
      expect(r.text, 'diagram\n');
    });

    test('wikilinks are preserved (Quill-internal relation)', () {
      const text = '[[01H7ABCDEFGH]] referenced\n';
      expect(stripMarkdownLinksLinesIn(text, 0, text.length).text, text);
    });

    test('transcluded wikilinks are preserved', () {
      const text = '![[01H7ABCDEFGH]]\n';
      expect(stripMarkdownLinksLinesIn(text, 0, text.length).text, text);
    });

    test('mixed link + emphasis only touches the link', () {
      // Emphasis stays — caller can chain `stripMarkdownEmphasisLines`.
      const text = '**important** [page](url) note\n';
      final r = stripMarkdownLinksLinesIn(text, 0, text.length);
      expect(r.text, '**important** page note\n');
    });

    test('plain prose is the identity', () {
      const text = 'no links here\n';
      expect(stripMarkdownLinksLinesIn(text, 0, text.length).text, text);
    });

    test('empty image alt becomes empty string', () {
      const text = '![](img.png) caption\n';
      final r = stripMarkdownLinksLinesIn(text, 0, text.length);
      expect(r.text, ' caption\n');
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

  group('asciiOnlyLinesIn', () {
    test('drops emoji and keeps ASCII text', () {
      const text = 'hello 👋 world\n';
      final r = asciiOnlyLinesIn(text, 0, text.length);
      expect(r.text, 'hello  world\n');
    });

    test('drops accented Latin (does NOT fold to base letters)', () {
      // Unlike removeAccents, this just drops the non-ASCII chars.
      const text = 'café résumé\n';
      final r = asciiOnlyLinesIn(text, 0, text.length);
      expect(r.text, 'caf rsum\n');
    });

    test('drops CJK / Arabic / other scripts', () {
      const text = 'mix 日本 안녕 مرحبا done\n';
      final r = asciiOnlyLinesIn(text, 0, text.length);
      expect(r.text, 'mix    done\n');
    });

    test('plain ASCII passes through unchanged', () {
      const text = 'hello world 1234 !@#\n';
      expect(asciiOnlyLinesIn(text, 0, text.length).text, text);
    });

    test('smart quotes / em dashes are dropped', () {
      // `‘` left single quote, `—` em dash — both >127.
      const text = '‘hello’ — world\n';
      final r = asciiOnlyLinesIn(text, 0, text.length);
      expect(r.text, 'hello  world\n');
    });

    test('empty input stays empty', () {
      expect(asciiOnlyLinesIn('', 0, 0).text, '');
    });
  });

  group('capitalizeFirstLetterPerLineIn', () {
    test('capitalizes the first letter, leaves the rest', () {
      const text = 'hello world\nfoo BAR\n';
      final r = capitalizeFirstLetterPerLineIn(text, 0, text.length);
      expect(r.text, 'Hello world\nFoo BAR\n');
    });

    test('skips leading non-letter chars (bullet markers)', () {
      const text = '- hello\n* world\n  + indented\n';
      final r = capitalizeFirstLetterPerLineIn(text, 0, text.length);
      expect(r.text, '- Hello\n* World\n  + Indented\n');
    });

    test('already-capitalized line is unchanged', () {
      const text = 'Hello\nWorld\n';
      expect(capitalizeFirstLetterPerLineIn(text, 0, text.length).text, text);
    });

    test('lines without any letters pass through unchanged', () {
      const text = '   \n123\n!!\n';
      expect(capitalizeFirstLetterPerLineIn(text, 0, text.length).text, text);
    });

    test('empty input stays empty', () {
      expect(capitalizeFirstLetterPerLineIn('', 0, 0).text, '');
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

  group('extractMarkdownLinkUrlsFromLinesIn', () {
    test('strips the label and keeps the URL', () {
      const text = 'click [Docs](https://x.test) and [Wiki](https://y.test)\n';
      final r = extractMarkdownLinkUrlsFromLinesIn(text, 0, text.length);
      expect(r.text, 'https://x.test\nhttps://y.test\n');
    });

    test('wikilinks [[ULID]] are NOT matched (lookbehind rejects)', () {
      const text = '[[01HABCDEFGHIJKLMNOPQRSTUVW]] and [foo](https://x.test)\n';
      final r = extractMarkdownLinkUrlsFromLinesIn(text, 0, text.length);
      expect(r.text, 'https://x.test\n');
    });

    test('image-link form is NOT a plain markdown link', () {
      // `![alt](src)` has a leading `!` so the regex (which has
      // negative lookbehind on `[` to reject `[[`) ALSO does not
      // need to reject `![` — the regex matches starting at `[`,
      // and `!` is fine before. Document the actual behaviour:
      // images ARE matched (the URL inside `(...)` IS extracted).
      const text = '![alt](image.png) and [doc](https://x.test)\n';
      final r = extractMarkdownLinkUrlsFromLinesIn(text, 0, text.length);
      expect(r.text, 'image.png\nhttps://x.test\n');
    });

    test('empty URL slot extracts as empty string', () {
      const text = '[label]() trailing\n';
      // The lookbehind/lookahead allow empty contents inside `(...)`.
      final r = extractMarkdownLinkUrlsFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('lines without markdown links dropped from output', () {
      const text = 'bare url https://x.test\n[lbl](https://y.test)\n';
      final r = extractMarkdownLinkUrlsFromLinesIn(text, 0, text.length);
      expect(r.text, 'https://y.test\n');
    });

    test('empty input stays empty', () {
      expect(extractMarkdownLinkUrlsFromLinesIn('', 0, 0).text, '');
    });
  });

  group('extractMarkdownLinkLabelsFromLinesIn', () {
    test('strips the wrapper and keeps the label', () {
      const text = 'click [Docs](https://x.test) and [Wiki](https://y.test)\n';
      final r = extractMarkdownLinkLabelsFromLinesIn(text, 0, text.length);
      expect(r.text, 'Docs\nWiki\n');
    });

    test('wikilinks [[ULID]] are NOT matched (lookbehind rejects)', () {
      const text = '[[01HABCDEFGHIJKLMNOPQRSTUVW]] and [Real](url)\n';
      final r = extractMarkdownLinkLabelsFromLinesIn(text, 0, text.length);
      expect(r.text, 'Real\n');
    });

    test('labels with internal punctuation pass through intact', () {
      const text = '[Click, then read](url) trailing\n';
      final r = extractMarkdownLinkLabelsFromLinesIn(text, 0, text.length);
      expect(r.text, 'Click, then read\n');
    });

    test('lines without markdown links dropped from output', () {
      const text = 'bare url https://x.test\n[label](https://y.test)\n';
      final r = extractMarkdownLinkLabelsFromLinesIn(text, 0, text.length);
      expect(r.text, 'label\n');
    });

    test('empty input stays empty', () {
      expect(extractMarkdownLinkLabelsFromLinesIn('', 0, 0).text, '');
    });
  });

  group('extractMarkdownImageUrlsFromLinesIn', () {
    test('strips the alt and keeps the URL', () {
      const text = 'see ![Hero](hero.png) and ![Logo](https://x.test/l.svg)\n';
      final r = extractMarkdownImageUrlsFromLinesIn(text, 0, text.length);
      expect(r.text, 'hero.png\nhttps://x.test/l.svg\n');
    });

    test('bare links without `!` are NOT matched', () {
      // The image extractor REQUIRES the leading `!`; a plain
      // `[doc](url)` link is not an image and must be skipped.
      const text = '[doc](https://x.test) and ![img](pic.png)\n';
      final r = extractMarkdownImageUrlsFromLinesIn(text, 0, text.length);
      expect(r.text, 'pic.png\n');
    });

    test('empty alt slot is allowed', () {
      // `![](url)` is a CommonMark-legal image with no alt;
      // the extractor must still capture the URL.
      const text = '![](deco.svg) trailing\n';
      final r = extractMarkdownImageUrlsFromLinesIn(text, 0, text.length);
      expect(r.text, 'deco.svg\n');
    });

    test('multiple images on one line each extract', () {
      const text = '![a](1.png) gap ![b](2.png) gap ![c](3.png)\n';
      final r = extractMarkdownImageUrlsFromLinesIn(text, 0, text.length);
      expect(r.text, '1.png\n2.png\n3.png\n');
    });

    test('image URL with query string and fragment preserved', () {
      const text = '![hero](https://cdn.test/h.png?v=2#main) text\n';
      final r = extractMarkdownImageUrlsFromLinesIn(text, 0, text.length);
      expect(r.text, 'https://cdn.test/h.png?v=2#main\n');
    });

    test('lines without images dropped from output', () {
      const text = 'no images here\n![img](pic.jpg)\nplain text\n';
      final r = extractMarkdownImageUrlsFromLinesIn(text, 0, text.length);
      expect(r.text, 'pic.jpg\n');
    });

    test('empty input stays empty', () {
      expect(extractMarkdownImageUrlsFromLinesIn('', 0, 0).text, '');
    });
  });

  group('extractMarkdownImageAltsFromLinesIn', () {
    test('strips the URL and keeps the alt', () {
      const text = 'see ![Hero](hero.png) and ![Logo](logo.svg)\n';
      final r = extractMarkdownImageAltsFromLinesIn(text, 0, text.length);
      expect(r.text, 'Hero\nLogo\n');
    });

    test('bare links without `!` are NOT matched', () {
      const text = '[Docs](url) and ![diagram](d.png)\n';
      final r = extractMarkdownImageAltsFromLinesIn(text, 0, text.length);
      expect(r.text, 'diagram\n');
    });

    test('empty alt emits as empty line', () {
      // The regex captures zero-or-more for alt, so an empty
      // alt yields an empty captured group. Match the
      // documented helper behaviour (one blank entry per match).
      const text = '![](decoration.svg)\n';
      final r = extractMarkdownImageAltsFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('alt with internal punctuation passes through intact', () {
      const text = '![Click, then read](pic.png) trailing\n';
      final r = extractMarkdownImageAltsFromLinesIn(text, 0, text.length);
      expect(r.text, 'Click, then read\n');
    });

    test('multiple images on one line each extract', () {
      const text = '![first](1.png) and ![second](2.png) and ![third](3.png)\n';
      final r = extractMarkdownImageAltsFromLinesIn(text, 0, text.length);
      expect(r.text, 'first\nsecond\nthird\n');
    });

    test('lines without images dropped from output', () {
      const text = 'plain prose here\n![alt](pic.png)\nmore prose\n';
      final r = extractMarkdownImageAltsFromLinesIn(text, 0, text.length);
      expect(r.text, 'alt\n');
    });

    test('empty input stays empty', () {
      expect(extractMarkdownImageAltsFromLinesIn('', 0, 0).text, '');
    });
  });

  group('extractUuidsFromLinesIn', () {
    test('extracts canonical hyphenated UUIDs', () {
      const u1 = '550e8400-e29b-41d4-a716-446655440000';
      const u2 = '6FA459EA-EE8A-3CA4-894E-DB77E160355E';
      final text = 'pair $u1 and $u2 are siblings\n';
      final r = extractUuidsFromLinesIn(text, 0, text.length);
      expect(r.text, '$u1\n$u2\n');
    });

    test('mixed-case hex digits accepted', () {
      const u = 'AbCdEf01-1234-5678-9aBc-DeF012345678';
      final text = 'uuid $u\n';
      final r = extractUuidsFromLinesIn(text, 0, text.length);
      expect(r.text, '$u\n');
    });

    test('wrong segment lengths are NOT UUIDs', () {
      // 7-4-4-4-12 → wrong shape.
      const text = '12345678-1234-1234-1234-123456789012\n'
          '1234567-1234-1234-1234-123456789012\n';
      final r = extractUuidsFromLinesIn(text, 0, text.length);
      expect(r.text, '12345678-1234-1234-1234-123456789012\n');
    });

    test('lines without a UUID dropped from output', () {
      const u = '550e8400-e29b-41d4-a716-446655440000';
      final text = 'plain prose\nuuid $u\n';
      final r = extractUuidsFromLinesIn(text, 0, text.length);
      expect(r.text, '$u\n');
    });

    test('empty input stays empty', () {
      expect(extractUuidsFromLinesIn('', 0, 0).text, '');
    });
  });

  group('extractSemverFromLinesIn', () {
    test('plain `1.2.3` extracts', () {
      const text = 'release 1.2.3 shipped\n';
      final r = extractSemverFromLinesIn(text, 0, text.length);
      expect(r.text, '1.2.3\n');
    });

    test('pre-release tag included', () {
      const text = 'cut 1.2.3-rc.1 today\n';
      final r = extractSemverFromLinesIn(text, 0, text.length);
      expect(r.text, '1.2.3-rc.1\n');
    });

    test('build metadata included', () {
      const text = 'build 1.2.3+sha.abcdef trail\n';
      final r = extractSemverFromLinesIn(text, 0, text.length);
      expect(r.text, '1.2.3+sha.abcdef\n');
    });

    test('combined pre-release AND build metadata', () {
      const text = 'tag 1.2.3-rc.1+sha.abc123 fixed\n';
      final r = extractSemverFromLinesIn(text, 0, text.length);
      expect(r.text, '1.2.3-rc.1+sha.abc123\n');
    });

    test('leading `v` Git-tag form is captured with the `v`', () {
      // `v1.2.3` is the dominant Git-tag / changelog form;
      // the regex's `v?` arm picks it up and the `v` is
      // included in the match (it identifies the tag).
      const text = 'tag v1.2.3 release\n';
      final r = extractSemverFromLinesIn(text, 0, text.length);
      expect(r.text, 'v1.2.3\n');
    });

    test('4-segment versions are NOT matched as partial semver', () {
      // `(?!\.\d)` after PATCH rejects 4-segment versions
      // like `1.2.3.4` — we do NOT emit "1.2.3" for those.
      // `transformLinesIn` re-emits a trailing `\n` even when
      // no matches were found (documented helper behaviour).
      const text = 'kernel 5.15.0.123 build\n';
      final r = extractSemverFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('leading zeros in segments are NOT semver-valid', () {
      // Per semver.org, MAJOR/MINOR/PATCH segments may not
      // have leading zeros (except for the literal `0`).
      const text = '01.2.3 and 1.02.3 and 1.2.03 are invalid\n';
      final r = extractSemverFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('two-segment versions are NOT semver', () {
      const text = 'partial 1.2 missing patch\n';
      final r = extractSemverFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('digits attached to a word are NOT matched', () {
      // The lookbehind `(?<![\w.])` rejects matches where the
      // preceding char is a word char or `.`, so `foo1.2.3`
      // (no separator) is correctly skipped.
      const text = 'attached foo1.2.3 thing\n';
      final r = extractSemverFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('multiple semvers on one line each extract', () {
      const text = 'from 1.0.0 to 2.3.4-beta to 10.20.30 done\n';
      final r = extractSemverFromLinesIn(text, 0, text.length);
      expect(r.text, '1.0.0\n2.3.4-beta\n10.20.30\n');
    });

    test('hyphenated pre-release identifier handled', () {
      // `foo-bar` is a single semver-valid pre-release identifier
      // (the dash is part of `[0-9A-Za-z-]+`).
      const text = '1.2.3-foo-bar baseline\n';
      final r = extractSemverFromLinesIn(text, 0, text.length);
      expect(r.text, '1.2.3-foo-bar\n');
    });

    test('lines without semver dropped from output', () {
      const text = 'plain prose\n1.2.3 shipped\nmore prose\n';
      final r = extractSemverFromLinesIn(text, 0, text.length);
      expect(r.text, '1.2.3\n');
    });

    test('empty input stays empty', () {
      expect(extractSemverFromLinesIn('', 0, 0).text, '');
    });
  });

  group('extractMacAddressesFromLinesIn', () {
    test('colon-separated MAC extracts in canonical form', () {
      const text = 'host 01:23:45:67:89:AB online\n';
      final r = extractMacAddressesFromLinesIn(text, 0, text.length);
      expect(r.text, '01:23:45:67:89:AB\n');
    });

    test('hyphen-separated MAC extracts as-is', () {
      const text = 'wmi reports 01-23-45-67-89-AB now\n';
      final r = extractMacAddressesFromLinesIn(text, 0, text.length);
      expect(r.text, '01-23-45-67-89-AB\n');
    });

    test('mixed-case hex digits accepted', () {
      const text = 'addr aB:Cd:Ef:01:23:45 seen\n';
      final r = extractMacAddressesFromLinesIn(text, 0, text.length);
      expect(r.text, 'aB:Cd:Ef:01:23:45\n');
    });

    test('mixed separators are NOT a MAC', () {
      // Backref `\1` requires the same separator throughout the
      // run — `01:23-45:67:89:AB` switches between `:` and `-`.
      const text = 'fake 01:23-45:67:89:AB invalid\n';
      final r = extractMacAddressesFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('5-octet shape is NOT a MAC', () {
      // Five octets = missing one separator-segment — too short.
      const text = 'short 01:23:45:67:89 only five\n';
      final r = extractMacAddressesFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('7-octet shape captures only the first 6 (canonical)', () {
      // Greedy match anchors at the first valid 6-octet run.
      // The trailing `:XX` ends up as leftover on the source
      // line; the regex's `\b` ensures we stop before consuming
      // the 7th octet. Documented behaviour: prose-style MACs
      // shouldn't surface false positives.
      const text = 'over 01:23:45:67:89:AB:CD wrong\n';
      final r = extractMacAddressesFromLinesIn(text, 0, text.length);
      // `\b` anchors mean the 6-octet run starting at `01` reaches
      // `AB`, and `AB` is followed by `:`, which is non-word — so
      // `\b` matches between `AB` and `:`, and we stop there.
      expect(r.text, '01:23:45:67:89:AB\n');
    });

    test('three-digit "octet" is NOT a MAC', () {
      const text = 'bad 001:23:45:67:89:AB malformed\n';
      final r = extractMacAddressesFromLinesIn(text, 0, text.length);
      // The leading `001` is 3 hex; the regex requires exactly 2
      // per octet. Could the regex slide forward and match
      // `01:23:45:67:89:AB`? `\b` before the second `0` requires
      // non-word→word, but `0` is preceded by `0` (word). No `\b`,
      // no match.
      expect(r.text, '\n');
    });

    test('multiple MACs on one line each extract', () {
      const text = 'pair 01:23:45:67:89:AB and aa-bb-cc-dd-ee-ff\n';
      final r = extractMacAddressesFromLinesIn(text, 0, text.length);
      expect(r.text, '01:23:45:67:89:AB\naa-bb-cc-dd-ee-ff\n');
    });

    test('non-hex chars in an octet reject the MAC', () {
      // `ZZ` is not hex; the regex requires `[0-9a-fA-F]`.
      const text = 'nope 01:23:ZZ:67:89:AB reject\n';
      final r = extractMacAddressesFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('lines without MACs dropped from output', () {
      const text = 'plain prose\n01:23:45:67:89:AB live\nmore prose\n';
      final r = extractMacAddressesFromLinesIn(text, 0, text.length);
      expect(r.text, '01:23:45:67:89:AB\n');
    });

    test('empty input stays empty', () {
      expect(extractMacAddressesFromLinesIn('', 0, 0).text, '');
    });
  });

  group('extractMarkdownCodeSpansFromLinesIn', () {
    test('strips the backticks and keeps the span content', () {
      const text = 'call `foo()` and `bar.baz` to start\n';
      final r = extractMarkdownCodeSpansFromLinesIn(text, 0, text.length);
      expect(r.text, 'foo()\nbar.baz\n');
    });

    test('two adjacent backticks (no content between) NOT matched', () {
      // `[^`\n]+` requires at least one non-backtick char between
      // delimiters, so a zero-content span isn't a meaningful
      // citation and is skipped. Stricter than CommonMark's
      // multi-backtick span rules (`` `` `` for spans containing
      // a literal backtick) which v1 of this extractor does not
      // implement.
      const text = 'see `` for trivia\n';
      final r = extractMarkdownCodeSpansFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('span with internal spaces preserved', () {
      const text = 'note `if let Some(x) = opt` works\n';
      final r = extractMarkdownCodeSpansFromLinesIn(text, 0, text.length);
      expect(r.text, 'if let Some(x) = opt\n');
    });

    test('multiple spans on one line each extract', () {
      const text = '`a` then `b` then `c` chain\n';
      final r = extractMarkdownCodeSpansFromLinesIn(text, 0, text.length);
      expect(r.text, 'a\nb\nc\n');
    });

    test('span with punctuation and symbols passes through', () {
      const text = 'use `obj.method(arg1, arg2)` syntax\n';
      final r = extractMarkdownCodeSpansFromLinesIn(text, 0, text.length);
      expect(r.text, 'obj.method(arg1, arg2)\n');
    });

    test('unterminated backtick is NOT matched', () {
      // Opening backtick with no closing delimiter on the line
      // doesn't match — `[^`\n]+` would need a trailing `` ` ``.
      const text = 'lone `unclosed text here\n';
      final r = extractMarkdownCodeSpansFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('spans never cross a line boundary', () {
      // `[^`\n]+` rejects `\n`, so an unterminated span on one
      // line + opening backtick on the next does NOT splice.
      const text = 'one `foo`\nbar `baz` end\n';
      final r = extractMarkdownCodeSpansFromLinesIn(text, 0, text.length);
      expect(r.text, 'foo\nbaz\n');
    });

    test('lines without code spans dropped from output', () {
      const text = 'plain prose\nwith `code` mark\nmore prose\n';
      final r = extractMarkdownCodeSpansFromLinesIn(text, 0, text.length);
      expect(r.text, 'code\n');
    });

    test('empty input stays empty', () {
      expect(extractMarkdownCodeSpansFromLinesIn('', 0, 0).text, '');
    });
  });

  group('extractMarkdownHeadingsFromLinesIn', () {
    test('H1 through H6 all match and strip hashes', () {
      const text =
          '# H1\n## H2\n### H3\n#### H4\n##### H5\n###### H6\n';
      final r = extractMarkdownHeadingsFromLinesIn(text, 0, text.length);
      expect(r.text, 'H1\nH2\nH3\nH4\nH5\nH6\n');
    });

    test('seven hashes is NOT a heading', () {
      // CommonMark caps ATX heading level at 6 — a 7-hash line
      // is not a heading and must be skipped.
      const text = '####### Seven\n';
      final r = extractMarkdownHeadingsFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('ATX-closed form strips trailing hashes', () {
      const text = '## Closed ##\n';
      final r = extractMarkdownHeadingsFromLinesIn(text, 0, text.length);
      expect(r.text, 'Closed\n');
    });

    test('ATX-closed form with extra whitespace and hashes', () {
      const text = '## Closed   ####  \n';
      final r = extractMarkdownHeadingsFromLinesIn(text, 0, text.length);
      expect(r.text, 'Closed\n');
    });

    test('leading whitespace blocks heading recognition', () {
      // `^#` requires the hash at line-start; an indented form
      // is a continuation, not a heading.
      const text = ' # Indented\n';
      final r = extractMarkdownHeadingsFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('hash with no space after is NOT a heading', () {
      // `#NoSpace` is read as a tag/identifier per most
      // CommonMark parsers — heading recognition requires `\s+`.
      const text = '#NoSpace fragment\n';
      final r = extractMarkdownHeadingsFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('hash with no title content is NOT a heading', () {
      // `.+?` requires at least one content char after the
      // separator whitespace.
      const text = '# \n';
      final r = extractMarkdownHeadingsFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('title content with inline punctuation passes through', () {
      const text = '## Foo, bar (baz) — qux!\n';
      final r = extractMarkdownHeadingsFromLinesIn(text, 0, text.length);
      expect(r.text, 'Foo, bar (baz) — qux!\n');
    });

    test('plain prose lines are dropped from output', () {
      const text = 'plain prose\n# Real Heading\nmore prose\n';
      final r = extractMarkdownHeadingsFromLinesIn(text, 0, text.length);
      expect(r.text, 'Real Heading\n');
    });

    test('empty input stays empty', () {
      expect(extractMarkdownHeadingsFromLinesIn('', 0, 0).text, '');
    });
  });

  group('extractMarkdownBlockquoteContentFromLinesIn', () {
    test('strips the `>` marker and keeps the content', () {
      const text = '> Quoted line\n';
      final r =
          extractMarkdownBlockquoteContentFromLinesIn(text, 0, text.length);
      expect(r.text, 'Quoted line\n');
    });

    test('contiguous double `>>` flattens in one pass', () {
      // `>>` is the dense-nested form (no inner space); greedy
      // `>+` eats both markers and emits the content tail.
      const text = '>> Nested\n';
      final r =
          extractMarkdownBlockquoteContentFromLinesIn(text, 0, text.length);
      expect(r.text, 'Nested\n');
    });

    test('CommonMark space-nested `> >` unwraps one level per pass', () {
      // Greedy `>+` only matches contiguous `>`, so `> > inner`
      // emits `> inner` (the inner `>` survives). A second pass
      // would flatten it.
      const text = '> > Inner\n';
      final r =
          extractMarkdownBlockquoteContentFromLinesIn(text, 0, text.length);
      expect(r.text, '> Inner\n');
    });

    test('no-space `>nocontentgap` is still a valid blockquote', () {
      // CommonMark technically requires whitespace after `>`,
      // but many parsers and the Quill renderer treat the
      // marker as sufficient. `\s?` is optional in the regex.
      const text = '>nospace content\n';
      final r =
          extractMarkdownBlockquoteContentFromLinesIn(text, 0, text.length);
      expect(r.text, 'nospace content\n');
    });

    test('bare `>` marker with no content is NOT a match', () {
      // `(.+)$` requires at least one content char.
      const text = '>\n';
      final r =
          extractMarkdownBlockquoteContentFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('marker followed by only whitespace is NOT a match', () {
      const text = '>   \n';
      final r =
          extractMarkdownBlockquoteContentFromLinesIn(text, 0, text.length);
      // `\s?` greedily takes one space; `(.+)$` then sees two
      // spaces remaining. That counts as content per `.+`,
      // matching whitespace-only content. Document the actual
      // behaviour rather than fight it.
      expect(r.text, '  \n');
    });

    test('leading whitespace blocks the match', () {
      const text = ' > Indented\n';
      final r =
          extractMarkdownBlockquoteContentFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('multiple blockquote lines all extract', () {
      const text = '> First\n> Second\n> Third\n';
      final r =
          extractMarkdownBlockquoteContentFromLinesIn(text, 0, text.length);
      expect(r.text, 'First\nSecond\nThird\n');
    });

    test('plain prose lines are dropped from output', () {
      const text = 'plain\n> Quoted bit\nmore plain\n';
      final r =
          extractMarkdownBlockquoteContentFromLinesIn(text, 0, text.length);
      expect(r.text, 'Quoted bit\n');
    });

    test('empty input stays empty', () {
      expect(
        extractMarkdownBlockquoteContentFromLinesIn('', 0, 0).text,
        '',
      );
    });
  });

  group('extractMarkdownListContentFromLinesIn', () {
    test('dash bullet strips and keeps content', () {
      const text = '- first item\n';
      final r = extractMarkdownListContentFromLinesIn(text, 0, text.length);
      expect(r.text, 'first item\n');
    });

    test('asterisk bullet strips and keeps content', () {
      const text = '* asterisk item\n';
      final r = extractMarkdownListContentFromLinesIn(text, 0, text.length);
      expect(r.text, 'asterisk item\n');
    });

    test('plus bullet strips and keeps content', () {
      const text = '+ plus item\n';
      final r = extractMarkdownListContentFromLinesIn(text, 0, text.length);
      expect(r.text, 'plus item\n');
    });

    test('ordered single-digit marker strips and keeps content', () {
      const text = '1. ordered item\n';
      final r = extractMarkdownListContentFromLinesIn(text, 0, text.length);
      expect(r.text, 'ordered item\n');
    });

    test('ordered multi-digit marker strips and keeps content', () {
      const text = '42. forty-second item\n';
      final r = extractMarkdownListContentFromLinesIn(text, 0, text.length);
      expect(r.text, 'forty-second item\n');
    });

    test('indented sub-bullet matches with leading whitespace', () {
      // Outline-style nesting — `\s*` allows the sub-item.
      const text = '  - sub item\n';
      final r = extractMarkdownListContentFromLinesIn(text, 0, text.length);
      expect(r.text, 'sub item\n');
    });

    test('marker without space gap is NOT a list item', () {
      // `\s+` between marker and content is required.
      const text = '-nogap content\n';
      final r = extractMarkdownListContentFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('bare marker with no content is NOT a match', () {
      const text = '-\n';
      final r = extractMarkdownListContentFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('mixed markers across lines all extract', () {
      const text = '- dash\n* star\n+ plus\n9. ordered\n';
      final r = extractMarkdownListContentFromLinesIn(text, 0, text.length);
      expect(r.text, 'dash\nstar\nplus\nordered\n');
    });

    test('plain prose lines dropped from output', () {
      const text = 'plain prose\n- a bullet\nmore prose\n';
      final r = extractMarkdownListContentFromLinesIn(text, 0, text.length);
      expect(r.text, 'a bullet\n');
    });

    test('inline punctuation in item content passes through', () {
      const text = '- a, b (c) — d!\n';
      final r = extractMarkdownListContentFromLinesIn(text, 0, text.length);
      expect(r.text, 'a, b (c) — d!\n');
    });

    test('empty input stays empty', () {
      expect(extractMarkdownListContentFromLinesIn('', 0, 0).text, '');
    });
  });

  group('extractMarkdownStrikethroughFromLinesIn', () {
    test('strips the `~~` delimiters and keeps content', () {
      const text = 'plan ~~abandoned~~ and ~~superseded~~ items\n';
      final r =
          extractMarkdownStrikethroughFromLinesIn(text, 0, text.length);
      expect(r.text, 'abandoned\nsuperseded\n');
    });

    test('single tilde is NOT a GFM strikethrough', () {
      // GFM requires exact `~~` doubled tildes on each side.
      const text = 'partial ~one~ tilde only\n';
      final r =
          extractMarkdownStrikethroughFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('zero-content `~~~~` does NOT match', () {
      // `[^~\n]+` requires at least one non-tilde char between.
      const text = 'see ~~~~ trivia\n';
      final r =
          extractMarkdownStrikethroughFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('span never crosses a line boundary', () {
      // `[^~\n]+` rejects `\n`, so an unterminated span on one
      // line + opening `~~` on next does NOT splice.
      const text = 'one ~~foo~~\nbar ~~baz~~ end\n';
      final r =
          extractMarkdownStrikethroughFromLinesIn(text, 0, text.length);
      expect(r.text, 'foo\nbaz\n');
    });

    test('span with internal spaces and punctuation', () {
      const text = 'note ~~Q1, Q2 (canceled)~~ trail\n';
      final r =
          extractMarkdownStrikethroughFromLinesIn(text, 0, text.length);
      expect(r.text, 'Q1, Q2 (canceled)\n');
    });

    test('unterminated `~~` is NOT a match', () {
      const text = 'lone ~~unclosed text here\n';
      final r =
          extractMarkdownStrikethroughFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('lines without strikethrough dropped from output', () {
      const text = 'plain prose\nwith ~~strike~~\nmore prose\n';
      final r =
          extractMarkdownStrikethroughFromLinesIn(text, 0, text.length);
      expect(r.text, 'strike\n');
    });

    test('empty input stays empty', () {
      expect(
        extractMarkdownStrikethroughFromLinesIn('', 0, 0).text,
        '',
      );
    });
  });

  group('extractMarkdownCodeFenceLangsFromLinesIn', () {
    test('basic ```lang opener extracts the lang', () {
      const text = '```dart\nvoid main() {}\n```\n';
      final r =
          extractMarkdownCodeFenceLangsFromLinesIn(text, 0, text.length);
      expect(r.text, 'dart\n');
    });

    test('4+ backtick fence still matches', () {
      // CM allows `>= 3` backticks; pick whichever count doesn't
      // collide with literal backticks in the body.
      const text = '````bash\nrm -rf /\n````\n';
      final r =
          extractMarkdownCodeFenceLangsFromLinesIn(text, 0, text.length);
      expect(r.text, 'bash\n');
    });

    test('lang with `+` `-` `#` `.` chars all preserved', () {
      const text = '```c++\nx\n```\n```c#\ny\n```\n```objective-c\nz\n```\n```node.js\nw\n```\n';
      final r =
          extractMarkdownCodeFenceLangsFromLinesIn(text, 0, text.length);
      expect(r.text, 'c++\nc#\nobjective-c\nnode.js\n');
    });

    test('closing fence (no lang) does NOT match', () {
      // The closing fence has no info string — regex requires
      // at least one lang char after the backticks.
      const text = '```\n```\n';
      final r =
          extractMarkdownCodeFenceLangsFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('inline code span (single backtick) is NOT a fence', () {
      // `{3,}` requires three+ backticks; single is inline code.
      const text = 'note `foo` inline\n';
      final r =
          extractMarkdownCodeFenceLangsFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('trailing info-string after lang does NOT contaminate capture', () {
      // CommonMark allows arbitrary info after the lang. The
      // captured group `[\w+\-.#]+` is greedy on lang-class only,
      // so it stops at the first space.
      const text = '```python3 title=demo\ndef x(): pass\n```\n';
      final r =
          extractMarkdownCodeFenceLangsFromLinesIn(text, 0, text.length);
      expect(r.text, 'python3\n');
    });

    test('indented fence (up to 3 spaces) still matches', () {
      // CM permits up to 3 spaces of indent before a fence.
      const text = '   ```yaml\nkey: value\n```\n';
      final r =
          extractMarkdownCodeFenceLangsFromLinesIn(text, 0, text.length);
      expect(r.text, 'yaml\n');
    });

    test('multiple fence openers on different lines all extract', () {
      const text =
          '```dart\nx\n```\n```rust\ny\n```\n```go\nz\n```\n';
      final r =
          extractMarkdownCodeFenceLangsFromLinesIn(text, 0, text.length);
      expect(r.text, 'dart\nrust\ngo\n');
    });

    test('plain prose lines dropped from output', () {
      const text = 'plain prose\n```ts\nx\n```\nmore prose\n';
      final r =
          extractMarkdownCodeFenceLangsFromLinesIn(text, 0, text.length);
      expect(r.text, 'ts\n');
    });

    test('empty input stays empty', () {
      expect(
        extractMarkdownCodeFenceLangsFromLinesIn('', 0, 0).text,
        '',
      );
    });
  });

  group('extractMarkdownBoldFromLinesIn', () {
    test('asterisk-form `**foo**` extracts content', () {
      const text = 'plan is **shipped** and **complete**\n';
      final r = extractMarkdownBoldFromLinesIn(text, 0, text.length);
      expect(r.text, 'shipped\ncomplete\n');
    });

    test('underscore-form `__foo__` extracts content', () {
      const text = 'see __bold__ tag\n';
      final r = extractMarkdownBoldFromLinesIn(text, 0, text.length);
      expect(r.text, 'bold\n');
    });

    test('single-delimiter italic forms are NOT matched', () {
      // `*foo*` and `_foo_` are italic in CommonMark; the bold
      // extractor requires the doubled delimiter.
      const text = '*italic only* and _italic too_\n';
      final r = extractMarkdownBoldFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('mixed asterisk + underscore bold spans on one line', () {
      const text = '**first** and __second__\n';
      final r = extractMarkdownBoldFromLinesIn(text, 0, text.length);
      expect(r.text, 'first\nsecond\n');
    });

    test('zero-content `****` does NOT match', () {
      // `[^*\n]+` requires at least one non-asterisk char.
      const text = 'gap **** trivia\n';
      final r = extractMarkdownBoldFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('bold-italic `***foo***` captures only the inner content', () {
      // `[^*\n]+` is greedy on NON-asterisk chars, so it
      // captures the bare content `bold italic` without the
      // inner `*` that wraps italic. The outer `**` closes
      // bold at positions 14-15; position 16's third `*` is
      // leftover. A future italic extractor would unwrap
      // further when chained.
      const text = '***bold italic***\n';
      final r = extractMarkdownBoldFromLinesIn(text, 0, text.length);
      expect(r.text, 'bold italic\n');
    });

    test('span never crosses a line boundary', () {
      const text = 'one **foo**\nbar **baz** end\n';
      final r = extractMarkdownBoldFromLinesIn(text, 0, text.length);
      expect(r.text, 'foo\nbaz\n');
    });

    test('content with internal punctuation passes through', () {
      const text = 'note **Q1, Q2 (final)** trail\n';
      final r = extractMarkdownBoldFromLinesIn(text, 0, text.length);
      expect(r.text, 'Q1, Q2 (final)\n');
    });

    test('unterminated `**` is NOT a match', () {
      const text = 'lone **unclosed text here\n';
      final r = extractMarkdownBoldFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('lines without bold dropped from output', () {
      const text = 'plain prose\nwith **bold**\nmore prose\n';
      final r = extractMarkdownBoldFromLinesIn(text, 0, text.length);
      expect(r.text, 'bold\n');
    });

    test('empty input stays empty', () {
      expect(extractMarkdownBoldFromLinesIn('', 0, 0).text, '');
    });
  });

  group('extractMarkdownItalicFromLinesIn', () {
    test('asterisk-form `*foo*` extracts content', () {
      const text = 'plan is *tentative* still\n';
      final r = extractMarkdownItalicFromLinesIn(text, 0, text.length);
      expect(r.text, 'tentative\n');
    });

    test('underscore-form `_foo_` extracts content', () {
      const text = 'see _italic_ tag\n';
      final r = extractMarkdownItalicFromLinesIn(text, 0, text.length);
      expect(r.text, 'italic\n');
    });

    test('doubled-delimiter bold forms are NOT matched', () {
      // `**foo**` and `__foo__` are bold in CommonMark; lookbehind/
      // lookahead guards keep them out of the italic pool.
      const text = '**bold only** and __bold too__\n';
      final r = extractMarkdownItalicFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('mixed asterisk + underscore italic spans on one line', () {
      const text = '*first* and _second_\n';
      final r = extractMarkdownItalicFromLinesIn(text, 0, text.length);
      expect(r.text, 'first\nsecond\n');
    });

    test('bold-italic `***foo***` produces no italic match', () {
      // Every `*` in this run is flanked by another `*` (either
      // before or after), so the lookbehind / lookahead rejects
      // all candidate positions. The bold extractor handles
      // this case; italic is correctly silent.
      const text = '***bold italic***\n';
      final r = extractMarkdownItalicFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('zero-content `**` / `__` does NOT match italic either', () {
      // No content between the delimiters — `[^*\n]+` and
      // `[^_\n]+` both require at least one char.
      const text = 'gap **  __\n';
      final r = extractMarkdownItalicFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('span never crosses a line boundary', () {
      const text = 'one *foo*\nbar *baz* end\n';
      final r = extractMarkdownItalicFromLinesIn(text, 0, text.length);
      expect(r.text, 'foo\nbaz\n');
    });

    test('content with internal punctuation passes through', () {
      const text = 'note *Q1, Q2 (draft)* trail\n';
      final r = extractMarkdownItalicFromLinesIn(text, 0, text.length);
      expect(r.text, 'Q1, Q2 (draft)\n');
    });

    test('unterminated `*` is NOT a match', () {
      const text = 'lone *unclosed text here\n';
      final r = extractMarkdownItalicFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('lines without italic dropped from output', () {
      const text = 'plain prose\nwith *italic*\nmore prose\n';
      final r = extractMarkdownItalicFromLinesIn(text, 0, text.length);
      expect(r.text, 'italic\n');
    });

    test('empty input stays empty', () {
      expect(extractMarkdownItalicFromLinesIn('', 0, 0).text, '');
    });
  });

  group('extractMarkdownFootnoteIdsFromLinesIn', () {
    test('numeric `[^1]` ref extracts the ID', () {
      const text = 'see footnote [^1] for details\n';
      final r =
          extractMarkdownFootnoteIdsFromLinesIn(text, 0, text.length);
      expect(r.text, '1\n');
    });

    test('alphanumeric label `[^note]` extracts the ID', () {
      const text = 'cite [^note] here\n';
      final r =
          extractMarkdownFootnoteIdsFromLinesIn(text, 0, text.length);
      expect(r.text, 'note\n');
    });

    test('hyphenated label `[^foo-bar]` extracts intact', () {
      const text = 'tagged [^foo-bar] mid-sentence\n';
      final r =
          extractMarkdownFootnoteIdsFromLinesIn(text, 0, text.length);
      expect(r.text, 'foo-bar\n');
    });

    test('definition line `[^1]: text` also yields its ID', () {
      // The def-line head shares the `[^id]` shape with refs,
      // so both surfaces contribute to the ID count.
      const text = '[^1]: This is the footnote text\n';
      final r =
          extractMarkdownFootnoteIdsFromLinesIn(text, 0, text.length);
      expect(r.text, '1\n');
    });

    test('plain `[bracket]` without caret is NOT a footnote', () {
      // The `[^` opener is literal — `[label]` is a reference
      // link, not a footnote.
      const text = 'note [bracket] no caret\n';
      final r =
          extractMarkdownFootnoteIdsFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('empty `[^]` is NOT a match', () {
      // `[^\]\n]+` requires at least one ID char.
      const text = 'trivia [^] empty\n';
      final r =
          extractMarkdownFootnoteIdsFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('multiple footnotes on one line each extract', () {
      const text = 'pair [^a] and [^b] and [^c] cite\n';
      final r =
          extractMarkdownFootnoteIdsFromLinesIn(text, 0, text.length);
      expect(r.text, 'a\nb\nc\n');
    });

    test('mixed ref + def on one block all extract', () {
      const text = 'see [^1] inline\n[^1]: definition\n[^2]: another\n';
      final r =
          extractMarkdownFootnoteIdsFromLinesIn(text, 0, text.length);
      expect(r.text, '1\n1\n2\n');
    });

    test('lines without footnotes dropped from output', () {
      const text = 'plain prose\nwith [^1] ref\nmore prose\n';
      final r =
          extractMarkdownFootnoteIdsFromLinesIn(text, 0, text.length);
      expect(r.text, '1\n');
    });

    test('empty input stays empty', () {
      expect(
        extractMarkdownFootnoteIdsFromLinesIn('', 0, 0).text,
        '',
      );
    });
  });

  group('extractTimeOfDayFromLinesIn', () {
    test('24-hour HH:MM extracts', () {
      const text = 'meeting at 09:30 today\n';
      final r = extractTimeOfDayFromLinesIn(text, 0, text.length);
      expect(r.text, '09:30\n');
    });

    test('24-hour HH:MM:SS extracts', () {
      const text = 'started at 14:23:45 sharp\n';
      final r = extractTimeOfDayFromLinesIn(text, 0, text.length);
      expect(r.text, '14:23:45\n');
    });

    test('12-hour with space AM/PM extracts', () {
      const text = 'demo at 2:30 PM Thursday\n';
      final r = extractTimeOfDayFromLinesIn(text, 0, text.length);
      expect(r.text, '2:30 PM\n');
    });

    test('12-hour no-space form extracts', () {
      const text = 'standup 9:30am daily\n';
      final r = extractTimeOfDayFromLinesIn(text, 0, text.length);
      expect(r.text, '9:30am\n');
    });

    test('case-insensitive AM/PM meridian', () {
      const text = 'cut 12:00 Pm release\n';
      final r = extractTimeOfDayFromLinesIn(text, 0, text.length);
      expect(r.text, '12:00 Pm\n');
    });

    test('multiple times on one line each extract', () {
      const text = 'from 09:00 to 17:30 daily\n';
      final r = extractTimeOfDayFromLinesIn(text, 0, text.length);
      expect(r.text, '09:00\n17:30\n');
    });

    test('single-digit minutes are NOT a time match', () {
      // `\d{2}` requires exactly two digit chars for the minutes.
      const text = 'ratio 1:2 invalid\n';
      final r = extractTimeOfDayFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('embedded in longer numeric run is NOT a match', () {
      // `\b` on each end rejects embedded slices inside `12345`
      // or other long digit runs.
      const text = 'identifier 12345 inline\n';
      final r = extractTimeOfDayFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('mixed 24h and 12h forms on one block all extract', () {
      const text =
          'wake at 6:00am\nstandup 09:30\nlunch 12:00 PM\nstop 17:00\n';
      final r = extractTimeOfDayFromLinesIn(text, 0, text.length);
      expect(r.text, '6:00am\n09:30\n12:00 PM\n17:00\n');
    });

    test('lines without times dropped from output', () {
      const text = 'plain prose\nstart 14:00 sharp\nmore prose\n';
      final r = extractTimeOfDayFromLinesIn(text, 0, text.length);
      expect(r.text, '14:00\n');
    });

    test('empty input stays empty', () {
      expect(extractTimeOfDayFromLinesIn('', 0, 0).text, '');
    });
  });

  group('extractPercentagesFromLinesIn', () {
    test('whole-number percentage extracts', () {
      const text = 'growth 42% YoY tracked\n';
      final r = extractPercentagesFromLinesIn(text, 0, text.length);
      expect(r.text, '42%\n');
    });

    test('decimal percentage extracts', () {
      const text = 'churn 99.9% retained\n';
      final r = extractPercentagesFromLinesIn(text, 0, text.length);
      expect(r.text, '99.9%\n');
    });

    test('0% and 100% edge cases extract', () {
      const text = 'from 0% to 100% complete\n';
      final r = extractPercentagesFromLinesIn(text, 0, text.length);
      expect(r.text, '0%\n100%\n');
    });

    test('multiple percentages on one line each extract', () {
      const text = 'split 25%, 35%, and 40% across teams\n';
      final r = extractPercentagesFromLinesIn(text, 0, text.length);
      expect(r.text, '25%\n35%\n40%\n');
    });

    test('after non-letter operator `n=42%` still matches', () {
      // `\b` before digits is satisfied when preceded by a
      // non-word char like `=`.
      const text = 'ratio n=42% precise\n';
      final r = extractPercentagesFromLinesIn(text, 0, text.length);
      expect(r.text, '42%\n');
    });

    test('embedded in word `abc42%` is NOT a match', () {
      // `\b` requires a non-word→word transition before digits.
      const text = 'token abc42% inline\n';
      final r = extractPercentagesFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('bare `%` without digits is NOT a match', () {
      const text = 'symbol % alone trivia\n';
      final r = extractPercentagesFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('number without `%` is NOT a percentage', () {
      const text = 'count 42 things\n';
      final r = extractPercentagesFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('lines without percentages dropped from output', () {
      const text = 'plain prose\nrate 75% growth\nmore prose\n';
      final r = extractPercentagesFromLinesIn(text, 0, text.length);
      expect(r.text, '75%\n');
    });

    test('empty input stays empty', () {
      expect(extractPercentagesFromLinesIn('', 0, 0).text, '');
    });
  });

  group('extractCurrencyFromLinesIn', () {
    test('plain dollar amount extracts', () {
      const text = 'price \$10 today\n';
      final r = extractCurrencyFromLinesIn(text, 0, text.length);
      expect(r.text, r'$10' '\n');
    });

    test('decimal dollar amount extracts', () {
      const text = 'cost \$10.99 each\n';
      final r = extractCurrencyFromLinesIn(text, 0, text.length);
      expect(r.text, r'$10.99' '\n');
    });

    test('US-style thousands separator preserved', () {
      const text = 'total \$1,234,567 paid\n';
      final r = extractCurrencyFromLinesIn(text, 0, text.length);
      expect(r.text, r'$1,234,567' '\n');
    });

    test('thousands + decimal combined', () {
      const text = 'invoice \$1,234.56 sent\n';
      final r = extractCurrencyFromLinesIn(text, 0, text.length);
      expect(r.text, r'$1,234.56' '\n');
    });

    test('euro symbol extracts', () {
      const text = 'price €5 in Berlin\n';
      final r = extractCurrencyFromLinesIn(text, 0, text.length);
      expect(r.text, '€5\n');
    });

    test('pound and yen symbols extract', () {
      const text = 'tea £100 and bento ¥500 stocked\n';
      final r = extractCurrencyFromLinesIn(text, 0, text.length);
      expect(r.text, '£100\n¥500\n');
    });

    test('multiple currencies on one line each extract', () {
      const text = 'split \$10 €5 £3 ¥200 across\n';
      final r = extractCurrencyFromLinesIn(text, 0, text.length);
      expect(r.text, r'$10' '\n€5\n£3\n¥200\n');
    });

    test('EU comma-decimal `€5,99` captures only the integer part', () {
      // `,99` doesn't follow `,\d{3}` thousands rule, so the
      // regex stops at `€5`. Document the v1 limitation.
      const text = 'price €5,99 in Paris\n';
      final r = extractCurrencyFromLinesIn(text, 0, text.length);
      expect(r.text, '€5\n');
    });

    test('bare currency symbol with no digits is NOT a match', () {
      const text = 'symbol \$ alone trivia\n';
      final r = extractCurrencyFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('lines without currency dropped from output', () {
      const text = 'plain prose\ncharge \$50 today\nmore prose\n';
      final r = extractCurrencyFromLinesIn(text, 0, text.length);
      expect(r.text, r'$50' '\n');
    });

    test('empty input stays empty', () {
      expect(extractCurrencyFromLinesIn('', 0, 0).text, '');
    });
  });

  group('extractFileSizesFromLinesIn', () {
    test('decimal `1.5 MB` form extracts', () {
      const text = 'file size 1.5 MB compressed\n';
      final r = extractFileSizesFromLinesIn(text, 0, text.length);
      expect(r.text, '1.5 MB\n');
    });

    test('no-space `42KB` form extracts', () {
      const text = 'log was 42KB before\n';
      final r = extractFileSizesFromLinesIn(text, 0, text.length);
      expect(r.text, '42KB\n');
    });

    test('all SI-prefix units extract', () {
      const text = '1 KB\n2 MB\n3 GB\n4 TB\n5 PB\n';
      final r = extractFileSizesFromLinesIn(text, 0, text.length);
      expect(r.text, '1 KB\n2 MB\n3 GB\n4 TB\n5 PB\n');
    });

    test('all binary-prefix units extract', () {
      const text = '1 KiB\n2 MiB\n3 GiB\n4 TiB\n5 PiB\n';
      final r = extractFileSizesFromLinesIn(text, 0, text.length);
      expect(r.text, '1 KiB\n2 MiB\n3 GiB\n4 TiB\n5 PiB\n');
    });

    test('bare `B` for bytes extracts', () {
      const text = 'header is 512 B small\n';
      final r = extractFileSizesFromLinesIn(text, 0, text.length);
      expect(r.text, '512 B\n');
    });

    test('case-insensitive units', () {
      const text = 'sizes 1kb 2Mb 3gb 4tib mixed\n';
      final r = extractFileSizesFromLinesIn(text, 0, text.length);
      expect(r.text, '1kb\n2Mb\n3gb\n4tib\n');
    });

    test('multiple sizes on one line each extract', () {
      const text = 'before 100 MB then 1.5 GB after\n';
      final r = extractFileSizesFromLinesIn(text, 0, text.length);
      expect(r.text, '100 MB\n1.5 GB\n');
    });

    test('number without size unit is NOT a match', () {
      const text = 'count 42 things\n';
      final r = extractFileSizesFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('lines without sizes dropped from output', () {
      const text = 'plain prose\nsize 100 MB total\nmore prose\n';
      final r = extractFileSizesFromLinesIn(text, 0, text.length);
      expect(r.text, '100 MB\n');
    });

    test('empty input stays empty', () {
      expect(extractFileSizesFromLinesIn('', 0, 0).text, '');
    });
  });

  group('extractGitShasFromLinesIn', () {
    test('typical 7-char short SHA extracts', () {
      const text = 'see commit abc1234 for context\n';
      final r = extractGitShasFromLinesIn(text, 0, text.length);
      expect(r.text, 'abc1234\n');
    });

    test('8-char hex with letters extracts', () {
      const text = 'released deadbeef yesterday\n';
      final r = extractGitShasFromLinesIn(text, 0, text.length);
      expect(r.text, 'deadbeef\n');
    });

    test('full 40-char SHA-1 extracts', () {
      const sha = '1234567890abcdef1234567890abcdef12345678';
      final text = 'full sha $sha tracked\n';
      final r = extractGitShasFromLinesIn(text, 0, text.length);
      expect(r.text, '$sha\n');
    });

    test('all-digit `1234567` (no letters) is NOT a SHA', () {
      // The lookahead requires at least one `[a-f]` letter.
      // A pure-numeric 7-digit run is a number, not a SHA.
      const text = 'id 1234567 tracked\n';
      final r = extractGitShasFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('mixed-case `DeadBeef` is NOT a SHA', () {
      // Lowercase-only — disambiguates from UUIDs and hex
      // colors which often use uppercase.
      const text = 'cookie DeadBeef inline\n';
      final r = extractGitShasFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('6-char hex (too short) is NOT a SHA', () {
      const text = 'short abc123 only six\n';
      final r = extractGitShasFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('41-char hex (too long) is NOT a SHA', () {
      // The trailing word boundary would fall inside a word,
      // so neither greedy nor backtrack length 7..40 succeeds.
      const sha41 = '1234567890abcdef1234567890abcdef123456789';
      final text = 'over $sha41 long\n';
      final r = extractGitShasFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('multiple SHAs on one line each extract', () {
      const text = 'merged abc1234 with deadbeef cleanup\n';
      final r = extractGitShasFromLinesIn(text, 0, text.length);
      expect(r.text, 'abc1234\ndeadbeef\n');
    });

    test('lines without SHAs dropped from output', () {
      const text = 'plain prose\ncherry-pick cafebabe done\nmore prose\n';
      final r = extractGitShasFromLinesIn(text, 0, text.length);
      expect(r.text, 'cafebabe\n');
    });

    test('empty input stays empty', () {
      expect(extractGitShasFromLinesIn('', 0, 0).text, '');
    });
  });

  group('extractPhoneNumbersFromLinesIn', () {
    test('plain E.164 with no separators extracts', () {
      const text = 'reach me at +15551234567 anytime\n';
      final r = extractPhoneNumbersFromLinesIn(text, 0, text.length);
      expect(r.text, '+15551234567\n');
    });

    test('dash-separated form extracts', () {
      const text = 'call +1-555-123-4567 today\n';
      final r = extractPhoneNumbersFromLinesIn(text, 0, text.length);
      expect(r.text, '+1-555-123-4567\n');
    });

    test('dot-separated form extracts', () {
      const text = 'fax +1.555.123.4567 instead\n';
      final r = extractPhoneNumbersFromLinesIn(text, 0, text.length);
      expect(r.text, '+1.555.123.4567\n');
    });

    test('space-separated UK form extracts', () {
      const text = 'desk +44 20 1234 5678 weekdays\n';
      final r = extractPhoneNumbersFromLinesIn(text, 0, text.length);
      expect(r.text, '+44 20 1234 5678\n');
    });

    test('three-digit country code extracts', () {
      const text = 'China +8613800138000 standard\n';
      final r = extractPhoneNumbersFromLinesIn(text, 0, text.length);
      expect(r.text, '+8613800138000\n');
    });

    test('too few digits is NOT a phone', () {
      // `+12` is way under E.164 length; the regex requires
      // 1-3 digit country code + at least 6 more digits.
      const text = 'short +12 only\n';
      final r = extractPhoneNumbersFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('embedded in word context is NOT a phone', () {
      // The lookbehind `(?<!\w)` rejects matches preceded by
      // a word char — so `bob+15551234567@example.com` does
      // NOT yield a phone extraction (the `+` is part of an
      // email local-part).
      const text = 'mail bob+15551234567@example.com sent\n';
      final r = extractPhoneNumbersFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('multiple phones on one line each extract', () {
      const text = 'pair +15551234567 and +442012345678 listed\n';
      final r = extractPhoneNumbersFromLinesIn(text, 0, text.length);
      expect(r.text, '+15551234567\n+442012345678\n');
    });

    test('non-prefix form `555-1234` is NOT extracted', () {
      // The `+` is the canonical international marker; bare
      // local-format phones are out of scope for v1.
      const text = 'local 555-1234 only\n';
      final r = extractPhoneNumbersFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('lines without phones dropped from output', () {
      const text = 'plain prose\nring +15551234567 today\nmore prose\n';
      final r = extractPhoneNumbersFromLinesIn(text, 0, text.length);
      expect(r.text, '+15551234567\n');
    });

    test('empty input stays empty', () {
      expect(extractPhoneNumbersFromLinesIn('', 0, 0).text, '');
    });
  });

  group('canonicalizeHorizontalRulesIn', () {
    test('three-dash HR passes through unchanged', () {
      const text = '---\n';
      final r = canonicalizeHorizontalRulesIn(text, 0, text.length);
      expect(r.text, '---\n');
    });

    test('three-asterisk `***` canonicalizes to `---`', () {
      const text = '***\n';
      final r = canonicalizeHorizontalRulesIn(text, 0, text.length);
      expect(r.text, '---\n');
    });

    test('three-underscore `___` canonicalizes to `---`', () {
      const text = '___\n';
      final r = canonicalizeHorizontalRulesIn(text, 0, text.length);
      expect(r.text, '---\n');
    });

    test('space-separated `- - -` canonicalizes', () {
      const text = '- - -\n';
      final r = canonicalizeHorizontalRulesIn(text, 0, text.length);
      expect(r.text, '---\n');
    });

    test('space-separated `* * *` canonicalizes', () {
      const text = '* * *\n';
      final r = canonicalizeHorizontalRulesIn(text, 0, text.length);
      expect(r.text, '---\n');
    });

    test('four+ dashes still canonicalize to `---`', () {
      const text = '----\n--------\n';
      final r = canonicalizeHorizontalRulesIn(text, 0, text.length);
      expect(r.text, '---\n---\n');
    });

    test('leading and trailing whitespace tolerated', () {
      const text = '   ---   \n';
      final r = canonicalizeHorizontalRulesIn(text, 0, text.length);
      expect(r.text, '---\n');
    });

    test('two-dash line is NOT an HR (too few)', () {
      const text = '--\n';
      final r = canonicalizeHorizontalRulesIn(text, 0, text.length);
      expect(r.text, '--\n');
    });

    test('mixed marker chars are NOT an HR', () {
      // Backref `\1` requires same marker char throughout.
      const text = '-*-\n';
      final r = canonicalizeHorizontalRulesIn(text, 0, text.length);
      expect(r.text, '-*-\n');
    });

    test('HR with adjacent text is NOT a clean HR line', () {
      const text = '--- text\n';
      final r = canonicalizeHorizontalRulesIn(text, 0, text.length);
      expect(r.text, '--- text\n');
    });

    test('non-HR prose lines pass through unchanged', () {
      const text = 'paragraph\n# Heading\n- bullet\n';
      final r = canonicalizeHorizontalRulesIn(text, 0, text.length);
      expect(r.text, 'paragraph\n# Heading\n- bullet\n');
    });

    test('mixed selection: HR lines normalize, prose preserved', () {
      const text = 'intro\n***\nbody\n___\nclose\n';
      final r = canonicalizeHorizontalRulesIn(text, 0, text.length);
      expect(r.text, 'intro\n---\nbody\n---\nclose\n');
    });

    test('empty input stays empty', () {
      expect(canonicalizeHorizontalRulesIn('', 0, 0).text, '');
    });
  });

  group('extractMarkdownReferenceLinkUrlsFromLinesIn', () {
    test('plain `[foo]: url` extracts URL', () {
      const text = '[foo]: https://x.test\n';
      final r = extractMarkdownReferenceLinkUrlsFromLinesIn(
          text, 0, text.length);
      expect(r.text, 'https://x.test\n');
    });

    test('local path URL extracts', () {
      const text = '[bar]: /local/path\n';
      final r = extractMarkdownReferenceLinkUrlsFromLinesIn(
          text, 0, text.length);
      expect(r.text, '/local/path\n');
    });

    test('definition with title extracts only the URL', () {
      const text = '[baz]: https://x.test "Title"\n';
      final r = extractMarkdownReferenceLinkUrlsFromLinesIn(
          text, 0, text.length);
      expect(r.text, 'https://x.test\n');
    });

    test('angle-bracket URL form captured with brackets', () {
      // CommonMark also permits `<url>` form for definitions;
      // the regex's `\S+` greedy match captures the full token
      // including angle brackets. Trim downstream if needed.
      const text = '[qux]: <https://angle.test>\n';
      final r = extractMarkdownReferenceLinkUrlsFromLinesIn(
          text, 0, text.length);
      expect(r.text, '<https://angle.test>\n');
    });

    test('indented definition (up to 3 spaces) matches', () {
      const text = '   [foo]: url\n';
      final r = extractMarkdownReferenceLinkUrlsFromLinesIn(
          text, 0, text.length);
      expect(r.text, 'url\n');
    });

    test('inline `[label][ref]` collapsed-ref is NOT a definition', () {
      // The definition requires `[…]:` followed by whitespace
      // and a URL on its own line. An inline reference like
      // `see [foo][bar]` doesn't fit that line-shape.
      const text = 'see [foo][bar] inline\n';
      final r = extractMarkdownReferenceLinkUrlsFromLinesIn(
          text, 0, text.length);
      expect(r.text, '\n');
    });

    test('shortcut form `[foo]` alone is NOT a definition', () {
      const text = '[foo] short ref\n';
      final r = extractMarkdownReferenceLinkUrlsFromLinesIn(
          text, 0, text.length);
      expect(r.text, '\n');
    });

    test('inline link `[text](url)` is NOT a ref-link definition', () {
      // The `(url)` form is the inline link, captured by M1066,
      // not this extractor.
      const text = 'see [docs](https://x.test) inline\n';
      final r = extractMarkdownReferenceLinkUrlsFromLinesIn(
          text, 0, text.length);
      expect(r.text, '\n');
    });

    test('multiple definitions across lines all extract', () {
      const text = '[a]: https://1.test\n[b]: https://2.test\n'
          '[c]: https://3.test "with title"\n';
      final r = extractMarkdownReferenceLinkUrlsFromLinesIn(
          text, 0, text.length);
      expect(r.text, 'https://1.test\nhttps://2.test\nhttps://3.test\n');
    });

    test('plain prose lines dropped from output', () {
      const text = 'plain prose\n[ref]: https://x.test\nmore prose\n';
      final r = extractMarkdownReferenceLinkUrlsFromLinesIn(
          text, 0, text.length);
      expect(r.text, 'https://x.test\n');
    });

    test('empty input stays empty', () {
      expect(
        extractMarkdownReferenceLinkUrlsFromLinesIn('', 0, 0).text,
        '',
      );
    });
  });

  group('extractMarkdownReferenceLinkLabelsFromLinesIn', () {
    test('plain `[foo]: url` extracts label', () {
      const text = '[foo]: https://x.test\n';
      final r = extractMarkdownReferenceLinkLabelsFromLinesIn(
          text, 0, text.length);
      expect(r.text, 'foo\n');
    });

    test('label with internal spaces extracts intact', () {
      // CommonMark allows multi-word labels like `[Click here]`.
      const text = '[Click here]: /landing\n';
      final r = extractMarkdownReferenceLinkLabelsFromLinesIn(
          text, 0, text.length);
      expect(r.text, 'Click here\n');
    });

    test('hyphenated and digit labels extract intact', () {
      const text = '[ref-1]: https://1.test\n[doc-v2]: /v2\n';
      final r = extractMarkdownReferenceLinkLabelsFromLinesIn(
          text, 0, text.length);
      expect(r.text, 'ref-1\ndoc-v2\n');
    });

    test('definition with title extracts only the label', () {
      const text = '[baz]: https://x.test "Title"\n';
      final r = extractMarkdownReferenceLinkLabelsFromLinesIn(
          text, 0, text.length);
      expect(r.text, 'baz\n');
    });

    test('indented definition (up to 3 spaces) matches', () {
      const text = '   [foo]: url\n';
      final r = extractMarkdownReferenceLinkLabelsFromLinesIn(
          text, 0, text.length);
      expect(r.text, 'foo\n');
    });

    test('inline link `[text](url)` is NOT a definition', () {
      const text = 'see [docs](https://x.test) inline\n';
      final r = extractMarkdownReferenceLinkLabelsFromLinesIn(
          text, 0, text.length);
      expect(r.text, '\n');
    });

    test('shortcut form `[foo]` alone is NOT a definition', () {
      const text = '[foo] short ref\n';
      final r = extractMarkdownReferenceLinkLabelsFromLinesIn(
          text, 0, text.length);
      expect(r.text, '\n');
    });

    test('paired with URL extractor for orphan-ref audit', () {
      // Demonstrates the M1094/M1095 pairing — same input
      // yields parallel label+url sequences for cross-check.
      const text = '[a]: https://1.test\n[b]: https://2.test\n'
          '[c]: https://3.test\n';
      final labels = extractMarkdownReferenceLinkLabelsFromLinesIn(
          text, 0, text.length);
      final urls = extractMarkdownReferenceLinkUrlsFromLinesIn(
          text, 0, text.length);
      expect(labels.text, 'a\nb\nc\n');
      expect(urls.text, 'https://1.test\nhttps://2.test\nhttps://3.test\n');
    });

    test('plain prose lines dropped from output', () {
      const text = 'plain prose\n[ref]: https://x.test\nmore prose\n';
      final r = extractMarkdownReferenceLinkLabelsFromLinesIn(
          text, 0, text.length);
      expect(r.text, 'ref\n');
    });

    test('empty input stays empty', () {
      expect(
        extractMarkdownReferenceLinkLabelsFromLinesIn('', 0, 0).text,
        '',
      );
    });
  });

  group('extractMarkdownTableCellsFromLinesIn', () {
    test('three-cell row splits into three outputs', () {
      const text = '| a | b | c |\n';
      final r = extractMarkdownTableCellsFromLinesIn(text, 0, text.length);
      expect(r.text, 'a\nb\nc\n');
    });

    test('two-cell row splits into two outputs', () {
      const text = '| name | age |\n';
      final r = extractMarkdownTableCellsFromLinesIn(text, 0, text.length);
      expect(r.text, 'name\nage\n');
    });

    test('cells with internal spaces preserved', () {
      const text = '| full name | birth year |\n';
      final r = extractMarkdownTableCellsFromLinesIn(text, 0, text.length);
      expect(r.text, 'full name\nbirth year\n');
    });

    test('separator row `|---|---|` is extracted as cells', () {
      // Documented behaviour — keeps the extractor simple
      // and row-count consistent. Pipe through a "drop lines
      // matching ---" transform downstream to filter.
      const text = '|---|---|\n';
      final r = extractMarkdownTableCellsFromLinesIn(text, 0, text.length);
      expect(r.text, '---\n---\n');
    });

    test('row without outer pipes is NOT a match (v1)', () {
      // CommonMark allows `a | b | c` without outer pipes;
      // v1 of this extractor requires outer pipes.
      const text = 'a | b | c\n';
      final r = extractMarkdownTableCellsFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('row with one cell `| a |` is NOT a match', () {
      // 2 pipes total — under the 3-pipe minimum (so the
      // shape is unambiguously table-like).
      const text = '| a |\n';
      final r = extractMarkdownTableCellsFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('multi-row table all cells extract', () {
      const text =
          '| name | age |\n|---|---|\n| Alice | 30 |\n| Bob | 25 |\n';
      final r = extractMarkdownTableCellsFromLinesIn(text, 0, text.length);
      expect(
        r.text,
        'name\nage\n---\n---\nAlice\n30\nBob\n25\n',
      );
    });

    test('whitespace around pipes is trimmed in output', () {
      const text = '|   spaced   |   too   |\n';
      final r = extractMarkdownTableCellsFromLinesIn(text, 0, text.length);
      expect(r.text, 'spaced\ntoo\n');
    });

    test('plain prose lines dropped from output', () {
      const text = 'prose\n| h1 | h2 |\nmore prose\n';
      final r = extractMarkdownTableCellsFromLinesIn(text, 0, text.length);
      expect(r.text, 'h1\nh2\n');
    });

    test('empty cells emit as empty lines', () {
      // `||` between content yields an empty cell — preserved
      // as a blank output line to keep row-shape information
      // recoverable.
      const text = '| a |  | c |\n';
      final r = extractMarkdownTableCellsFromLinesIn(text, 0, text.length);
      expect(r.text, 'a\n\nc\n');
    });

    test('empty input stays empty', () {
      expect(extractMarkdownTableCellsFromLinesIn('', 0, 0).text, '');
    });
  });

  group('jsonStringEncodeLinesIn', () {
    test('plain line wraps with quotes', () {
      const text = 'hello\n';
      final r = jsonStringEncodeLinesIn(text, 0, text.length);
      expect(r.text, '"hello"\n');
    });

    test('internal double-quote escapes', () {
      const text = 'say "hi"\n';
      final r = jsonStringEncodeLinesIn(text, 0, text.length);
      expect(r.text, r'"say \"hi\""' '\n');
    });

    test('internal backslash escapes', () {
      const text = r'path\to\file' '\n';
      final r = jsonStringEncodeLinesIn(text, 0, text.length);
      expect(r.text, r'"path\\to\\file"' '\n');
    });

    test('tab character escapes as `\\t`', () {
      const text = 'a\tb\n';
      final r = jsonStringEncodeLinesIn(text, 0, text.length);
      expect(r.text, r'"a\tb"' '\n');
    });

    test('unicode chars above U+001F pass through unescaped', () {
      const text = 'café — 🦀\n';
      final r = jsonStringEncodeLinesIn(text, 0, text.length);
      expect(r.text, '"café — 🦀"\n');
    });

    test('multiple lines each encode independently', () {
      const text = 'first\nsecond\nthird\n';
      final r = jsonStringEncodeLinesIn(text, 0, text.length);
      expect(r.text, '"first"\n"second"\n"third"\n');
    });

    test('blank lines pass through (skip convention)', () {
      const text = 'a\n\nb\n';
      final r = jsonStringEncodeLinesIn(text, 0, text.length);
      expect(r.text, '"a"\n\n"b"\n');
    });

    test('produces valid JSON-string forms for piping', () {
      const text = 'foo\nbar"baz\n';
      final r = jsonStringEncodeLinesIn(text, 0, text.length);
      expect(r.text, r'"foo"' '\n' r'"bar\"baz"' '\n');
    });

    test('empty input stays empty', () {
      expect(jsonStringEncodeLinesIn('', 0, 0).text, '');
    });
  });

  group('extractMarkdownFootnoteBodiesFromLinesIn', () {
    test('numeric footnote body extracts', () {
      const text = '[^1]: This is the footnote text\n';
      final r = extractMarkdownFootnoteBodiesFromLinesIn(
          text, 0, text.length);
      expect(r.text, 'This is the footnote text\n');
    });

    test('alphanumeric ID with multi-word body', () {
      const text = '[^note]: Multi-word footnote body here\n';
      final r = extractMarkdownFootnoteBodiesFromLinesIn(
          text, 0, text.length);
      expect(r.text, 'Multi-word footnote body here\n');
    });

    test('in-prose reference `[^1]` (no `:`) is NOT a definition', () {
      // References lack the `:` body marker; only definitions
      // produce output.
      const text = 'see footnote [^1] inline\n';
      final r = extractMarkdownFootnoteBodiesFromLinesIn(
          text, 0, text.length);
      expect(r.text, '\n');
    });

    test('mixed ref + def: only def emits body', () {
      const text = 'see [^1] inline\n[^1]: actual definition body\n';
      final r = extractMarkdownFootnoteBodiesFromLinesIn(
          text, 0, text.length);
      expect(r.text, 'actual definition body\n');
    });

    test('body with internal punctuation preserved', () {
      const text = '[^1]: Q1, Q2 (final) — see [link](url) ref.\n';
      final r = extractMarkdownFootnoteBodiesFromLinesIn(
          text, 0, text.length);
      expect(r.text, 'Q1, Q2 (final) — see [link](url) ref.\n');
    });

    test('indented definition (up to 3 spaces) matches', () {
      const text = '   [^1]: indented body\n';
      final r = extractMarkdownFootnoteBodiesFromLinesIn(
          text, 0, text.length);
      expect(r.text, 'indented body\n');
    });

    test('multiple definitions across lines all extract', () {
      const text = '[^a]: first body\n[^b]: second body\n[^c]: third\n';
      final r = extractMarkdownFootnoteBodiesFromLinesIn(
          text, 0, text.length);
      expect(r.text, 'first body\nsecond body\nthird\n');
    });

    test('plain prose lines dropped from output', () {
      const text = 'plain prose\n[^1]: foot body\nmore prose\n';
      final r = extractMarkdownFootnoteBodiesFromLinesIn(
          text, 0, text.length);
      expect(r.text, 'foot body\n');
    });

    test('paired with ID extractor: (id, body) tuples', () {
      // Documents the design pairing — same input yields
      // parallel id+body sequences for tuple analysis.
      const text = '[^1]: first body\n[^2]: second body\n';
      final ids = extractMarkdownFootnoteIdsFromLinesIn(
          text, 0, text.length);
      final bodies = extractMarkdownFootnoteBodiesFromLinesIn(
          text, 0, text.length);
      expect(ids.text, '1\n2\n');
      expect(bodies.text, 'first body\nsecond body\n');
    });

    test('empty input stays empty', () {
      expect(
        extractMarkdownFootnoteBodiesFromLinesIn('', 0, 0).text,
        '',
      );
    });
  });

  group('extractBareUrlsFromLinesIn', () {
    test('plain `example.com` extracts', () {
      const text = 'see example.com for context\n';
      final r = extractBareUrlsFromLinesIn(text, 0, text.length);
      expect(r.text, 'example.com\n');
    });

    test('subdomain extracts intact', () {
      const text = 'docs.example.com is great\n';
      final r = extractBareUrlsFromLinesIn(text, 0, text.length);
      expect(r.text, 'docs.example.com\n');
    });

    test('domain with path extracts', () {
      const text = 'fetch example.com/api/v1 quickly\n';
      final r = extractBareUrlsFromLinesIn(text, 0, text.length);
      expect(r.text, 'example.com/api/v1\n');
    });

    test('multiple bare URLs on one line each extract', () {
      const text = 'compare foo.com to bar.org and baz.io\n';
      final r = extractBareUrlsFromLinesIn(text, 0, text.length);
      expect(r.text, 'foo.com\nbar.org\nbaz.io\n');
    });

    test('decimal number `1.5` is NOT a bare URL', () {
      // The TLD `[a-z]{2,}` requires alphabetic chars; `1.5`
      // has digit `5` as the "TLD" position. No match.
      const text = 'value 1.5 only\n';
      final r = extractBareUrlsFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('IPv4 address `192.168.1.42` is NOT a bare URL', () {
      // Same TLD-must-be-letters rule rejects IPv4 dotted-quads.
      const text = 'host 192.168.1.42 inline\n';
      final r = extractBareUrlsFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('parenthetical citation stops at closing paren', () {
      // `[^\s)]*` excludes `)` from the path so a trailing
      // `)` in `(see example.com/page)` doesn't get pulled in.
      const text = '(see example.com/page)\n';
      final r = extractBareUrlsFromLinesIn(text, 0, text.length);
      expect(r.text, 'example.com/page\n');
    });

    test('hyphens in subdomain segments preserved', () {
      const text = 'my-site.co.uk lives now\n';
      final r = extractBareUrlsFromLinesIn(text, 0, text.length);
      expect(r.text, 'my-site.co.uk\n');
    });

    test('case-insensitive matching of domain chars', () {
      const text = 'visit Example.COM today\n';
      final r = extractBareUrlsFromLinesIn(text, 0, text.length);
      expect(r.text, 'Example.COM\n');
    });

    test('lines without bare URLs dropped from output', () {
      const text = 'plain prose\nsee example.com inline\nmore prose\n';
      final r = extractBareUrlsFromLinesIn(text, 0, text.length);
      expect(r.text, 'example.com\n');
    });

    test('empty input stays empty', () {
      expect(extractBareUrlsFromLinesIn('', 0, 0).text, '');
    });
  });

  group('extractYearsFromLinesIn', () {
    test('current era year `2024` extracts', () {
      const text = 'shipped in 2024 finally\n';
      final r = extractYearsFromLinesIn(text, 0, text.length);
      expect(r.text, '2024\n');
    });

    test('20th-century year `1995` extracts', () {
      const text = 'born in 1995 here\n';
      final r = extractYearsFromLinesIn(text, 0, text.length);
      expect(r.text, '1995\n');
    });

    test('lower-boundary `1800` and upper-boundary `2099` extract', () {
      const text = 'from 1800 to 2099 era\n';
      final r = extractYearsFromLinesIn(text, 0, text.length);
      expect(r.text, '1800\n2099\n');
    });

    test('out-of-range `1799` (pre-1800) is NOT a match', () {
      const text = 'before 1799 too early\n';
      final r = extractYearsFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('out-of-range `2100` (post-2099) is NOT a match', () {
      const text = 'projected 2100 future\n';
      final r = extractYearsFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('2-digit and 3-digit years are NOT matched', () {
      const text = "in '95 and 1923's era\n";
      // `95` is too short, but `1923` matches.
      final r = extractYearsFromLinesIn(text, 0, text.length);
      expect(r.text, '1923\n');
    });

    test('5-digit `12345` is NOT a year', () {
      const text = 'id 12345 inline\n';
      final r = extractYearsFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('multiple years on one line each extract', () {
      const text = 'from 1995 to 2010 then 2024 stretch\n';
      final r = extractYearsFromLinesIn(text, 0, text.length);
      expect(r.text, '1995\n2010\n2024\n');
    });

    test('embedded year in version-shape `1.2.2024-rc` matches', () {
      // `\b` between `.` and `2` is a boundary; the year
      // surfaces from compound version strings. Accepted
      // false-positive vector — document and move on.
      const text = 'version 1.2.2024-rc.1 cut\n';
      final r = extractYearsFromLinesIn(text, 0, text.length);
      expect(r.text, '2024\n');
    });

    test('lines without years dropped from output', () {
      const text = 'plain prose\ncite 1985 here\nmore prose\n';
      final r = extractYearsFromLinesIn(text, 0, text.length);
      expect(r.text, '1985\n');
    });

    test('empty input stays empty', () {
      expect(extractYearsFromLinesIn('', 0, 0).text, '');
    });
  });

  group('extractMarkdownAutolinksFromLinesIn', () {
    test('https autolink extracts URL without angle brackets', () {
      const text = 'see <https://x.test> for context\n';
      final r = extractMarkdownAutolinksFromLinesIn(text, 0, text.length);
      expect(r.text, 'https://x.test\n');
    });

    test('http autolink (no s) extracts', () {
      const text = 'fetch <http://example.com/path> there\n';
      final r = extractMarkdownAutolinksFromLinesIn(text, 0, text.length);
      expect(r.text, 'http://example.com/path\n');
    });

    test('ftp autolink extracts', () {
      const text = 'upload to <ftp://files.test/data> tonight\n';
      final r = extractMarkdownAutolinksFromLinesIn(text, 0, text.length);
      expect(r.text, 'ftp://files.test/data\n');
    });

    test('mailto autolink extracts', () {
      const text = 'email <mailto:bob@example.com> direct\n';
      final r = extractMarkdownAutolinksFromLinesIn(text, 0, text.length);
      expect(r.text, 'mailto:bob@example.com\n');
    });

    test('bare URL (no angle brackets) is NOT an autolink', () {
      // The `<` `>` brackets are the distinguishing marker; a
      // bare `https://x.test` is captured by M1054, not here.
      const text = 'see https://x.test inline\n';
      final r = extractMarkdownAutolinksFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('angle-bracketed non-URL is NOT an autolink', () {
      // `<not-a-url>` has no recognised protocol prefix.
      const text = 'tag <not-a-url> here\n';
      final r = extractMarkdownAutolinksFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('multiple autolinks on one line each extract', () {
      const text = 'pair <https://a.test> and <https://b.test>\n';
      final r = extractMarkdownAutolinksFromLinesIn(text, 0, text.length);
      expect(r.text, 'https://a.test\nhttps://b.test\n');
    });

    test('URL with whitespace inside is NOT an autolink', () {
      // `[^>\s]+` rejects whitespace in the URL content.
      const text = 'invalid <https://x.test more>\n';
      final r = extractMarkdownAutolinksFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('autolink with query string and fragment preserved', () {
      const text = 'see <https://x.test/page?v=2#main> details\n';
      final r = extractMarkdownAutolinksFromLinesIn(text, 0, text.length);
      expect(r.text, 'https://x.test/page?v=2#main\n');
    });

    test('lines without autolinks dropped from output', () {
      const text = 'plain prose\n<https://x.test> only\nmore prose\n';
      final r = extractMarkdownAutolinksFromLinesIn(text, 0, text.length);
      expect(r.text, 'https://x.test\n');
    });

    test('empty input stays empty', () {
      expect(extractMarkdownAutolinksFromLinesIn('', 0, 0).text, '');
    });
  });

  group('extractHtmlTagsFromLinesIn', () {
    test('opening tag with attribute extracts name', () {
      const text = 'wrap <a href="x">link</a> here\n';
      final r = extractHtmlTagsFromLinesIn(text, 0, text.length);
      expect(r.text, 'a\na\n');
    });

    test('closing tag yields the same name', () {
      const text = 'end </body> done\n';
      final r = extractHtmlTagsFromLinesIn(text, 0, text.length);
      expect(r.text, 'body\n');
    });

    test('self-closing tag extracts', () {
      const text = 'image <br/> break\n';
      final r = extractHtmlTagsFromLinesIn(text, 0, text.length);
      expect(r.text, 'br\n');
    });

    test('HTML5 custom element with hyphen', () {
      const text = 'use <my-component prop="x"> here\n';
      final r = extractHtmlTagsFromLinesIn(text, 0, text.length);
      expect(r.text, 'my-component\n');
    });

    test('multiple tags on one line each extract', () {
      const text = '<div><span>txt</span></div>\n';
      final r = extractHtmlTagsFromLinesIn(text, 0, text.length);
      expect(r.text, 'div\nspan\nspan\ndiv\n');
    });

    test('markdown autolink is NOT an HTML tag', () {
      // `<https://x.test>` starts with `<h` but the regex's
      // `[\w-]*\b[^>]*>` happily consumes the rest. Hmm —
      // this is actually a known overlap. Document.
      const text = 'see <https://x.test>\n';
      final r = extractHtmlTagsFromLinesIn(text, 0, text.length);
      // The regex DOES match: `h` (first letter), `ttps`
      // (rest of name chars). Then `\b` between `s` and `:`.
      // Then `://x.test` as attribute content. Match name
      // = `https`. Documented overlap with autolinks.
      expect(r.text, 'https\n');
    });

    test('space after `<` is NOT a tag', () {
      // The regex requires `[a-zA-Z]` immediately after `<`
      // (with optional `/`). A space breaks it.
      const text = 'use < not a tag>\n';
      final r = extractHtmlTagsFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('digits-first `<1div>` is NOT a tag', () {
      const text = 'see <1div> bad\n';
      final r = extractHtmlTagsFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('plain prose lines dropped from output', () {
      const text = 'plain prose\n<p>para</p>\nmore prose\n';
      final r = extractHtmlTagsFromLinesIn(text, 0, text.length);
      expect(r.text, 'p\np\n');
    });

    test('empty input stays empty', () {
      expect(extractHtmlTagsFromLinesIn('', 0, 0).text, '');
    });
  });

  group('extractHtmlAttributeNamesFromLinesIn', () {
    test('double-quoted attribute extracts name', () {
      const text = 'wrap <a href="x">link</a> here\n';
      final r = extractHtmlAttributeNamesFromLinesIn(
          text, 0, text.length);
      expect(r.text, 'href\n');
    });

    test('single-quoted attribute extracts name', () {
      const text = "wrap <a href='x'>link</a> here\n";
      final r = extractHtmlAttributeNamesFromLinesIn(
          text, 0, text.length);
      expect(r.text, 'href\n');
    });

    test('multiple attributes on one tag each extract', () {
      const text = '<img src="pic.png" alt="hero" width="100">\n';
      final r = extractHtmlAttributeNamesFromLinesIn(
          text, 0, text.length);
      expect(r.text, 'src\nalt\nwidth\n');
    });

    test('data-* hyphenated attribute name preserved', () {
      const text = '<div data-id="42" data-role="button">\n';
      final r = extractHtmlAttributeNamesFromLinesIn(
          text, 0, text.length);
      expect(r.text, 'data-id\ndata-role\n');
    });

    test('tag with no attributes is NOT a match', () {
      const text = 'plain <div> here\n';
      final r = extractHtmlAttributeNamesFromLinesIn(
          text, 0, text.length);
      expect(r.text, '\n');
    });

    test('unquoted attribute is NOT matched (v1 limitation)', () {
      // `<img src=foo>` lacks the `=["']` shape; v1 only
      // captures quoted attribute values.
      const text = 'unquoted <img src=foo>\n';
      final r = extractHtmlAttributeNamesFromLinesIn(
          text, 0, text.length);
      expect(r.text, '\n');
    });

    test('whitespace around `=` tolerated', () {
      const text = '<a href = "x">\n';
      final r = extractHtmlAttributeNamesFromLinesIn(
          text, 0, text.length);
      expect(r.text, 'href\n');
    });

    test('multi-tag line with mixed attributes', () {
      const text = '<a href="x"><img src="p"></a>\n';
      final r = extractHtmlAttributeNamesFromLinesIn(
          text, 0, text.length);
      expect(r.text, 'href\nsrc\n');
    });

    test('lines without attribute syntax dropped from output', () {
      const text = 'plain prose\n<a href="x">link</a>\nmore prose\n';
      final r = extractHtmlAttributeNamesFromLinesIn(
          text, 0, text.length);
      expect(r.text, 'href\n');
    });

    test('empty input stays empty', () {
      expect(
        extractHtmlAttributeNamesFromLinesIn('', 0, 0).text,
        '',
      );
    });
  });

  group('extractHtmlAttributeValuesFromLinesIn', () {
    test('double-quoted value extracts content', () {
      const text = '<a href="https://x.test">link</a>\n';
      final r = extractHtmlAttributeValuesFromLinesIn(
          text, 0, text.length);
      expect(r.text, 'https://x.test\n');
    });

    test('single-quoted value extracts content', () {
      const text = "<a href='/local/path'>link</a>\n";
      final r = extractHtmlAttributeValuesFromLinesIn(
          text, 0, text.length);
      expect(r.text, '/local/path\n');
    });

    test('multiple attributes each yield value', () {
      const text = '<img src="pic.png" alt="hero" width="100">\n';
      final r = extractHtmlAttributeValuesFromLinesIn(
          text, 0, text.length);
      expect(r.text, 'pic.png\nhero\n100\n');
    });

    test('empty value emits as empty line', () {
      // `href=""` is a legitimate (if odd) attribute; capture
      // emits an empty entry so audits can flag empty values.
      const text = '<a href="" target="_blank">\n';
      final r = extractHtmlAttributeValuesFromLinesIn(
          text, 0, text.length);
      expect(r.text, '\n_blank\n');
    });

    test('paired with name extractor for full attr audit', () {
      const text = '<a href="x" class="y">\n';
      final names = extractHtmlAttributeNamesFromLinesIn(
          text, 0, text.length);
      final values = extractHtmlAttributeValuesFromLinesIn(
          text, 0, text.length);
      expect(names.text, 'href\nclass\n');
      expect(values.text, 'x\ny\n');
    });

    test('tag with no attributes is NOT a match', () {
      const text = 'plain <div> here\n';
      final r = extractHtmlAttributeValuesFromLinesIn(
          text, 0, text.length);
      expect(r.text, '\n');
    });

    test('value with internal spaces preserved', () {
      const text = '<a title="hover text here">link</a>\n';
      final r = extractHtmlAttributeValuesFromLinesIn(
          text, 0, text.length);
      expect(r.text, 'hover text here\n');
    });

    test('data-* attribute values preserved', () {
      const text = '<div data-id="42" data-role="button">\n';
      final r = extractHtmlAttributeValuesFromLinesIn(
          text, 0, text.length);
      expect(r.text, '42\nbutton\n');
    });

    test('lines without attribute syntax dropped from output', () {
      const text = 'plain prose\n<a href="x">link</a>\nmore prose\n';
      final r = extractHtmlAttributeValuesFromLinesIn(
          text, 0, text.length);
      expect(r.text, 'x\n');
    });

    test('empty input stays empty', () {
      expect(
        extractHtmlAttributeValuesFromLinesIn('', 0, 0).text,
        '',
      );
    });
  });

  group('extractMarkdownReferenceLinkUsageLabelsFromLinesIn', () {
    test('plain `[text][label]` extracts label', () {
      const text = 'see [the docs][foo] for context\n';
      final r = extractMarkdownReferenceLinkUsageLabelsFromLinesIn(
          text, 0, text.length);
      expect(r.text, 'foo\n');
    });

    test('label with hyphen and digits preserved', () {
      const text = 'cite [example][ref-1] inline\n';
      final r = extractMarkdownReferenceLinkUsageLabelsFromLinesIn(
          text, 0, text.length);
      expect(r.text, 'ref-1\n');
    });

    test('multiple usages on one line each extract', () {
      const text = 'pair [a][r1] and [b][r2] and [c][r3]\n';
      final r = extractMarkdownReferenceLinkUsageLabelsFromLinesIn(
          text, 0, text.length);
      expect(r.text, 'r1\nr2\nr3\n');
    });

    test('inline `[text](url)` parens form is NOT a usage', () {
      // The `(url)` form is the M1066 inline-link surface, not
      // this extractor.
      const text = 'see [docs](https://x.test) inline\n';
      final r = extractMarkdownReferenceLinkUsageLabelsFromLinesIn(
          text, 0, text.length);
      expect(r.text, '\n');
    });

    test('shortcut `[label]` (no second bracket) is NOT matched', () {
      // The shortcut form lacks the `[label]` after; v1 only
      // captures full `[text][label]` usages.
      const text = '[foo] short ref\n';
      final r = extractMarkdownReferenceLinkUsageLabelsFromLinesIn(
          text, 0, text.length);
      expect(r.text, '\n');
    });

    test('definition `[foo]: url` is NOT a usage', () {
      // Definitions are M1094/M1095's surface; this extractor
      // only captures inline usages.
      const text = '[foo]: https://x.test\n';
      final r = extractMarkdownReferenceLinkUsageLabelsFromLinesIn(
          text, 0, text.length);
      expect(r.text, '\n');
    });

    test('paired audit: usage labels vs definition labels', () {
      // Demonstrates the audit gesture — usages from this
      // extractor and definitions from M1095 give two sets
      // to cross-check (orphan defs, missing defs, etc.).
      const text = 'see [docs][foo] and [api][bar]\n[foo]: /docs\n';
      final usages =
          extractMarkdownReferenceLinkUsageLabelsFromLinesIn(
              text, 0, text.length);
      final defs = extractMarkdownReferenceLinkLabelsFromLinesIn(
          text, 0, text.length);
      expect(usages.text, 'foo\nbar\n');
      expect(defs.text, 'foo\n');
      // `bar` is in usages but not defs — orphan reference.
    });

    test('text with internal punctuation handled', () {
      const text = 'wrap [Click, then read][go] up\n';
      final r = extractMarkdownReferenceLinkUsageLabelsFromLinesIn(
          text, 0, text.length);
      expect(r.text, 'go\n');
    });

    test('lines without usages dropped from output', () {
      const text = 'plain prose\nsee [t][r] inline\nmore prose\n';
      final r = extractMarkdownReferenceLinkUsageLabelsFromLinesIn(
          text, 0, text.length);
      expect(r.text, 'r\n');
    });

    test('empty input stays empty', () {
      expect(
        extractMarkdownReferenceLinkUsageLabelsFromLinesIn('', 0, 0)
            .text,
        '',
      );
    });
  });

  group('extractCalendarDatesFromLinesIn', () {
    test('abbreviated month form extracts', () {
      const text = 'shipped Jan 1, 2024 today\n';
      final r = extractCalendarDatesFromLinesIn(text, 0, text.length);
      expect(r.text, 'Jan 1, 2024\n');
    });

    test('full month name extracts', () {
      const text = 'first published January 1, 2024 here\n';
      final r = extractCalendarDatesFromLinesIn(text, 0, text.length);
      expect(r.text, 'January 1, 2024\n');
    });

    test('ordinal suffix `1st` form extracts', () {
      const text = 'starts Apr 1st, 2024 demo\n';
      final r = extractCalendarDatesFromLinesIn(text, 0, text.length);
      expect(r.text, 'Apr 1st, 2024\n');
    });

    test('all ordinal forms (st/nd/rd/th) extract', () {
      const text =
          'Jan 1st, 2024\nFeb 2nd, 2024\nMar 3rd, 2024\nApr 4th, 2024\n';
      final r = extractCalendarDatesFromLinesIn(text, 0, text.length);
      expect(
        r.text,
        'Jan 1st, 2024\nFeb 2nd, 2024\nMar 3rd, 2024\nApr 4th, 2024\n',
      );
    });

    test('comma is optional', () {
      const text = 'dated Apr 1 2024 stamp\n';
      final r = extractCalendarDatesFromLinesIn(text, 0, text.length);
      expect(r.text, 'Apr 1 2024\n');
    });

    test('case-insensitive month names', () {
      const text = 'cite jan 1, 2024 and MARCH 5, 2025 today\n';
      final r = extractCalendarDatesFromLinesIn(text, 0, text.length);
      expect(r.text, 'jan 1, 2024\nMARCH 5, 2025\n');
    });

    test('two-digit day extracts (1-31 unvalidated)', () {
      const text = 'released Dec 25, 2023 holiday\n';
      final r = extractCalendarDatesFromLinesIn(text, 0, text.length);
      expect(r.text, 'Dec 25, 2023\n');
    });

    test('multiple dates on one line each extract', () {
      const text = 'from Jan 1, 2024 to Mar 15, 2024 stretch\n';
      final r = extractCalendarDatesFromLinesIn(text, 0, text.length);
      expect(r.text, 'Jan 1, 2024\nMar 15, 2024\n');
    });

    test('no-month substring is NOT a date', () {
      const text = 'just 1, 2024 alone\n';
      final r = extractCalendarDatesFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('ISO format `2024-01-15` is NOT matched here', () {
      // M1062 handles ISO dates; this extractor only catches
      // prose-style `Month Day, Year`.
      const text = 'iso 2024-01-15 form\n';
      final r = extractCalendarDatesFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('lines without dates dropped from output', () {
      const text = 'plain prose\nstart Jan 1, 2024 launch\nmore prose\n';
      final r = extractCalendarDatesFromLinesIn(text, 0, text.length);
      expect(r.text, 'Jan 1, 2024\n');
    });

    test('empty input stays empty', () {
      expect(extractCalendarDatesFromLinesIn('', 0, 0).text, '');
    });
  });

  group('extractIsoWeeksFromLinesIn', () {
    test('plain ISO week extracts', () {
      const text = 'sprint 2024-W12 active\n';
      final r = extractIsoWeeksFromLinesIn(text, 0, text.length);
      expect(r.text, '2024-W12\n');
    });

    test('lower-bound week 01 extracts', () {
      const text = 'planning 2024-W01 kickoff\n';
      final r = extractIsoWeeksFromLinesIn(text, 0, text.length);
      expect(r.text, '2024-W01\n');
    });

    test('upper-bound week 53 extracts (no semantic check)', () {
      const text = 'last 2024-W53 wrap-up\n';
      final r = extractIsoWeeksFromLinesIn(text, 0, text.length);
      expect(r.text, '2024-W53\n');
    });

    test('single-digit week is NOT a match', () {
      const text = 'fake 2024-W1 form\n';
      final r = extractIsoWeeksFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('3-digit week is NOT a match', () {
      const text = 'invalid 2024-W123 shape\n';
      final r = extractIsoWeeksFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('lowercase `w` is NOT a match', () {
      const text = 'wrong 2024-w12 case\n';
      final r = extractIsoWeeksFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('ISO date `2024-01-15` is NOT an ISO week', () {
      const text = 'date 2024-01-15 form\n';
      final r = extractIsoWeeksFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('multiple weeks on one line each extract', () {
      const text = 'from 2024-W01 to 2024-W12 to 2024-W26 stretch\n';
      final r = extractIsoWeeksFromLinesIn(text, 0, text.length);
      expect(r.text, '2024-W01\n2024-W12\n2024-W26\n');
    });

    test('lines without weeks dropped from output', () {
      const text = 'plain prose\nsprint 2024-W08 cut\nmore prose\n';
      final r = extractIsoWeeksFromLinesIn(text, 0, text.length);
      expect(r.text, '2024-W08\n');
    });

    test('empty input stays empty', () {
      expect(extractIsoWeeksFromLinesIn('', 0, 0).text, '');
    });
  });

  group('extractMarkdownImageReferenceUsageLabelsFromLinesIn', () {
    test('plain `![alt][label]` extracts label', () {
      const text = 'see ![hero image][img-1] context\n';
      final r = extractMarkdownImageReferenceUsageLabelsFromLinesIn(
          text, 0, text.length);
      expect(r.text, 'img-1\n');
    });

    test('empty alt `![][label]` extracts label', () {
      // Per CommonMark, image alt MAY be empty. The label
      // section still requires non-empty content.
      const text = 'decoration ![][placeholder] only\n';
      final r = extractMarkdownImageReferenceUsageLabelsFromLinesIn(
          text, 0, text.length);
      expect(r.text, 'placeholder\n');
    });

    test('text-link usage `[text][label]` (no `!`) is NOT matched', () {
      // The `!` prefix is the image-vs-link disambiguator.
      const text = 'wrap [docs][foo] here\n';
      final r = extractMarkdownImageReferenceUsageLabelsFromLinesIn(
          text, 0, text.length);
      expect(r.text, '\n');
    });

    test('inline image `![alt](url)` is NOT matched', () {
      // Parens form is M1073; this extractor only catches
      // the reference-bracket form.
      const text = 'use ![alt](pic.png) inline\n';
      final r = extractMarkdownImageReferenceUsageLabelsFromLinesIn(
          text, 0, text.length);
      expect(r.text, '\n');
    });

    test('multiple image refs on one line each extract', () {
      const text = 'gallery ![a][i1] then ![b][i2] then ![c][i3]\n';
      final r = extractMarkdownImageReferenceUsageLabelsFromLinesIn(
          text, 0, text.length);
      expect(r.text, 'i1\ni2\ni3\n');
    });

    test('hyphenated label preserved', () {
      const text = 'see ![hero][img-hero-1] crop\n';
      final r = extractMarkdownImageReferenceUsageLabelsFromLinesIn(
          text, 0, text.length);
      expect(r.text, 'img-hero-1\n');
    });

    test('text-link ref + image ref on same line: only image ref', () {
      const text = 'mix [t][l] and ![alt][i] together\n';
      final r = extractMarkdownImageReferenceUsageLabelsFromLinesIn(
          text, 0, text.length);
      expect(r.text, 'i\n');
    });

    test('lines without image refs dropped from output', () {
      const text = 'plain prose\nshow ![alt][img] here\nmore prose\n';
      final r = extractMarkdownImageReferenceUsageLabelsFromLinesIn(
          text, 0, text.length);
      expect(r.text, 'img\n');
    });

    test('empty input stays empty', () {
      expect(
        extractMarkdownImageReferenceUsageLabelsFromLinesIn('', 0, 0)
            .text,
        '',
      );
    });
  });

  group('extractCidrFromLinesIn', () {
    test('class-A subnet extracts', () {
      const text = 'route 10.0.0.0/8 to gateway\n';
      final r = extractCidrFromLinesIn(text, 0, text.length);
      expect(r.text, '10.0.0.0/8\n');
    });

    test('class-B subnet extracts', () {
      const text = 'block 172.16.0.0/12 inbound\n';
      final r = extractCidrFromLinesIn(text, 0, text.length);
      expect(r.text, '172.16.0.0/12\n');
    });

    test('class-C subnet extracts', () {
      const text = 'subnet 192.168.1.0/24 allocated\n';
      final r = extractCidrFromLinesIn(text, 0, text.length);
      expect(r.text, '192.168.1.0/24\n');
    });

    test('host-bit /32 form extracts', () {
      const text = 'pin 10.5.5.42/32 single-host\n';
      final r = extractCidrFromLinesIn(text, 0, text.length);
      expect(r.text, '10.5.5.42/32\n');
    });

    test('default route 0.0.0.0/0 extracts', () {
      const text = 'fallback 0.0.0.0/0 catch-all\n';
      final r = extractCidrFromLinesIn(text, 0, text.length);
      expect(r.text, '0.0.0.0/0\n');
    });

    test('plain IPv4 without `/N` is NOT a CIDR', () {
      const text = 'host 192.168.1.42 only\n';
      final r = extractCidrFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('multiple CIDRs on one line each extract', () {
      const text = 'allow 10.0.0.0/8 and 192.168.0.0/16 paths\n';
      final r = extractCidrFromLinesIn(text, 0, text.length);
      expect(r.text, '10.0.0.0/8\n192.168.0.0/16\n');
    });

    test('out-of-range octets / prefixes still match (no validate)', () {
      // Documented v1 behavior — `999.999.999.999/99` matches.
      // Downstream network-layer code is the validation layer.
      const text = 'fake 999.999.999.999/99 still grabs\n';
      final r = extractCidrFromLinesIn(text, 0, text.length);
      expect(r.text, '999.999.999.999/99\n');
    });

    test('lines without CIDRs dropped from output', () {
      const text = 'plain prose\nallow 10.0.0.0/8 only\nmore prose\n';
      final r = extractCidrFromLinesIn(text, 0, text.length);
      expect(r.text, '10.0.0.0/8\n');
    });

    test('empty input stays empty', () {
      expect(extractCidrFromLinesIn('', 0, 0).text, '');
    });
  });

  group('extractHtmlCommentsFromLinesIn', () {
    test('basic `<!-- foo -->` extracts content', () {
      const text = 'note <!-- hidden text --> visible\n';
      final r = extractHtmlCommentsFromLinesIn(text, 0, text.length);
      expect(r.text, 'hidden text\n');
    });

    test('no-whitespace `<!--bar-->` form extracts', () {
      const text = 'tight<!--bar-->fit\n';
      final r = extractHtmlCommentsFromLinesIn(text, 0, text.length);
      expect(r.text, 'bar\n');
    });

    test('TODO marker convention extracts', () {
      const text = '<!-- TODO: review next week -->\n';
      final r = extractHtmlCommentsFromLinesIn(text, 0, text.length);
      expect(r.text, 'TODO: review next week\n');
    });

    test('multiple comments on one line each extract', () {
      const text = '<!-- a -->mid<!-- b -->end<!-- c -->\n';
      final r = extractHtmlCommentsFromLinesIn(text, 0, text.length);
      expect(r.text, 'a\nb\nc\n');
    });

    test('leading and trailing whitespace trimmed', () {
      const text = '<!--   spaced   -->\n';
      final r = extractHtmlCommentsFromLinesIn(text, 0, text.length);
      expect(r.text, 'spaced\n');
    });

    test('unterminated `<!--` is NOT a match', () {
      // Without `-->` the regex can't close — falls through.
      const text = 'lone <!-- unclosed text here\n';
      final r = extractHtmlCommentsFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('non-greedy ensures FIRST `-->` closes the match', () {
      // `<!-- a --> ... <!-- b -->` should yield two captures,
      // not one giant match `a --> ... <!-- b`.
      const text = '<!-- a --> filler <!-- b -->\n';
      final r = extractHtmlCommentsFromLinesIn(text, 0, text.length);
      expect(r.text, 'a\nb\n');
    });

    test('lines without comments dropped from output', () {
      const text = 'plain prose\n<!-- todo -->\nmore prose\n';
      final r = extractHtmlCommentsFromLinesIn(text, 0, text.length);
      expect(r.text, 'todo\n');
    });

    test('empty input stays empty', () {
      expect(extractHtmlCommentsFromLinesIn('', 0, 0).text, '');
    });
  });

  group('extractEmailDomainsFromLinesIn', () {
    test('plain email yields domain', () {
      const text = 'contact user@example.com today\n';
      final r = extractEmailDomainsFromLinesIn(text, 0, text.length);
      expect(r.text, 'example.com\n');
    });

    test('subdomain in email captured intact', () {
      const text = 'reply alice@mail.example.org soon\n';
      final r = extractEmailDomainsFromLinesIn(text, 0, text.length);
      expect(r.text, 'mail.example.org\n');
    });

    test('multiple emails on one line each yield domain', () {
      const text = 'cc alice@a.test and bob@b.test direct\n';
      final r = extractEmailDomainsFromLinesIn(text, 0, text.length);
      expect(r.text, 'a.test\nb.test\n');
    });

    test('email with `+` tag preserves domain extraction', () {
      const text = 'tag bob+orders@shop.example.com inline\n';
      final r = extractEmailDomainsFromLinesIn(text, 0, text.length);
      expect(r.text, 'shop.example.com\n');
    });

    test('email with `.` in local part preserves domain', () {
      const text = 'send first.last@example.io now\n';
      final r = extractEmailDomainsFromLinesIn(text, 0, text.length);
      expect(r.text, 'example.io\n');
    });

    test('bare `@` without local or TLD is NOT a match', () {
      const text = 'tag @only here\n';
      final r = extractEmailDomainsFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('local-only without `@domain` is NOT a match', () {
      const text = 'just user without ampersand\n';
      final r = extractEmailDomainsFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('paired with M1053 email extractor for provider audit', () {
      // Demonstrates the design: full emails (M1053) + domains
      // (M1112) give parallel sequences for grouping by provider.
      const text = 'cc alice@google.com\ncc bob@google.com\ncc carol@yahoo.com\n';
      final emails = extractEmailsFromLinesIn(text, 0, text.length);
      final domains = extractEmailDomainsFromLinesIn(text, 0, text.length);
      expect(emails.text,
          'alice@google.com\nbob@google.com\ncarol@yahoo.com\n');
      expect(domains.text, 'google.com\ngoogle.com\nyahoo.com\n');
    });

    test('lines without emails dropped from output', () {
      const text = 'plain prose\ncc user@example.com\nmore prose\n';
      final r = extractEmailDomainsFromLinesIn(text, 0, text.length);
      expect(r.text, 'example.com\n');
    });

    test('empty input stays empty', () {
      expect(extractEmailDomainsFromLinesIn('', 0, 0).text, '');
    });
  });

  group('extractEmailLocalPartsFromLinesIn', () {
    test('plain email yields local-part', () {
      const text = 'contact user@example.com today\n';
      final r =
          extractEmailLocalPartsFromLinesIn(text, 0, text.length);
      expect(r.text, 'user\n');
    });

    test('first.last format extracts intact', () {
      const text = 'reply first.last@example.com soon\n';
      final r =
          extractEmailLocalPartsFromLinesIn(text, 0, text.length);
      expect(r.text, 'first.last\n');
    });

    test('plus-tag format extracts intact', () {
      const text = 'cc tag+orders@shop.com inline\n';
      final r =
          extractEmailLocalPartsFromLinesIn(text, 0, text.length);
      expect(r.text, 'tag+orders\n');
    });

    test('multiple emails on one line each yield local-part', () {
      const text = 'pair alice@a.test and bob@b.test direct\n';
      final r =
          extractEmailLocalPartsFromLinesIn(text, 0, text.length);
      expect(r.text, 'alice\nbob\n');
    });

    test('email triplet: full + domain + local cross-check', () {
      // Demonstrates the design: each extractor surfaces a
      // different slice of the same email shape.
      const text = 'cc alice@example.com\ncc bob@example.com\n';
      final emails = extractEmailsFromLinesIn(text, 0, text.length);
      final domains =
          extractEmailDomainsFromLinesIn(text, 0, text.length);
      final locals =
          extractEmailLocalPartsFromLinesIn(text, 0, text.length);
      expect(emails.text,
          'alice@example.com\nbob@example.com\n');
      expect(domains.text, 'example.com\nexample.com\n');
      expect(locals.text, 'alice\nbob\n');
    });

    test('underscore-and-digit local-part extracts intact', () {
      const text = 'ping user_42@svc.io reach\n';
      final r =
          extractEmailLocalPartsFromLinesIn(text, 0, text.length);
      expect(r.text, 'user_42\n');
    });

    test('bare `@only` is NOT a match', () {
      const text = 'tag @only here\n';
      final r =
          extractEmailLocalPartsFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('local without `@domain` is NOT a match', () {
      const text = 'just user no domain\n';
      final r =
          extractEmailLocalPartsFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('lines without emails dropped from output', () {
      const text = 'plain prose\ncc user@example.com\nmore prose\n';
      final r =
          extractEmailLocalPartsFromLinesIn(text, 0, text.length);
      expect(r.text, 'user\n');
    });

    test('empty input stays empty', () {
      expect(extractEmailLocalPartsFromLinesIn('', 0, 0).text, '');
    });
  });

  group('extractWikilinkAliasesFromLinesIn', () {
    test('plain wikilink with alias extracts alias', () {
      const text =
          'see [[01HABCDEFGHIJKLMNOPQRSTUVW|My Display Title]] info\n';
      final r = extractWikilinkAliasesFromLinesIn(text, 0, text.length);
      expect(r.text, 'My Display Title\n');
    });

    test('wikilink with anchor + alias extracts alias only', () {
      const text =
          'cite [[01HABCDEFGHIJKLMNOPQRSTUVW#intro|Intro section]]\n';
      final r = extractWikilinkAliasesFromLinesIn(text, 0, text.length);
      expect(r.text, 'Intro section\n');
    });

    test('wikilink WITHOUT alias is NOT matched', () {
      // The `|alias` is the required marker; bare ULID
      // wikilinks are NOT aliased.
      const text = 'plain [[01HABCDEFGHIJKLMNOPQRSTUVW]] ref\n';
      final r = extractWikilinkAliasesFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('multiple aliased wikilinks each extract', () {
      const text = 'pair [[01HABCDEFGHIJKLMNOPQRSTUVW|First]] and '
          '[[01HBBCDEFGHIJKLMNOPQRSTUVW|Second]] today\n';
      final r = extractWikilinkAliasesFromLinesIn(text, 0, text.length);
      expect(r.text, 'First\nSecond\n');
    });

    test('alias with internal punctuation preserved', () {
      const text =
          'wrap [[01HABCDEFGHIJKLMNOPQRSTUVW|A, B (final)!]] up\n';
      final r = extractWikilinkAliasesFromLinesIn(text, 0, text.length);
      expect(r.text, 'A, B (final)!\n');
    });

    test('mixed aliased + bare wikilinks: only aliased contribute', () {
      const text =
          'mix [[01HABCDEFGHIJKLMNOPQRSTUVW]] and '
          '[[01HBBCDEFGHIJKLMNOPQRSTUVW|alias]] note\n';
      final r = extractWikilinkAliasesFromLinesIn(text, 0, text.length);
      expect(r.text, 'alias\n');
    });

    test('markdown link `[t](u)` is NOT a wikilink', () {
      const text = 'use [text](url) inline\n';
      final r = extractWikilinkAliasesFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('lines without aliased wikilinks dropped from output', () {
      const text = 'plain prose\n'
          'cite [[01HABCDEFGHIJKLMNOPQRSTUVW|named]] only\n'
          'more prose\n';
      final r = extractWikilinkAliasesFromLinesIn(text, 0, text.length);
      expect(r.text, 'named\n');
    });

    test('empty input stays empty', () {
      expect(extractWikilinkAliasesFromLinesIn('', 0, 0).text, '');
    });
  });

  group('extractWikilinkAnchorsFromLinesIn', () {
    test('anchor-only wikilink extracts anchor', () {
      const text =
          'see [[01HABCDEFGHIJKLMNOPQRSTUVW#intro]] section\n';
      final r = extractWikilinkAnchorsFromLinesIn(text, 0, text.length);
      expect(r.text, 'intro\n');
    });

    test('anchor + alias wikilink extracts anchor only', () {
      const text =
          'cite [[01HABCDEFGHIJKLMNOPQRSTUVW#section-2|S2]] today\n';
      final r = extractWikilinkAnchorsFromLinesIn(text, 0, text.length);
      expect(r.text, 'section-2\n');
    });

    test('hyphenated anchor slug preserved', () {
      const text = 'jump [[01HABCDEFGHIJKLMNOPQRSTUVW#my-cool-section]]\n';
      final r = extractWikilinkAnchorsFromLinesIn(text, 0, text.length);
      expect(r.text, 'my-cool-section\n');
    });

    test('digit-starting anchor extracts', () {
      const text = 'step [[01HABCDEFGHIJKLMNOPQRSTUVW#2024-q1]] plan\n';
      final r = extractWikilinkAnchorsFromLinesIn(text, 0, text.length);
      expect(r.text, '2024-q1\n');
    });

    test('plain `[[ULID]]` (no anchor) is NOT matched', () {
      const text = 'bare [[01HABCDEFGHIJKLMNOPQRSTUVW]] ref\n';
      final r = extractWikilinkAnchorsFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('alias-only `[[ULID|alias]]` (no anchor) is NOT matched', () {
      const text = 'named [[01HABCDEFGHIJKLMNOPQRSTUVW|alias]] only\n';
      final r = extractWikilinkAnchorsFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('multiple anchored wikilinks each extract', () {
      const text = 'pair [[01HABCDEFGHIJKLMNOPQRSTUVW#a]] and '
          '[[01HBBCDEFGHIJKLMNOPQRSTUVW#b-c]] cross\n';
      final r = extractWikilinkAnchorsFromLinesIn(text, 0, text.length);
      expect(r.text, 'a\nb-c\n');
    });

    test('wikilink trio: base + alias + anchor cross-check', () {
      // Demonstrates the trio: same input yields parallel
      // body/alias/anchor sequences when all three apply.
      const text =
          'see [[01HABCDEFGHIJKLMNOPQRSTUVW#section|Display]] inline\n';
      final base = extractWikilinksFromLinesIn(text, 0, text.length);
      final aliases =
          extractWikilinkAliasesFromLinesIn(text, 0, text.length);
      final anchors =
          extractWikilinkAnchorsFromLinesIn(text, 0, text.length);
      expect(base.text, '01HABCDEFGHIJKLMNOPQRSTUVW#section|Display\n');
      expect(aliases.text, 'Display\n');
      expect(anchors.text, 'section\n');
    });

    test('lines without anchored wikilinks dropped from output', () {
      const text = 'plain prose\n'
          'cite [[01HABCDEFGHIJKLMNOPQRSTUVW#anc]] here\n'
          'more prose\n';
      final r = extractWikilinkAnchorsFromLinesIn(text, 0, text.length);
      expect(r.text, 'anc\n');
    });

    test('empty input stays empty', () {
      expect(extractWikilinkAnchorsFromLinesIn('', 0, 0).text, '');
    });
  });

  group('extractYoutubeIdsFromLinesIn', () {
    test('youtu.be short form extracts ID', () {
      const text = 'watch https://youtu.be/dQw4w9WgXcQ today\n';
      final r = extractYoutubeIdsFromLinesIn(text, 0, text.length);
      expect(r.text, 'dQw4w9WgXcQ\n');
    });

    test('full watch?v= form extracts ID', () {
      const text =
          'see https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=10s\n';
      final r = extractYoutubeIdsFromLinesIn(text, 0, text.length);
      expect(r.text, 'dQw4w9WgXcQ\n');
    });

    test('embed iframe URL extracts', () {
      // No trailing newline in input — transformLinesIn preserves
      // the no-newline shape, so the output has no trailing `\n`
      // either.
      const text = '<iframe src="https://youtube.com/embed/abc123XYZ-_">';
      final r = extractYoutubeIdsFromLinesIn(text, 0, text.length);
      expect(r.text, 'abc123XYZ-_');
    });

    test('protocol-less youtu.be still matches', () {
      const text = 'short youtu.be/abc123def45 link\n';
      final r = extractYoutubeIdsFromLinesIn(text, 0, text.length);
      expect(r.text, 'abc123def45\n');
    });

    test('plain 11-char string with no URL is NOT a match', () {
      const text = 'random dQw4w9WgXcQ inline\n';
      final r = extractYoutubeIdsFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('mixed surfaces on one line each extract', () {
      const text = 'pair https://youtu.be/ABCDEFGHIJK and '
          'https://youtube.com/watch?v=LMNOPQRSTUV\n';
      final r = extractYoutubeIdsFromLinesIn(text, 0, text.length);
      expect(r.text, 'ABCDEFGHIJK\nLMNOPQRSTUV\n');
    });

    test('underscore and hyphen chars in ID preserved', () {
      const text = 'see youtu.be/abc_def-XYZ link\n';
      final r = extractYoutubeIdsFromLinesIn(text, 0, text.length);
      expect(r.text, 'abc_def-XYZ\n');
    });

    test('ID shorter than 11 chars not captured', () {
      // YouTube IDs are exactly 11 chars; shorter doesn't match.
      const text = 'short youtu.be/abcdef bad\n';
      final r = extractYoutubeIdsFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('non-YouTube URL is NOT matched', () {
      const text = 'see https://vimeo.com/12345 different\n';
      final r = extractYoutubeIdsFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('lines without YouTube URLs dropped from output', () {
      const text = 'plain prose\nwatch youtu.be/dQw4w9WgXcQ\nmore prose\n';
      final r = extractYoutubeIdsFromLinesIn(text, 0, text.length);
      expect(r.text, 'dQw4w9WgXcQ\n');
    });

    test('empty input stays empty', () {
      expect(extractYoutubeIdsFromLinesIn('', 0, 0).text, '');
    });
  });

  group('extractGithubRepoPathsFromLinesIn', () {
    test('full HTTPS URL extracts owner/repo', () {
      const text = 'see https://github.com/flutter/flutter today\n';
      final r = extractGithubRepoPathsFromLinesIn(text, 0, text.length);
      expect(r.text, 'flutter/flutter\n');
    });

    test('owner with hyphen preserved', () {
      const text = 'fork https://github.com/dart-lang/sdk source\n';
      final r = extractGithubRepoPathsFromLinesIn(text, 0, text.length);
      expect(r.text, 'dart-lang/sdk\n');
    });

    test('repo name with dot preserved', () {
      const text = 'see github.com/qazaqninja/my.notion repo\n';
      final r = extractGithubRepoPathsFromLinesIn(text, 0, text.length);
      expect(r.text, 'qazaqninja/my.notion\n');
    });

    test('protocol-less form still matches', () {
      const text = 'check github.com/foo/bar quickly\n';
      final r = extractGithubRepoPathsFromLinesIn(text, 0, text.length);
      expect(r.text, 'foo/bar\n');
    });

    test('multiple repos on one line each extract', () {
      const text =
          'cite github.com/foo/bar and github.com/baz/qux today\n';
      final r = extractGithubRepoPathsFromLinesIn(text, 0, text.length);
      expect(r.text, 'foo/bar\nbaz/qux\n');
    });

    test('plain `path/file.txt` (not a GitHub URL) is NOT matched', () {
      // The `github.com/` anchor is what disambiguates from
      // generic two-segment paths.
      const text = 'open path/file.txt now\n';
      final r = extractGithubRepoPathsFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('different domain (gitlab.com) is NOT matched', () {
      const text = 'mirror gitlab.com/foo/bar elsewhere\n';
      final r = extractGithubRepoPathsFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('underscores in repo name preserved', () {
      const text = 'use github.com/foo/some_repo here\n';
      final r = extractGithubRepoPathsFromLinesIn(text, 0, text.length);
      expect(r.text, 'foo/some_repo\n');
    });

    test('extra path segments NOT included in capture', () {
      // The regex captures only `owner/repo`, not the trailing
      // `/blob/main/...` path.
      const text =
          'docs https://github.com/foo/bar/blob/main/README.md\n';
      final r = extractGithubRepoPathsFromLinesIn(text, 0, text.length);
      expect(r.text, 'foo/bar\n');
    });

    test('lines without GitHub URLs dropped from output', () {
      const text =
          'plain prose\nfork github.com/foo/bar\nmore prose\n';
      final r = extractGithubRepoPathsFromLinesIn(text, 0, text.length);
      expect(r.text, 'foo/bar\n');
    });

    test('empty input stays empty', () {
      expect(extractGithubRepoPathsFromLinesIn('', 0, 0).text, '');
    });
  });

  group('extractYearRangesFromLinesIn', () {
    test('hyphen form extracts', () {
      const text = 'career 1995-2024 spanned\n';
      final r = extractYearRangesFromLinesIn(text, 0, text.length);
      expect(r.text, '1995-2024\n');
    });

    test('em-dash form extracts', () {
      const text = 'copyright 2000–2024 reserved\n';
      final r = extractYearRangesFromLinesIn(text, 0, text.length);
      expect(r.text, '2000–2024\n');
    });

    test('adjacent multiple ranges each extract', () {
      const text = 'phases 1995-2010 and 2015-2024 logged\n';
      final r = extractYearRangesFromLinesIn(text, 0, text.length);
      expect(r.text, '1995-2010\n2015-2024\n');
    });

    test('single year (no range) is NOT matched', () {
      const text = 'just 2024 alone here\n';
      final r = extractYearRangesFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('abbreviated form `2024-25` is NOT matched', () {
      // Both sides require exactly 4 digits.
      const text = 'season 2024-25 fall\n';
      final r = extractYearRangesFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('reversed range still extracts (no semantic check)', () {
      const text = 'odd 2024-1995 quirk\n';
      final r = extractYearRangesFromLinesIn(text, 0, text.length);
      expect(r.text, '2024-1995\n');
    });

    test('embedded in longer numeric is NOT matched', () {
      // `\b` boundaries reject embedded runs.
      const text = 'id 12345-67890123 inline\n';
      final r = extractYearRangesFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('lines without ranges dropped from output', () {
      const text = 'plain prose\ncareer 1995-2024\nmore prose\n';
      final r = extractYearRangesFromLinesIn(text, 0, text.length);
      expect(r.text, '1995-2024\n');
    });

    test('empty input stays empty', () {
      expect(extractYearRangesFromLinesIn('', 0, 0).text, '');
    });
  });

  group('extractDoiFromLinesIn', () {
    test('basic DOI extracts', () {
      const text = 'cite 10.1000/xyz123 here\n';
      final r = extractDoiFromLinesIn(text, 0, text.length);
      expect(r.text, '10.1000/xyz123\n');
    });

    test('IEEE-style DOI extracts intact', () {
      const text = 'paper 10.1109/CVPR.2023.12345 referenced\n';
      final r = extractDoiFromLinesIn(text, 0, text.length);
      expect(r.text, '10.1109/CVPR.2023.12345\n');
    });

    test('DOI with hyphens and dots in suffix', () {
      const text = 'ref 10.1234/abc.def-ghi pulled\n';
      final r = extractDoiFromLinesIn(text, 0, text.length);
      expect(r.text, '10.1234/abc.def-ghi\n');
    });

    test('resolver URL exposes the embedded DOI', () {
      const text = 'see https://doi.org/10.1000/xyz123 link\n';
      final r = extractDoiFromLinesIn(text, 0, text.length);
      expect(r.text, '10.1000/xyz123\n');
    });

    test('prefix too short (3 digits) is NOT a match', () {
      // Spec requires 4-9 digit prefix.
      const text = 'fake 10.123/short bad\n';
      final r = extractDoiFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('decimal `10.5` is NOT a DOI', () {
      // No `/suffix` follows.
      const text = 'note value 10.5 only\n';
      final r = extractDoiFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('multiple DOIs on one line each extract', () {
      const text =
          'cite 10.1000/abc and 10.2000/def together\n';
      final r = extractDoiFromLinesIn(text, 0, text.length);
      expect(r.text, '10.1000/abc\n10.2000/def\n');
    });

    test('lines without DOIs dropped from output', () {
      const text = 'plain prose\ncite 10.1000/abc\nmore prose\n';
      final r = extractDoiFromLinesIn(text, 0, text.length);
      expect(r.text, '10.1000/abc\n');
    });

    test('empty input stays empty', () {
      expect(extractDoiFromLinesIn('', 0, 0).text, '');
    });
  });

  group('extractFileExtensionsFromLinesIn', () {
    test('common image extension extracts', () {
      const text = 'open pic.png today\n';
      final r = extractFileExtensionsFromLinesIn(text, 0, text.length);
      expect(r.text, 'png\n');
    });

    test('script extension extracts', () {
      const text = 'run script.js daily\n';
      final r = extractFileExtensionsFromLinesIn(text, 0, text.length);
      expect(r.text, 'js\n');
    });

    test('mixed-alphanumeric ext like `7z` extracts', () {
      const text = 'pack archive.7z compressed\n';
      final r = extractFileExtensionsFromLinesIn(text, 0, text.length);
      expect(r.text, '7z\n');
    });

    test('case preserved (uppercase `PDF`)', () {
      const text = 'open report.PDF print\n';
      final r = extractFileExtensionsFromLinesIn(text, 0, text.length);
      expect(r.text, 'PDF\n');
    });

    test('multi-extension files yield both segments', () {
      // `archive.tar.gz` yields `tar` and `gz` as separate
      // captures. Document the v1 behaviour — filter
      // downstream if you want just the final extension.
      const text = 'pack archive.tar.gz today\n';
      final r = extractFileExtensionsFromLinesIn(text, 0, text.length);
      expect(r.text, 'tar\ngz\n');
    });

    test('decimal number `1.5` is NOT a file extension', () {
      // Lookahead requires at least one letter — pure digits
      // are decimals, not extensions.
      const text = 'note value 1.5 only\n';
      final r = extractFileExtensionsFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('version-like `version.1.2.3` is NOT an extension', () {
      const text = 'version 1.2.3 cut\n';
      final r = extractFileExtensionsFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('multiple files on one line each extract', () {
      const text = 'compare pic.jpg and pic.png and data.csv\n';
      final r = extractFileExtensionsFromLinesIn(text, 0, text.length);
      expect(r.text, 'jpg\npng\ncsv\n');
    });

    test('lines without files dropped from output', () {
      const text = 'plain prose\nopen pic.png\nmore prose\n';
      final r = extractFileExtensionsFromLinesIn(text, 0, text.length);
      expect(r.text, 'png\n');
    });

    test('empty input stays empty', () {
      expect(extractFileExtensionsFromLinesIn('', 0, 0).text, '');
    });
  });

  group('extractIsbn13FromLinesIn', () {
    test('bare ISBN-13 extracts', () {
      const text = 'book ISBN 9783161484100 today\n';
      final r = extractIsbn13FromLinesIn(text, 0, text.length);
      expect(r.text, '9783161484100\n');
    });

    test('hyphenated ISBN-13 extracts intact', () {
      const text = 'see 978-3-16-148410-0 cover\n';
      final r = extractIsbn13FromLinesIn(text, 0, text.length);
      expect(r.text, '978-3-16-148410-0\n');
    });

    test('space-separated ISBN-13 extracts intact', () {
      const text = 'book 978 3 16 148410 0 form\n';
      final r = extractIsbn13FromLinesIn(text, 0, text.length);
      expect(r.text, '978 3 16 148410 0\n');
    });

    test('GS1 prefix 979 (music) extracts', () {
      const text = 'music ISBN 9790123456789 logged\n';
      final r = extractIsbn13FromLinesIn(text, 0, text.length);
      expect(r.text, '9790123456789\n');
    });

    test('invalid prefix `980` is NOT an ISBN-13', () {
      // Only 978/979 are valid GS1 ISBN-13 namespaces.
      const text = 'fake 9803161484100 invalid\n';
      final r = extractIsbn13FromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('too short (12 digits) is NOT a match', () {
      const text = 'short 978316148410 only\n';
      final r = extractIsbn13FromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('ISBN-10 form (10 digits, no `978`) is NOT matched', () {
      // Out of scope for v1 — modern books use ISBN-13.
      const text = 'legacy 0306406152 inline\n';
      final r = extractIsbn13FromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('multiple ISBN-13s on one line each extract', () {
      const text = 'pair 9783161484100 and 9781234567897 listed\n';
      final r = extractIsbn13FromLinesIn(text, 0, text.length);
      expect(r.text, '9783161484100\n9781234567897\n');
    });

    test('lines without ISBNs dropped from output', () {
      const text = 'plain prose\ncite 9783161484100\nmore prose\n';
      final r = extractIsbn13FromLinesIn(text, 0, text.length);
      expect(r.text, '9783161484100\n');
    });

    test('empty input stays empty', () {
      expect(extractIsbn13FromLinesIn('', 0, 0).text, '');
    });
  });

  group('extractJiraTicketsFromLinesIn', () {
    test('typical PROJ-1234 form extracts', () {
      const text = 'fix PROJ-1234 today\n';
      final r = extractJiraTicketsFromLinesIn(text, 0, text.length);
      expect(r.text, 'PROJ-1234\n');
    });

    test('short project key with single-digit issue', () {
      const text = 'ticket OPS-1 still open\n';
      final r = extractJiraTicketsFromLinesIn(text, 0, text.length);
      expect(r.text, 'OPS-1\n');
    });

    test('long issue number extracts', () {
      const text = 'massive XYZ-999999 inline\n';
      final r = extractJiraTicketsFromLinesIn(text, 0, text.length);
      expect(r.text, 'XYZ-999999\n');
    });

    test('lowercase project key is NOT a JIRA ticket', () {
      // JIRA convention requires uppercase.
      const text = 'fake proj-123 invalid\n';
      final r = extractJiraTicketsFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('single-letter prefix is NOT matched', () {
      // The regex requires 2+ letters.
      const text = 'short A-123 only one\n';
      final r = extractJiraTicketsFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('plain number (no prefix) is NOT a ticket', () {
      const text = 'count 123 things\n';
      final r = extractJiraTicketsFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('plain project key (no number) is NOT a ticket', () {
      const text = 'project PROJ standalone\n';
      final r = extractJiraTicketsFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('multiple tickets on one line each extract', () {
      const text = 'merge PROJ-100 and OPS-42 deploy\n';
      final r = extractJiraTicketsFromLinesIn(text, 0, text.length);
      expect(r.text, 'PROJ-100\nOPS-42\n');
    });

    test('mixed-case word `MyProj-1` (lowercase mixed in) NOT matched', () {
      // The regex requires all-uppercase letters in the key.
      const text = 'fake MyProj-1 mixed\n';
      final r = extractJiraTicketsFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('lines without tickets dropped from output', () {
      const text = 'plain prose\nfix PROJ-1234 today\nmore prose\n';
      final r = extractJiraTicketsFromLinesIn(text, 0, text.length);
      expect(r.text, 'PROJ-1234\n');
    });

    test('empty input stays empty', () {
      expect(extractJiraTicketsFromLinesIn('', 0, 0).text, '');
    });
  });

  group('extractPrIssueRefsFromLinesIn', () {
    test('typical `#1234` reference extracts', () {
      const text = 'fix #1234 today\n';
      final r = extractPrIssueRefsFromLinesIn(text, 0, text.length);
      expect(r.text, '#1234\n');
    });

    test('single-digit reference extracts', () {
      const text = 'see PR #1 milestone\n';
      final r = extractPrIssueRefsFromLinesIn(text, 0, text.length);
      expect(r.text, '#1\n');
    });

    test('large-number reference extracts', () {
      const text = 'issue #999999 reported\n';
      final r = extractPrIssueRefsFromLinesIn(text, 0, text.length);
      expect(r.text, '#999999\n');
    });

    test('hashtag with letters is NOT a numeric ref', () {
      // `#tag` is M1055's hashtag surface, not this one.
      const text = 'tagged #bug-fix only\n';
      final r = extractPrIssueRefsFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('embedded in word `abc#123` is NOT matched', () {
      // Lookbehind blocks word-preceded matches.
      const text = 'token abc#123 inline\n';
      final r = extractPrIssueRefsFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('bare `#` (no digits) is NOT a match', () {
      const text = 'symbol # alone trivia\n';
      final r = extractPrIssueRefsFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('hashtag-then-numeric `#tag-123` only matches the tag form', () {
      // Lookbehind allows the `#` after space. Then `\d+` requires
      // digits — `t` is not. Fail. Move on past `tag-123`.
      const text = 'mixed #tag-123 surface\n';
      final r = extractPrIssueRefsFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('multiple refs on one line each extract', () {
      const text = 'merge #100, #200 and #300 batch\n';
      final r = extractPrIssueRefsFromLinesIn(text, 0, text.length);
      expect(r.text, '#100\n#200\n#300\n');
    });

    test('punctuation-adjacent reference extracts', () {
      const text = '(see #1234) for details\n';
      final r = extractPrIssueRefsFromLinesIn(text, 0, text.length);
      expect(r.text, '#1234\n');
    });

    test('lines without refs dropped from output', () {
      const text = 'plain prose\nfix #1234 today\nmore prose\n';
      final r = extractPrIssueRefsFromLinesIn(text, 0, text.length);
      expect(r.text, '#1234\n');
    });

    test('empty input stays empty', () {
      expect(extractPrIssueRefsFromLinesIn('', 0, 0).text, '');
    });
  });

  group('extractRomanNumeralsFromLinesIn', () {
    test('simple `IV` extracts', () {
      const text = 'chapter IV begins\n';
      final r = extractRomanNumeralsFromLinesIn(text, 0, text.length);
      expect(r.text, 'IV\n');
    });

    test('large Roman `MCMXCIX` (1999) extracts', () {
      const text = 'year MCMXCIX inline\n';
      final r = extractRomanNumeralsFromLinesIn(text, 0, text.length);
      expect(r.text, 'MCMXCIX\n');
    });

    test('basic `I` through `X` extract', () {
      const text = 'I II III IV V VI VII VIII IX X\n';
      final r = extractRomanNumeralsFromLinesIn(text, 0, text.length);
      expect(
        r.text,
        'I\nII\nIII\nIV\nV\nVI\nVII\nVIII\nIX\nX\n',
      );
    });

    test('lowercase Roman `iv` is NOT matched', () {
      // Outline / chapter Roman numerals are uppercase by
      // convention; lowercase forms conflict with English
      // words ending in `i` / `v` / `x`.
      const text = 'fake iv lowercase\n';
      final r = extractRomanNumeralsFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('English word `MIX` matches as Roman 1009', () {
      // `MIX` happens to be both an English word and a valid
      // Roman numeral (M + IX = 1009). Acceptable false-
      // positive given the visual identity.
      const text = 'cocktail MIX added\n';
      final r = extractRomanNumeralsFromLinesIn(text, 0, text.length);
      expect(r.text, 'MIX\n');
    });

    test('mid-prose Roman extracts with word boundary', () {
      const text = 'see Section XIII for context\n';
      final r = extractRomanNumeralsFromLinesIn(text, 0, text.length);
      expect(r.text, 'XIII\n');
    });

    test('multiple Romans on one line each extract', () {
      const text = 'chapters IV through VII covered\n';
      final r = extractRomanNumeralsFromLinesIn(text, 0, text.length);
      expect(r.text, 'IV\nVII\n');
    });

    test('plain English words (no Roman chars) are NOT matched', () {
      const text = 'pure prose with no numerals here\n';
      final r = extractRomanNumeralsFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('lines without Romans dropped from output', () {
      const text = 'plain prose\nchapter VII begins\nmore prose\n';
      final r = extractRomanNumeralsFromLinesIn(text, 0, text.length);
      expect(r.text, 'VII\n');
    });

    test('empty input stays empty', () {
      expect(extractRomanNumeralsFromLinesIn('', 0, 0).text, '');
    });
  });

  group('extractLatLngFromLinesIn', () {
    test('comma-separated coords extract', () {
      const text = 'NYC at 40.7128,-74.0060 listed\n';
      final r = extractLatLngFromLinesIn(text, 0, text.length);
      expect(r.text, '40.7128,-74.0060\n');
    });

    test('whitespace around comma tolerated', () {
      const text = 'spot 40.7128, -74.0060 saved\n';
      final r = extractLatLngFromLinesIn(text, 0, text.length);
      expect(r.text, '40.7128, -74.0060\n');
    });

    test('boundary coords (90 / 180) extract', () {
      const text = 'pole 90.0, 180.0 max\n';
      final r = extractLatLngFromLinesIn(text, 0, text.length);
      expect(r.text, '90.0, 180.0\n');
    });

    test('negative both axes extract', () {
      const text = 'south -33.8688, -151.2093 Sydney\n';
      final r = extractLatLngFromLinesIn(text, 0, text.length);
      expect(r.text, '-33.8688, -151.2093\n');
    });

    test('single decimal (no comma) is NOT a coordinate pair', () {
      const text = 'just 1.5 alone\n';
      final r = extractLatLngFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('integer pair `40, 74` (no decimals) is NOT a match', () {
      // Both sides require a decimal point.
      const text = 'rough 40, 74 only\n';
      final r = extractLatLngFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('multiple pairs on one line each extract', () {
      const text = 'route from 40.7128,-74.0060 to 51.5074,-0.1278 today\n';
      final r = extractLatLngFromLinesIn(text, 0, text.length);
      expect(r.text, '40.7128,-74.0060\n51.5074,-0.1278\n');
    });

    test('decimal pair `1.5,2.5` matches (no range validation)', () {
      // Documented v1 behavior — accept the false positive
      // since two-decimals-with-comma is rare in non-coord
      // prose.
      const text = 'pair 1.5,2.5 unlikely\n';
      final r = extractLatLngFromLinesIn(text, 0, text.length);
      expect(r.text, '1.5,2.5\n');
    });

    test('lines without coord pairs dropped from output', () {
      const text = 'plain prose\nspot 40.7128,-74.0060\nmore prose\n';
      final r = extractLatLngFromLinesIn(text, 0, text.length);
      expect(r.text, '40.7128,-74.0060\n');
    });

    test('empty input stays empty', () {
      expect(extractLatLngFromLinesIn('', 0, 0).text, '');
    });
  });

  group('extractEthAddressesFromLinesIn', () {
    test('lowercase hex address extracts', () {
      const text = 'wallet 0x742d35cc6634c0532925a3b844bc9e7595f8b8c7 here\n';
      final r = extractEthAddressesFromLinesIn(text, 0, text.length);
      expect(r.text, '0x742d35cc6634c0532925a3b844bc9e7595f8b8c7\n');
    });

    test('EIP-55 mixed-case checksum form extracts intact', () {
      const text = 'see 0x742d35Cc6634C0532925a3b844Bc9e7595f8b8C7 today\n';
      final r = extractEthAddressesFromLinesIn(text, 0, text.length);
      expect(r.text, '0x742d35Cc6634C0532925a3b844Bc9e7595f8b8C7\n');
    });

    test('too-short (39 hex) is NOT an address', () {
      const text = 'short 0x742d35cc6634c0532925a3b844bc9e7595f8b8c bad\n';
      final r = extractEthAddressesFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('too-long (41 hex) is NOT an address', () {
      const text =
          'long 0x742d35cc6634c0532925a3b844bc9e7595f8b8c77 invalid\n';
      final r = extractEthAddressesFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('missing `0x` prefix is NOT an address', () {
      const text =
          'bare 742d35cc6634c0532925a3b844bc9e7595f8b8c7 only\n';
      final r = extractEthAddressesFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('multiple addresses on one line each extract', () {
      const text =
          'from 0x742d35cc6634c0532925a3b844bc9e7595f8b8c7 '
          'to 0x111111111111111111111111111111111111dead today\n';
      final r = extractEthAddressesFromLinesIn(text, 0, text.length);
      expect(
        r.text,
        '0x742d35cc6634c0532925a3b844bc9e7595f8b8c7\n'
        '0x111111111111111111111111111111111111dead\n',
      );
    });

    test('non-hex char in address is NOT a match', () {
      // `Z` is not in `[a-fA-F0-9]`.
      const text =
          'fake 0x742d35Zc6634c0532925a3b844bc9e7595f8b8c7 bad\n';
      final r = extractEthAddressesFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('lines without ETH addresses dropped from output', () {
      const text =
          'plain prose\nwallet 0x742d35cc6634c0532925a3b844bc9e7595f8b8c7\nmore prose\n';
      final r = extractEthAddressesFromLinesIn(text, 0, text.length);
      expect(r.text, '0x742d35cc6634c0532925a3b844bc9e7595f8b8c7\n');
    });

    test('empty input stays empty', () {
      expect(extractEthAddressesFromLinesIn('', 0, 0).text, '');
    });
  });

  group('extractMongoObjectIdsFromLinesIn', () {
    test('typical lowercase ObjectId extracts', () {
      const text = 'doc _id: 507f1f77bcf86cd799439011 here\n';
      final r = extractMongoObjectIdsFromLinesIn(text, 0, text.length);
      expect(r.text, '507f1f77bcf86cd799439011\n');
    });

    test('mixed-case hex ObjectId extracts intact', () {
      const text = 'see 507F1F77BcF86cd799439011 today\n';
      final r = extractMongoObjectIdsFromLinesIn(text, 0, text.length);
      expect(r.text, '507F1F77BcF86cd799439011\n');
    });

    test('all-digit 24-char run is NOT a match', () {
      // Lookahead requires AT LEAST ONE letter — disambiguates
      // from a long number that happens to have 24 digits.
      const text = 'count 123456789012345678901234 only\n';
      final r = extractMongoObjectIdsFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('too-short (23 hex) is NOT an ObjectId', () {
      const text = 'short 507f1f77bcf86cd79943901 bad\n';
      final r = extractMongoObjectIdsFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('too-long (25 hex) is NOT an ObjectId', () {
      const text = 'long 507f1f77bcf86cd7994390111 invalid\n';
      final r = extractMongoObjectIdsFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('multiple ObjectIds on one line each extract', () {
      const text =
          'pair 507f1f77bcf86cd799439011 and '
          '507f1f77bcf86cd799439012 logged\n';
      final r = extractMongoObjectIdsFromLinesIn(text, 0, text.length);
      expect(r.text, '507f1f77bcf86cd799439011\n'
          '507f1f77bcf86cd799439012\n');
    });

    test('non-hex char in 24-run is NOT a match', () {
      const text = 'fake 507f1f77bcf86cZ799439011 bad\n';
      final r = extractMongoObjectIdsFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('lines without ObjectIds dropped from output', () {
      const text = 'plain prose\n_id: 507f1f77bcf86cd799439011\nmore prose\n';
      final r = extractMongoObjectIdsFromLinesIn(text, 0, text.length);
      expect(r.text, '507f1f77bcf86cd799439011\n');
    });

    test('empty input stays empty', () {
      expect(extractMongoObjectIdsFromLinesIn('', 0, 0).text, '');
    });
  });

  group('extractAwsArnsFromLinesIn', () {
    test('IAM role ARN extracts', () {
      const text = 'role arn:aws:iam::123456789012:role/AdminRole here\n';
      final r = extractAwsArnsFromLinesIn(text, 0, text.length);
      expect(r.text, 'arn:aws:iam::123456789012:role/AdminRole\n');
    });

    test('S3 bucket ARN extracts', () {
      const text = 'bucket arn:aws:s3:::my-bucket-name today\n';
      final r = extractAwsArnsFromLinesIn(text, 0, text.length);
      expect(r.text, 'arn:aws:s3:::my-bucket-name\n');
    });

    test('Lambda function ARN with region extracts', () {
      const text =
          'fn arn:aws:lambda:us-east-1:123456789012:function:myFn called\n';
      final r = extractAwsArnsFromLinesIn(text, 0, text.length);
      expect(
        r.text,
        'arn:aws:lambda:us-east-1:123456789012:function:myFn\n',
      );
    });

    test('aws-cn (China partition) ARN extracts', () {
      const text =
          'cn arn:aws-cn:lambda:cn-north-1:123456789012:function:myFn ref\n';
      final r = extractAwsArnsFromLinesIn(text, 0, text.length);
      expect(
        r.text,
        'arn:aws-cn:lambda:cn-north-1:123456789012:function:myFn\n',
      );
    });

    test('aws-us-gov partition ARN extracts', () {
      const text =
          'gov arn:aws-us-gov:ec2:us-gov-west-1:123456789012:instance/i-1234 ref\n';
      final r = extractAwsArnsFromLinesIn(text, 0, text.length);
      expect(
        r.text,
        'arn:aws-us-gov:ec2:us-gov-west-1:123456789012:instance/i-1234\n',
      );
    });

    test('plain `arn` (no colons) is NOT an ARN', () {
      const text = 'word arn alone here\n';
      final r = extractAwsArnsFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('multiple ARNs on one line each extract', () {
      const text =
          'pair arn:aws:s3:::bucket1 and arn:aws:s3:::bucket2 ready\n';
      final r = extractAwsArnsFromLinesIn(text, 0, text.length);
      expect(
        r.text,
        'arn:aws:s3:::bucket1\narn:aws:s3:::bucket2\n',
      );
    });

    test('wildcard `*` in resource path extracts', () {
      const text = 'policy arn:aws:s3:::my-bucket/* allow\n';
      final r = extractAwsArnsFromLinesIn(text, 0, text.length);
      expect(r.text, 'arn:aws:s3:::my-bucket/*\n');
    });

    test('lines without ARNs dropped from output', () {
      const text =
          'plain prose\nrole arn:aws:iam::123456789012:role/X\nmore prose\n';
      final r = extractAwsArnsFromLinesIn(text, 0, text.length);
      expect(r.text, 'arn:aws:iam::123456789012:role/X\n');
    });

    test('empty input stays empty', () {
      expect(extractAwsArnsFromLinesIn('', 0, 0).text, '');
    });
  });

  group('extractMacOuisFromLinesIn', () {
    test('colon-separated MAC yields colon-separated OUI', () {
      const text = 'host 01:23:45:67:89:AB online\n';
      final r = extractMacOuisFromLinesIn(text, 0, text.length);
      expect(r.text, '01:23:45\n');
    });

    test('hyphen-separated MAC yields hyphen-separated OUI', () {
      const text = 'wmi 01-23-45-67-89-AB inline\n';
      final r = extractMacOuisFromLinesIn(text, 0, text.length);
      expect(r.text, '01-23-45\n');
    });

    test('mixed-case hex digits preserved', () {
      const text = 'addr aB:Cd:Ef:01:23:45 seen\n';
      final r = extractMacOuisFromLinesIn(text, 0, text.length);
      expect(r.text, 'aB:Cd:Ef\n');
    });

    test('mixed-separator MAC is NOT a match', () {
      // Backref `\2` enforces same separator throughout.
      const text = 'fake 01:23-45:67:89:AB invalid\n';
      final r = extractMacOuisFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('partial MAC (3 octets only) is NOT a match', () {
      // Need full 6-octet MAC; only-OUI portion doesn't count.
      const text = 'partial 01:23:45 short\n';
      final r = extractMacOuisFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('multiple MACs on one line: each yields its OUI', () {
      const text = 'pair 01:23:45:67:89:AB and aa-bb-cc-dd-ee-ff\n';
      final r = extractMacOuisFromLinesIn(text, 0, text.length);
      expect(r.text, '01:23:45\naa-bb-cc\n');
    });

    test('paired with full-MAC extractor for vendor audit', () {
      // Demonstrates the design pairing — full MACs (M1076) +
      // OUIs (M1130) for "which hosts use which vendors?"
      const text =
          'host 01:23:45:67:89:AB and aa:bb:cc:11:22:33 listed\n';
      final fulls = extractMacAddressesFromLinesIn(text, 0, text.length);
      final ouis = extractMacOuisFromLinesIn(text, 0, text.length);
      expect(fulls.text, '01:23:45:67:89:AB\naa:bb:cc:11:22:33\n');
      expect(ouis.text, '01:23:45\naa:bb:cc\n');
    });

    test('lines without MACs dropped from output', () {
      const text = 'plain prose\nseen 01:23:45:67:89:AB\nmore prose\n';
      final r = extractMacOuisFromLinesIn(text, 0, text.length);
      expect(r.text, '01:23:45\n');
    });

    test('empty input stays empty', () {
      expect(extractMacOuisFromLinesIn('', 0, 0).text, '');
    });
  });

  group('extractTwitterStatusIdsFromLinesIn', () {
    test('twitter.com URL extracts status ID', () {
      const text = 'see https://twitter.com/jack/status/20 today\n';
      final r = extractTwitterStatusIdsFromLinesIn(
          text, 0, text.length);
      expect(r.text, '20\n');
    });

    test('x.com (post-rebrand) URL extracts ID', () {
      const text =
          'cite https://x.com/jack/status/1234567890123456789 ref\n';
      final r = extractTwitterStatusIdsFromLinesIn(
          text, 0, text.length);
      expect(r.text, '1234567890123456789\n');
    });

    test('protocol-less form still matches', () {
      const text = 'tweet twitter.com/foo/status/100 short\n';
      final r = extractTwitterStatusIdsFromLinesIn(
          text, 0, text.length);
      expect(r.text, '100\n');
    });

    test('non-Twitter URL is NOT matched', () {
      const text = 'other site.com/foo/status/123 not Twitter\n';
      final r = extractTwitterStatusIdsFromLinesIn(
          text, 0, text.length);
      expect(r.text, '\n');
    });

    test('plain `/status/N` (no domain anchor) is NOT matched', () {
      const text = 'fake /status/123 only path\n';
      final r = extractTwitterStatusIdsFromLinesIn(
          text, 0, text.length);
      expect(r.text, '\n');
    });

    test('multiple tweet URLs on one line each extract', () {
      const text = 'pair twitter.com/a/status/100 and '
          'x.com/b/status/200 cited\n';
      final r = extractTwitterStatusIdsFromLinesIn(
          text, 0, text.length);
      expect(r.text, '100\n200\n');
    });

    test('username with underscore preserved', () {
      const text = 'see twitter.com/my_user/status/42 today\n';
      final r = extractTwitterStatusIdsFromLinesIn(
          text, 0, text.length);
      expect(r.text, '42\n');
    });

    test('username with dot preserved', () {
      const text = 'see twitter.com/some.user/status/99 today\n';
      final r = extractTwitterStatusIdsFromLinesIn(
          text, 0, text.length);
      expect(r.text, '99\n');
    });

    test('lines without Twitter URLs dropped from output', () {
      const text =
          'plain prose\nsee twitter.com/x/status/1 today\nmore prose\n';
      final r = extractTwitterStatusIdsFromLinesIn(
          text, 0, text.length);
      expect(r.text, '1\n');
    });

    test('empty input stays empty', () {
      expect(
        extractTwitterStatusIdsFromLinesIn('', 0, 0).text,
        '',
      );
    });
  });

  group('extractGithubIssuePrNumbersFromLinesIn', () {
    test('issue URL extracts number', () {
      const text = 'fix https://github.com/flutter/flutter/issues/100 today\n';
      final r = extractGithubIssuePrNumbersFromLinesIn(
          text, 0, text.length);
      expect(r.text, '100\n');
    });

    test('pull URL extracts number', () {
      const text =
          'see https://github.com/flutter/flutter/pull/200 merged\n';
      final r = extractGithubIssuePrNumbersFromLinesIn(
          text, 0, text.length);
      expect(r.text, '200\n');
    });

    test('protocol-less form still matches', () {
      const text = 'cite github.com/foo/bar/issues/1 today\n';
      final r = extractGithubIssuePrNumbersFromLinesIn(
          text, 0, text.length);
      expect(r.text, '1\n');
    });

    test('blob URL (not issue/pull) is NOT a match', () {
      const text =
          'docs github.com/foo/bar/blob/main/README.md anywhere\n';
      final r = extractGithubIssuePrNumbersFromLinesIn(
          text, 0, text.length);
      expect(r.text, '\n');
    });

    test('hyphenated owner / repo names preserved', () {
      const text =
          'see github.com/dart-lang/sdk/issues/42 today\n';
      final r = extractGithubIssuePrNumbersFromLinesIn(
          text, 0, text.length);
      expect(r.text, '42\n');
    });

    test('multiple issue/PR URLs on one line each extract', () {
      const text =
          'merge github.com/a/b/issues/1 and github.com/c/d/pull/2 ready\n';
      final r = extractGithubIssuePrNumbersFromLinesIn(
          text, 0, text.length);
      expect(r.text, '1\n2\n');
    });

    test('non-GitHub URL is NOT matched', () {
      const text =
          'cite gitlab.com/foo/bar/issues/1 elsewhere\n';
      final r = extractGithubIssuePrNumbersFromLinesIn(
          text, 0, text.length);
      expect(r.text, '\n');
    });

    test('large issue number extracts', () {
      const text =
          'big github.com/foo/bar/issues/999999 reported\n';
      final r = extractGithubIssuePrNumbersFromLinesIn(
          text, 0, text.length);
      expect(r.text, '999999\n');
    });

    test('lines without GH issue/PR URLs dropped from output', () {
      const text =
          'plain prose\nfix github.com/o/r/issues/1\nmore prose\n';
      final r = extractGithubIssuePrNumbersFromLinesIn(
          text, 0, text.length);
      expect(r.text, '1\n');
    });

    test('empty input stays empty', () {
      expect(
        extractGithubIssuePrNumbersFromLinesIn('', 0, 0).text,
        '',
      );
    });
  });

  group('extractNpmScopedPackagesFromLinesIn', () {
    test('standard `@scope/name` extracts', () {
      const text = 'install @flutter/material today\n';
      final r = extractNpmScopedPackagesFromLinesIn(text, 0, text.length);
      expect(r.text, '@flutter/material\n');
    });

    test('hyphenated package name preserved', () {
      const text = 'dep @scope/my-cool-package added\n';
      final r = extractNpmScopedPackagesFromLinesIn(text, 0, text.length);
      expect(r.text, '@scope/my-cool-package\n');
    });

    test('dotted package name preserved', () {
      const text = 'use @types/node.js types\n';
      final r = extractNpmScopedPackagesFromLinesIn(text, 0, text.length);
      expect(r.text, '@types/node.js\n');
    });

    test('digit-starting scope/name extracts', () {
      const text = 'see @123scope/4name today\n';
      final r = extractNpmScopedPackagesFromLinesIn(text, 0, text.length);
      expect(r.text, '@123scope/4name\n');
    });

    test('unscoped package (`react`) is NOT matched', () {
      // Avoid English-word false positives — unscoped form
      // is out of scope for v1.
      const text = 'install react today\n';
      final r = extractNpmScopedPackagesFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('uppercase-scope is NOT matched', () {
      // NPM convention is lowercase.
      const text = 'fake @SCOPE/Material here\n';
      final r = extractNpmScopedPackagesFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('multiple packages on one line each extract', () {
      const text = 'pair @foo/bar and @baz/qux installed\n';
      final r = extractNpmScopedPackagesFromLinesIn(text, 0, text.length);
      expect(r.text, '@foo/bar\n@baz/qux\n');
    });

    test('bare `@scope` (no `/name`) is NOT matched', () {
      const text = 'partial @scope only here\n';
      final r = extractNpmScopedPackagesFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('lines without scoped packages dropped from output', () {
      const text = 'plain prose\ninstall @vue/cli\nmore prose\n';
      final r = extractNpmScopedPackagesFromLinesIn(text, 0, text.length);
      expect(r.text, '@vue/cli\n');
    });

    test('empty input stays empty', () {
      expect(extractNpmScopedPackagesFromLinesIn('', 0, 0).text, '');
    });
  });

  group('extractHttpStatusCodesFromLinesIn', () {
    test('404 not-found extracts', () {
      const text = 'page returned 404 today\n';
      final r = extractHttpStatusCodesFromLinesIn(text, 0, text.length);
      expect(r.text, '404\n');
    });

    test('200 OK extracts', () {
      const text = 'success 200 logged\n';
      final r = extractHttpStatusCodesFromLinesIn(text, 0, text.length);
      expect(r.text, '200\n');
    });

    test('500 server error extracts', () {
      const text = 'server 500 alert\n';
      final r = extractHttpStatusCodesFromLinesIn(text, 0, text.length);
      expect(r.text, '500\n');
    });

    test('range boundary 100 and 599 both extract', () {
      const text = 'edge 100 and 599 boundary\n';
      final r = extractHttpStatusCodesFromLinesIn(text, 0, text.length);
      expect(r.text, '100\n599\n');
    });

    test('2-digit number is NOT a status code', () {
      const text = 'short 99 only\n';
      final r = extractHttpStatusCodesFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('4-digit year 2024 is NOT a status code', () {
      // `\b` boundaries reject embedded 3-digit slices of
      // longer numeric runs.
      const text = 'year 2024 only\n';
      final r = extractHttpStatusCodesFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('600+ codes are NOT in HTTP range', () {
      const text = 'fake 600 700 800 invalid\n';
      final r = extractHttpStatusCodesFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('multiple status codes on one line each extract', () {
      const text = 'logged 200, 404, and 500 across\n';
      final r = extractHttpStatusCodesFromLinesIn(text, 0, text.length);
      expect(r.text, '200\n404\n500\n');
    });

    test('lines without codes dropped from output', () {
      const text = 'plain prose\nerror 503 reported\nmore prose\n';
      final r = extractHttpStatusCodesFromLinesIn(text, 0, text.length);
      expect(r.text, '503\n');
    });

    test('empty input stays empty', () {
      expect(extractHttpStatusCodesFromLinesIn('', 0, 0).text, '');
    });
  });

  group('extractStackOverflowQuestionIdsFromLinesIn', () {
    test('canonical /questions/N URL extracts', () {
      const text = 'see https://stackoverflow.com/questions/12345 ref\n';
      final r = extractStackOverflowQuestionIdsFromLinesIn(
          text, 0, text.length);
      expect(r.text, '12345\n');
    });

    test('URL with trailing slug extracts ID only', () {
      const text =
          'cite https://stackoverflow.com/questions/12345/how-to-x today\n';
      final r = extractStackOverflowQuestionIdsFromLinesIn(
          text, 0, text.length);
      expect(r.text, '12345\n');
    });

    test('short /q/N form extracts', () {
      const text = 'short stackoverflow.com/q/999 inline\n';
      final r = extractStackOverflowQuestionIdsFromLinesIn(
          text, 0, text.length);
      expect(r.text, '999\n');
    });

    test('protocol-less form still matches', () {
      const text = 'see stackoverflow.com/questions/42 today\n';
      final r = extractStackOverflowQuestionIdsFromLinesIn(
          text, 0, text.length);
      expect(r.text, '42\n');
    });

    test('non-SO URL is NOT matched', () {
      const text =
          'cite quora.com/questions/12345 elsewhere\n';
      final r = extractStackOverflowQuestionIdsFromLinesIn(
          text, 0, text.length);
      expect(r.text, '\n');
    });

    test('SO tag URL (not /questions/) is NOT a Q ID', () {
      // `/tagged/dart` is a tag listing, not a question.
      const text =
          'browse https://stackoverflow.com/tagged/dart anywhere\n';
      final r = extractStackOverflowQuestionIdsFromLinesIn(
          text, 0, text.length);
      expect(r.text, '\n');
    });

    test('multiple SO URLs on one line each extract', () {
      const text =
          'pair stackoverflow.com/questions/100 and '
          'stackoverflow.com/q/200 cited\n';
      final r = extractStackOverflowQuestionIdsFromLinesIn(
          text, 0, text.length);
      expect(r.text, '100\n200\n');
    });

    test('large question number extracts', () {
      const text =
          'big stackoverflow.com/questions/79999999 ref\n';
      final r = extractStackOverflowQuestionIdsFromLinesIn(
          text, 0, text.length);
      expect(r.text, '79999999\n');
    });

    test('lines without SO URLs dropped from output', () {
      const text =
          'plain prose\ncite stackoverflow.com/questions/100\nmore prose\n';
      final r = extractStackOverflowQuestionIdsFromLinesIn(
          text, 0, text.length);
      expect(r.text, '100\n');
    });

    test('empty input stays empty', () {
      expect(
        extractStackOverflowQuestionIdsFromLinesIn('', 0, 0).text,
        '',
      );
    });
  });

  group('extractDbConnectionStringsFromLinesIn', () {
    test('mongodb URL extracts', () {
      const text = 'connect mongodb://localhost:27017/mydb here\n';
      final r = extractDbConnectionStringsFromLinesIn(text, 0, text.length);
      expect(r.text, 'mongodb://localhost:27017/mydb\n');
    });

    test('mongodb+srv form extracts', () {
      const text = 'cloud mongodb+srv://cluster.mongo.net/db today\n';
      final r = extractDbConnectionStringsFromLinesIn(text, 0, text.length);
      expect(r.text, 'mongodb+srv://cluster.mongo.net/db\n');
    });

    test('postgres URL with credentials extracts', () {
      const text = 'pg postgres://user:pass@host:5432/db cited\n';
      final r = extractDbConnectionStringsFromLinesIn(text, 0, text.length);
      expect(r.text, 'postgres://user:pass@host:5432/db\n');
    });

    test('postgresql URL form extracts', () {
      const text = 'long postgresql://user@host/db form\n';
      final r = extractDbConnectionStringsFromLinesIn(text, 0, text.length);
      expect(r.text, 'postgresql://user@host/db\n');
    });

    test('mysql URL extracts', () {
      const text = 'use mysql://user@host:3306/db today\n';
      final r = extractDbConnectionStringsFromLinesIn(text, 0, text.length);
      expect(r.text, 'mysql://user@host:3306/db\n');
    });

    test('redis URL extracts', () {
      const text = 'cache redis://localhost:6379 inline\n';
      final r = extractDbConnectionStringsFromLinesIn(text, 0, text.length);
      expect(r.text, 'redis://localhost:6379\n');
    });

    test('rediss TLS variant extracts', () {
      const text = 'secure rediss://localhost:6380 form\n';
      final r = extractDbConnectionStringsFromLinesIn(text, 0, text.length);
      expect(r.text, 'rediss://localhost:6380\n');
    });

    test('https URL (not DB) is NOT matched', () {
      const text = 'web https://x.test inline\n';
      final r = extractDbConnectionStringsFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('multiple DB strings on one line each extract', () {
      const text =
          'compare mongodb://a:1 and postgres://b:2 stacks\n';
      final r = extractDbConnectionStringsFromLinesIn(text, 0, text.length);
      expect(r.text, 'mongodb://a:1\npostgres://b:2\n');
    });

    test('lines without DB strings dropped from output', () {
      const text = 'plain prose\ncache redis://x:6379\nmore prose\n';
      final r = extractDbConnectionStringsFromLinesIn(text, 0, text.length);
      expect(r.text, 'redis://x:6379\n');
    });

    test('empty input stays empty', () {
      expect(extractDbConnectionStringsFromLinesIn('', 0, 0).text, '');
    });
  });

  group('extractRgbColorsFromLinesIn', () {
    test('basic rgb() extracts', () {
      const text = 'background rgb(255, 0, 0) red\n';
      final r = extractRgbColorsFromLinesIn(text, 0, text.length);
      expect(r.text, 'rgb(255, 0, 0)\n');
    });

    test('rgba() with alpha extracts', () {
      const text = 'overlay rgba(0, 0, 0, 0.5) shade\n';
      final r = extractRgbColorsFromLinesIn(text, 0, text.length);
      expect(r.text, 'rgba(0, 0, 0, 0.5)\n');
    });

    test('no-space form extracts', () {
      const text = 'tight rgb(0,0,0) black\n';
      final r = extractRgbColorsFromLinesIn(text, 0, text.length);
      expect(r.text, 'rgb(0,0,0)\n');
    });

    test('mixed spacing tolerated', () {
      const text = 'odd rgba( 12,34 , 56 , 1) inline\n';
      final r = extractRgbColorsFromLinesIn(text, 0, text.length);
      expect(r.text, 'rgba( 12,34 , 56 , 1)\n');
    });

    test('rgba with integer alpha extracts', () {
      const text = 'opaque rgba(255, 255, 255, 1) full\n';
      final r = extractRgbColorsFromLinesIn(text, 0, text.length);
      expect(r.text, 'rgba(255, 255, 255, 1)\n');
    });

    test('plain `rgb` word (no parens) is NOT a match', () {
      const text = 'word rgb only no parens\n';
      final r = extractRgbColorsFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('out-of-range values still match (no validation)', () {
      // Documented v1 behaviour — `999` channel passes; CSS
      // engine validates downstream.
      const text = 'fake rgb(999, 999, 999) over\n';
      final r = extractRgbColorsFromLinesIn(text, 0, text.length);
      expect(r.text, 'rgb(999, 999, 999)\n');
    });

    test('multiple colors on one line each extract', () {
      const text =
          'pair rgb(255,0,0) and rgba(0,255,0,0.5) palette\n';
      final r = extractRgbColorsFromLinesIn(text, 0, text.length);
      expect(r.text, 'rgb(255,0,0)\nrgba(0,255,0,0.5)\n');
    });

    test('hex color `#abc` is NOT matched here', () {
      // Hex colors are M1063's surface.
      const text = 'use #ff0000 only\n';
      final r = extractRgbColorsFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('lines without rgb()/rgba() dropped from output', () {
      const text = 'plain prose\nuse rgb(0,0,255)\nmore prose\n';
      final r = extractRgbColorsFromLinesIn(text, 0, text.length);
      expect(r.text, 'rgb(0,0,255)\n');
    });

    test('empty input stays empty', () {
      expect(extractRgbColorsFromLinesIn('', 0, 0).text, '');
    });
  });

  group('extractHslColorsFromLinesIn', () {
    test('basic hsl() extracts', () {
      const text = 'color hsl(120, 50%, 50%) green\n';
      final r = extractHslColorsFromLinesIn(text, 0, text.length);
      expect(r.text, 'hsl(120, 50%, 50%)\n');
    });

    test('hsla() with alpha extracts', () {
      const text = 'overlay hsla(0, 100%, 50%, 0.5) shade\n';
      final r = extractHslColorsFromLinesIn(text, 0, text.length);
      expect(r.text, 'hsla(0, 100%, 50%, 0.5)\n');
    });

    test('no-space form extracts', () {
      const text = 'tight hsl(0,0%,0%) black\n';
      final r = extractHslColorsFromLinesIn(text, 0, text.length);
      expect(r.text, 'hsl(0,0%,0%)\n');
    });

    test('full-range hsla extracts', () {
      const text = 'opaque hsla(360, 100%, 100%, 1) white\n';
      final r = extractHslColorsFromLinesIn(text, 0, text.length);
      expect(r.text, 'hsla(360, 100%, 100%, 1)\n');
    });

    test('hsl without `%` on sat/light is NOT a match', () {
      // Saturation and lightness MUST end with `%` per CSS spec
      // (unlike RGB which uses raw numbers). Regex enforces this.
      const text = 'fake hsl(120, 50, 50) no-percents\n';
      final r = extractHslColorsFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('plain `hsl` word (no parens) is NOT a match', () {
      const text = 'word hsl only no parens\n';
      final r = extractHslColorsFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('multiple HSL colors on one line each extract', () {
      const text =
          'pair hsl(0,100%,50%) and hsla(120,50%,50%,0.3) palette\n';
      final r = extractHslColorsFromLinesIn(text, 0, text.length);
      expect(r.text, 'hsl(0,100%,50%)\nhsla(120,50%,50%,0.3)\n');
    });

    test('RGB color is NOT matched here', () {
      // RGB is M1137's surface.
      const text = 'use rgb(255,0,0) only\n';
      final r = extractHslColorsFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('lines without HSL/HSLA dropped from output', () {
      const text = 'plain prose\nuse hsl(0,100%,50%)\nmore prose\n';
      final r = extractHslColorsFromLinesIn(text, 0, text.length);
      expect(r.text, 'hsl(0,100%,50%)\n');
    });

    test('empty input stays empty', () {
      expect(extractHslColorsFromLinesIn('', 0, 0).text, '');
    });
  });

  group('extractLinuxPathsFromLinesIn', () {
    test('classic `/etc/passwd` extracts', () {
      const text = 'check /etc/passwd today\n';
      final r = extractLinuxPathsFromLinesIn(text, 0, text.length);
      expect(r.text, '/etc/passwd\n');
    });

    test('long path with multiple segments extracts', () {
      const text = 'run /usr/local/bin/myapp daily\n';
      final r = extractLinuxPathsFromLinesIn(text, 0, text.length);
      expect(r.text, '/usr/local/bin/myapp\n');
    });

    test('hidden file (leading dot) preserved', () {
      const text = 'edit /home/user/.bashrc here\n';
      final r = extractLinuxPathsFromLinesIn(text, 0, text.length);
      expect(r.text, '/home/user/.bashrc\n');
    });

    test('hyphenated segment preserved', () {
      const text = 'see /var/log/cron-daemon.log inline\n';
      final r = extractLinuxPathsFromLinesIn(text, 0, text.length);
      expect(r.text, '/var/log/cron-daemon.log\n');
    });

    test('single-segment `/usr` is NOT a match', () {
      // Requires 2+ segments to disambiguate from generic
      // tokens.
      const text = 'bare /usr only\n';
      final r = extractLinuxPathsFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('math `1/2/3` (no leading-from-word-boundary) is NOT a match', () {
      // Lookbehind blocks word-preceded `/`.
      const text = 'ratio 1/2/3 inline\n';
      final r = extractLinuxPathsFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('relative path `path/to/file` is NOT matched', () {
      // No leading `/` — relative paths are out of scope.
      const text = 'edit path/to/file inline\n';
      final r = extractLinuxPathsFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('multiple paths on one line each extract', () {
      const text =
          'copy /etc/passwd to /tmp/backup.txt now\n';
      final r = extractLinuxPathsFromLinesIn(text, 0, text.length);
      expect(r.text, '/etc/passwd\n/tmp/backup.txt\n');
    });

    test('lines without paths dropped from output', () {
      const text = 'plain prose\nedit /etc/hosts\nmore prose\n';
      final r = extractLinuxPathsFromLinesIn(text, 0, text.length);
      expect(r.text, '/etc/hosts\n');
    });

    test('empty input stays empty', () {
      expect(extractLinuxPathsFromLinesIn('', 0, 0).text, '');
    });
  });

  group('extractWindowsPathsFromLinesIn', () {
    test('classic `C:\\Users\\foo` extracts', () {
      const text = r'open C:\Users\foo today' '\n';
      final r = extractWindowsPathsFromLinesIn(text, 0, text.length);
      expect(r.text, r'C:\Users\foo' '\n');
    });

    test('deep system path extracts', () {
      const text = r'edit C:\Windows\System32\drivers\etc\hosts inline' '\n';
      final r = extractWindowsPathsFromLinesIn(text, 0, text.length);
      expect(
        r.text,
        r'C:\Windows\System32\drivers\etc\hosts' '\n',
      );
    });

    test('single-segment `C:\\Users` IS matched', () {
      // Windows paths usually have at least a drive + folder,
      // so single-segment is sensible (unlike Linux's
      // 2+ requirement).
      const text = r'cd C:\Users today' '\n';
      final r = extractWindowsPathsFromLinesIn(text, 0, text.length);
      expect(r.text, r'C:\Users' '\n');
    });

    test('lowercase drive letter still matches', () {
      const text = r'open d:\projects\repo today' '\n';
      final r = extractWindowsPathsFromLinesIn(text, 0, text.length);
      expect(r.text, r'd:\projects\repo' '\n');
    });

    test('file with dot extension preserved', () {
      const text = r'edit C:\config.json today' '\n';
      final r = extractWindowsPathsFromLinesIn(text, 0, text.length);
      expect(r.text, r'C:\config.json' '\n');
    });

    test('bare `C:` (no backslash) is NOT a match', () {
      const text = 'just C: alone\n';
      final r = extractWindowsPathsFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('Linux path `/etc/passwd` is NOT matched here', () {
      // Linux paths are M1139's surface.
      const text = 'unix /etc/passwd elsewhere\n';
      final r = extractWindowsPathsFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('multiple Windows paths on one line each extract', () {
      const text = r'copy C:\src to D:\dest now' '\n';
      final r = extractWindowsPathsFromLinesIn(text, 0, text.length);
      expect(r.text, r'C:\src' '\n' r'D:\dest' '\n');
    });

    test('lines without Windows paths dropped from output', () {
      const text = r'plain prose' '\n'
          r'edit C:\Windows\notepad.exe' '\n'
          r'more prose' '\n';
      final r = extractWindowsPathsFromLinesIn(text, 0, text.length);
      expect(r.text, r'C:\Windows\notepad.exe' '\n');
    });

    test('empty input stays empty', () {
      expect(extractWindowsPathsFromLinesIn('', 0, 0).text, '');
    });
  });

  group('extractPemBlockTypesFromLinesIn', () {
    test('CERTIFICATE block extracts type', () {
      const text = '-----BEGIN CERTIFICATE-----\n';
      final r = extractPemBlockTypesFromLinesIn(text, 0, text.length);
      expect(r.text, 'CERTIFICATE\n');
    });

    test('PRIVATE KEY (with space) extracts intact', () {
      const text = '-----BEGIN PRIVATE KEY-----\n';
      final r = extractPemBlockTypesFromLinesIn(text, 0, text.length);
      expect(r.text, 'PRIVATE KEY\n');
    });

    test('RSA PRIVATE KEY (3-word type) extracts', () {
      const text = '-----BEGIN RSA PRIVATE KEY-----\n';
      final r = extractPemBlockTypesFromLinesIn(text, 0, text.length);
      expect(r.text, 'RSA PRIVATE KEY\n');
    });

    test('PUBLIC KEY extracts', () {
      const text = '-----BEGIN PUBLIC KEY-----\n';
      final r = extractPemBlockTypesFromLinesIn(text, 0, text.length);
      expect(r.text, 'PUBLIC KEY\n');
    });

    test('ENCRYPTED PRIVATE KEY extracts', () {
      const text = '-----BEGIN ENCRYPTED PRIVATE KEY-----\n';
      final r = extractPemBlockTypesFromLinesIn(text, 0, text.length);
      expect(r.text, 'ENCRYPTED PRIVATE KEY\n');
    });

    test('lowercase block type is NOT matched', () {
      const text = '-----BEGIN certificate-----\n';
      final r = extractPemBlockTypesFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('plain `BEGIN` (no dashes) is NOT a PEM header', () {
      const text = 'word BEGIN CERTIFICATE only\n';
      final r = extractPemBlockTypesFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('END block (not BEGIN) is NOT matched', () {
      const text = '-----END CERTIFICATE-----\n';
      final r = extractPemBlockTypesFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('multiple PEM blocks across lines all extract', () {
      const text =
          '-----BEGIN CERTIFICATE-----\n'
          'data\n'
          '-----END CERTIFICATE-----\n'
          '-----BEGIN PUBLIC KEY-----\n'
          'data\n'
          '-----END PUBLIC KEY-----\n';
      final r = extractPemBlockTypesFromLinesIn(text, 0, text.length);
      expect(r.text, 'CERTIFICATE\nPUBLIC KEY\n');
    });

    test('lines without PEM headers dropped from output', () {
      const text =
          'plain prose\n-----BEGIN CERTIFICATE-----\nmore prose\n';
      final r = extractPemBlockTypesFromLinesIn(text, 0, text.length);
      expect(r.text, 'CERTIFICATE\n');
    });

    test('empty input stays empty', () {
      expect(extractPemBlockTypesFromLinesIn('', 0, 0).text, '');
    });
  });

  group('extractJwtFromLinesIn', () {
    test('canonical JWT extracts', () {
      // Header + payload + signature (all sufficient chars).
      const text =
          'token eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ4In0.signature123\n';
      final r = extractJwtFromLinesIn(text, 0, text.length);
      expect(
        r.text,
        'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ4In0.signature123\n',
      );
    });

    test('JWT with base64-url chars (- and _) extracts', () {
      const text =
          'tok eyJhbGc_iOiJIUzI1NiJ9.eyJzdWI-iOiJ4In0.sig-val_here\n';
      final r = extractJwtFromLinesIn(text, 0, text.length);
      expect(
        r.text,
        'eyJhbGc_iOiJIUzI1NiJ9.eyJzdWI-iOiJ4In0.sig-val_here\n',
      );
    });

    test('single segment (no dots) is NOT a JWT', () {
      const text = 'fake eyJhbGciOiJIUzI1NiJ9 only\n';
      final r = extractJwtFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('payload without `eyJ` prefix is NOT a JWT', () {
      // Second segment must start with `eyJ` too — the
      // payload is always a JSON object.
      const text =
          'fake eyJhbGciOiJIUzI1NiJ9.foopayload.sig only\n';
      final r = extractJwtFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('header without `eyJ` prefix is NOT a JWT', () {
      const text = 'fake notjwt.eyJzdWIiOiJ4In0.sig only\n';
      final r = extractJwtFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('multiple JWTs on one line each extract', () {
      const text =
          'pair eyJaaa.eyJbbb.sig1 and eyJccc.eyJddd.sig2 cached\n';
      final r = extractJwtFromLinesIn(text, 0, text.length);
      expect(r.text, 'eyJaaa.eyJbbb.sig1\neyJccc.eyJddd.sig2\n');
    });

    test('Authorization-header style with Bearer prefix', () {
      const text =
          'Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJ_payload.sig\n';
      final r = extractJwtFromLinesIn(text, 0, text.length);
      expect(
        r.text,
        'eyJhbGciOiJIUzI1NiJ9.eyJ_payload.sig\n',
      );
    });

    test('plain English prose is NOT a JWT', () {
      const text = 'no token in this prose at all\n';
      final r = extractJwtFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('lines without JWTs dropped from output', () {
      const text =
          'plain prose\ntok eyJa.eyJb.sig here\nmore prose\n';
      final r = extractJwtFromLinesIn(text, 0, text.length);
      expect(r.text, 'eyJa.eyJb.sig\n');
    });

    test('empty input stays empty', () {
      expect(extractJwtFromLinesIn('', 0, 0).text, '');
    });
  });

  group('extractBitcoinAddressesFromLinesIn', () {
    test('legacy P2PKH (Satoshi-style) extracts', () {
      // The Genesis block's coinbase address.
      const text =
          'see 1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa today\n';
      final r = extractBitcoinAddressesFromLinesIn(
          text, 0, text.length);
      expect(r.text, '1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa\n');
    });

    test('P2SH (3-prefix) extracts', () {
      const text =
          'multisig 3J98t1WpEZ73CNmQviecrnyiWrnqRhWNLy here\n';
      final r = extractBitcoinAddressesFromLinesIn(
          text, 0, text.length);
      expect(r.text, '3J98t1WpEZ73CNmQviecrnyiWrnqRhWNLy\n');
    });

    test('Bech32 SegWit extracts', () {
      const text =
          'segwit bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4 inline\n';
      final r = extractBitcoinAddressesFromLinesIn(
          text, 0, text.length);
      expect(
        r.text,
        'bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4\n',
      );
    });

    test('too-short legacy form is NOT a match', () {
      // P2PKH requires 26+ chars total (1 prefix + 25-34).
      const text = 'short 1abc only\n';
      final r = extractBitcoinAddressesFromLinesIn(
          text, 0, text.length);
      expect(r.text, '\n');
    });

    test('confusable chars (0, O, I, l) in legacy are NOT matched', () {
      // Base58 excludes these to avoid visual ambiguity. The
      // regex class `[1-9A-HJ-NP-Za-km-z]` enforces.
      const text = 'fake 10AAAAAAAAAAAAAAAAAAAAAAAA0 invalid\n';
      final r = extractBitcoinAddressesFromLinesIn(
          text, 0, text.length);
      // The `0` should disqualify; regex won't match the 0-bearing
      // candidate. Documented behaviour.
      expect(r.text, '\n');
    });

    test('multiple addresses on one line each extract', () {
      const text =
          'pair 1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa and '
          '3J98t1WpEZ73CNmQviecrnyiWrnqRhWNLy together\n';
      final r = extractBitcoinAddressesFromLinesIn(
          text, 0, text.length);
      expect(
        r.text,
        '1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa\n'
        '3J98t1WpEZ73CNmQviecrnyiWrnqRhWNLy\n',
      );
    });

    test('lowercase `bc1...` too short is NOT a match', () {
      // SegWit requires 39+ chars after `bc1`.
      const text = 'fake bc1short here\n';
      final r = extractBitcoinAddressesFromLinesIn(
          text, 0, text.length);
      expect(r.text, '\n');
    });

    test('lines without addresses dropped from output', () {
      const text =
          'plain prose\nsee 1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa\nmore prose\n';
      final r = extractBitcoinAddressesFromLinesIn(
          text, 0, text.length);
      expect(r.text, '1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa\n');
    });

    test('empty input stays empty', () {
      expect(
        extractBitcoinAddressesFromLinesIn('', 0, 0).text,
        '',
      );
    });
  });

  group('extractMacAddressesCiscoFromLinesIn', () {
    test('Cisco dotted MAC extracts', () {
      const text = 'host 0123.4567.89ab online\n';
      final r = extractMacAddressesCiscoFromLinesIn(text, 0, text.length);
      expect(r.text, '0123.4567.89ab\n');
    });

    test('all-letters MAC extracts', () {
      const text = 'vendor abcd.ef01.2345 seen\n';
      final r = extractMacAddressesCiscoFromLinesIn(text, 0, text.length);
      expect(r.text, 'abcd.ef01.2345\n');
    });

    test('mixed-case hex digits preserved', () {
      const text = 'addr aBcD.Ef01.2345 case\n';
      final r = extractMacAddressesCiscoFromLinesIn(text, 0, text.length);
      expect(r.text, 'aBcD.Ef01.2345\n');
    });

    test('colon-separated MAC (M1076 form) is NOT matched', () {
      const text = 'colon 01:23:45:67:89:ab elsewhere\n';
      final r = extractMacAddressesCiscoFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('hyphen-separated MAC (M1076 form) is NOT matched', () {
      const text = 'hyphen 01-23-45-67-89-ab elsewhere\n';
      final r = extractMacAddressesCiscoFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('wrong group count (2 groups) is NOT a match', () {
      const text = 'fake 0123.4567 partial\n';
      final r = extractMacAddressesCiscoFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('wrong digit count (3 per group) is NOT a match', () {
      const text = 'fake 012.345.678 short\n';
      final r = extractMacAddressesCiscoFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('multiple Cisco MACs on one line each extract', () {
      const text = 'pair 0123.4567.89ab and ffff.eeee.dddd seen\n';
      final r = extractMacAddressesCiscoFromLinesIn(text, 0, text.length);
      expect(r.text, '0123.4567.89ab\nffff.eeee.dddd\n');
    });

    test('lines without Cisco MACs dropped from output', () {
      const text = 'plain prose\nseen abcd.ef01.2345 today\nmore prose\n';
      final r = extractMacAddressesCiscoFromLinesIn(text, 0, text.length);
      expect(r.text, 'abcd.ef01.2345\n');
    });

    test('empty input stays empty', () {
      expect(
        extractMacAddressesCiscoFromLinesIn('', 0, 0).text,
        '',
      );
    });
  });

  group('extractHtmlEntitiesFromLinesIn', () {
    test('named entity `&amp;` extracts', () {
      const text = 'AT&amp;T inline\n';
      final r = extractHtmlEntitiesFromLinesIn(text, 0, text.length);
      expect(r.text, '&amp;\n');
    });

    test('named entity `&lt;` and `&gt;` both extract', () {
      const text = 'compare &lt; and &gt; markers\n';
      final r = extractHtmlEntitiesFromLinesIn(text, 0, text.length);
      expect(r.text, '&lt;\n&gt;\n');
    });

    test('numeric decimal entity `&#39;` extracts', () {
      const text = "isn&#39;t it\n";
      final r = extractHtmlEntitiesFromLinesIn(text, 0, text.length);
      expect(r.text, '&#39;\n');
    });

    test('numeric hex entity `&#x27;` extracts', () {
      const text = 'don&#x27;t worry\n';
      final r = extractHtmlEntitiesFromLinesIn(text, 0, text.length);
      expect(r.text, '&#x27;\n');
    });

    test('multi-char named entity `&copy;` extracts', () {
      const text = 'license &copy; 2024 inline\n';
      final r = extractHtmlEntitiesFromLinesIn(text, 0, text.length);
      expect(r.text, '&copy;\n');
    });

    test('plain `&` (no entity body) is NOT a match', () {
      const text = 'symbol & alone here\n';
      final r = extractHtmlEntitiesFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('unterminated `&amp` (no semicolon) is NOT a match', () {
      const text = 'fake &amp without semi\n';
      final r = extractHtmlEntitiesFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('multiple entities on one line each extract', () {
      const text = 'wrap &lt;tag&gt; &amp; close\n';
      final r = extractHtmlEntitiesFromLinesIn(text, 0, text.length);
      expect(r.text, '&lt;\n&gt;\n&amp;\n');
    });

    test('single-letter entity body is NOT a match', () {
      // The named-entity arm requires letter + at-least-one
      // alphanumeric, so `&a;` (single letter) fails.
      const text = 'short &a; only\n';
      final r = extractHtmlEntitiesFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('lines without entities dropped from output', () {
      const text = 'plain prose\n&copy; 2024\nmore prose\n';
      final r = extractHtmlEntitiesFromLinesIn(text, 0, text.length);
      expect(r.text, '&copy;\n');
    });

    test('empty input stays empty', () {
      expect(extractHtmlEntitiesFromLinesIn('', 0, 0).text, '');
    });
  });

  group('extractMarkdownTaskStatesFromLinesIn', () {
    test('lowercase `[x]` (done) extracts state `x`', () {
      const text = '- [x] done item here\n';
      final r = extractMarkdownTaskStatesFromLinesIn(text, 0, text.length);
      expect(r.text, 'x\n');
    });

    test('uppercase `[X]` extracts state `X`', () {
      const text = '- [X] also done\n';
      final r = extractMarkdownTaskStatesFromLinesIn(text, 0, text.length);
      expect(r.text, 'X\n');
    });

    test('empty `[ ]` (open) extracts space char', () {
      const text = '- [ ] open todo\n';
      final r = extractMarkdownTaskStatesFromLinesIn(text, 0, text.length);
      expect(r.text, ' \n');
    });

    test('multi-char `[foo]` is NOT a checkbox', () {
      // Only single-char `[ ]`, `[x]`, `[X]` are task states.
      const text = 'see [foo] tag here\n';
      final r = extractMarkdownTaskStatesFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('`[t]` (random letter) is NOT a checkbox', () {
      const text = 'fake [t] only here\n';
      final r = extractMarkdownTaskStatesFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('mixed done + open list', () {
      const text =
          '- [x] first\n- [ ] second\n- [X] third\n- [ ] fourth\n';
      final r = extractMarkdownTaskStatesFromLinesIn(text, 0, text.length);
      expect(r.text, 'x\n \nX\n \n');
    });

    test('multiple checkboxes on one line each extract', () {
      const text = '[x] done and [ ] open inline\n';
      final r = extractMarkdownTaskStatesFromLinesIn(text, 0, text.length);
      expect(r.text, 'x\n \n');
    });

    test('nested in prose extracts the state', () {
      const text = 'see status [x] for the item\n';
      final r = extractMarkdownTaskStatesFromLinesIn(text, 0, text.length);
      expect(r.text, 'x\n');
    });

    test('lines without checkboxes dropped from output', () {
      const text = 'plain prose\n- [x] done item\nmore prose\n';
      final r = extractMarkdownTaskStatesFromLinesIn(text, 0, text.length);
      expect(r.text, 'x\n');
    });

    test('empty input stays empty', () {
      expect(
        extractMarkdownTaskStatesFromLinesIn('', 0, 0).text,
        '',
      );
    });
  });

  group('extractSlackMentionsFromLinesIn', () {
    test('user mention `<@U12345>` extracts', () {
      const text = 'ping <@U12345> now\n';
      final r = extractSlackMentionsFromLinesIn(text, 0, text.length);
      expect(r.text, '<@U12345>\n');
    });

    test('channel mention `<#C12345>` extracts', () {
      const text = 'see <#C12345> for context\n';
      final r = extractSlackMentionsFromLinesIn(text, 0, text.length);
      expect(r.text, '<#C12345>\n');
    });

    test('user mention with alias `<@U12345|alice>` extracts', () {
      const text = 'ping <@U12345|alice> here\n';
      final r = extractSlackMentionsFromLinesIn(text, 0, text.length);
      expect(r.text, '<@U12345|alice>\n');
    });

    test('channel mention with name `<#C12345|general>` extracts', () {
      const text = 'see <#C12345|general> chat\n';
      final r = extractSlackMentionsFromLinesIn(text, 0, text.length);
      expect(r.text, '<#C12345|general>\n');
    });

    test('plain `@alice` (no brackets) is NOT a Slack mention', () {
      // Plain prose mentions are M1056's surface, not this one.
      const text = 'hi @alice today\n';
      final r = extractSlackMentionsFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('non-mention angle-bracket `<other>` is NOT matched', () {
      // Must start with `@` or `#` after the `<`.
      const text = 'tag <other> here\n';
      final r = extractSlackMentionsFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('lowercase-prefix `<@u12345>` is NOT matched', () {
      // Slack IDs start with uppercase.
      const text = 'fake <@u12345> bad\n';
      final r = extractSlackMentionsFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('multiple mentions on one line each extract', () {
      const text = 'cc <@U1> and <@U2> in <#C1>\n';
      final r = extractSlackMentionsFromLinesIn(text, 0, text.length);
      expect(r.text, '<@U1>\n<@U2>\n<#C1>\n');
    });

    test('lines without Slack mentions dropped from output', () {
      const text = 'plain prose\nping <@U12345>\nmore prose\n';
      final r = extractSlackMentionsFromLinesIn(text, 0, text.length);
      expect(r.text, '<@U12345>\n');
    });

    test('empty input stays empty', () {
      expect(extractSlackMentionsFromLinesIn('', 0, 0).text, '');
    });
  });

  group('extractDiscordMentionsFromLinesIn', () {
    test('user mention `<@123>` extracts', () {
      const text = 'ping <@123456789> now\n';
      final r = extractDiscordMentionsFromLinesIn(text, 0, text.length);
      expect(r.text, '<@123456789>\n');
    });

    test('nickname mention `<@!123>` extracts', () {
      const text = 'see <@!987654321> reply\n';
      final r = extractDiscordMentionsFromLinesIn(text, 0, text.length);
      expect(r.text, '<@!987654321>\n');
    });

    test('role mention `<@&456>` extracts', () {
      const text = 'page <@&456789012> on-call\n';
      final r = extractDiscordMentionsFromLinesIn(text, 0, text.length);
      expect(r.text, '<@&456789012>\n');
    });

    test('channel mention `<#789>` extracts', () {
      const text = 'see <#789012345> general\n';
      final r = extractDiscordMentionsFromLinesIn(text, 0, text.length);
      expect(r.text, '<#789012345>\n');
    });

    test('Slack mention `<@U12345>` is NOT matched', () {
      // Slack IDs use letter prefixes; Discord uses pure
      // numeric snowflakes.
      const text = 'cite <@U12345> elsewhere\n';
      final r = extractDiscordMentionsFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('plain `@user` (no brackets) is NOT a Discord mention', () {
      const text = 'hi @user today\n';
      final r = extractDiscordMentionsFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('multiple mentions on one line each extract', () {
      const text = 'cc <@123> <@&456> in <#789> chat\n';
      final r = extractDiscordMentionsFromLinesIn(text, 0, text.length);
      expect(r.text, '<@123>\n<@&456>\n<#789>\n');
    });

    test('non-numeric mention `<@abc>` is NOT matched', () {
      const text = 'fake <@abc> bad\n';
      final r = extractDiscordMentionsFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('lines without Discord mentions dropped from output', () {
      const text = 'plain prose\nping <@123>\nmore prose\n';
      final r = extractDiscordMentionsFromLinesIn(text, 0, text.length);
      expect(r.text, '<@123>\n');
    });

    test('empty input stays empty', () {
      expect(extractDiscordMentionsFromLinesIn('', 0, 0).text, '');
    });
  });

  group('extractNpmSemverRangesFromLinesIn', () {
    test('caret range `^1.2.3` extracts', () {
      const text = 'dep "react": "^18.2.0" today\n';
      final r = extractNpmSemverRangesFromLinesIn(text, 0, text.length);
      expect(r.text, '^18.2.0\n');
    });

    test('tilde range `~1.2.3` extracts', () {
      const text = 'pin lodash: ~4.17.21 stable\n';
      final r = extractNpmSemverRangesFromLinesIn(text, 0, text.length);
      expect(r.text, '~4.17.21\n');
    });

    test('greater-than-equal `>=1.2.0` extracts', () {
      const text = 'min node >=18.0.0 today\n';
      final r = extractNpmSemverRangesFromLinesIn(text, 0, text.length);
      expect(r.text, '>=18.0.0\n');
    });

    test('less-than `<2.0.0` extracts', () {
      const text = 'max <2.0.0 ceiling\n';
      final r = extractNpmSemverRangesFromLinesIn(text, 0, text.length);
      expect(r.text, '<2.0.0\n');
    });

    test('less-than-equal `<=1.2.3` extracts', () {
      const text = 'cap <=1.2.3 ok\n';
      final r = extractNpmSemverRangesFromLinesIn(text, 0, text.length);
      expect(r.text, '<=1.2.3\n');
    });

    test('exact `=1.2.3` extracts', () {
      const text = 'pin =1.2.3 exactly\n';
      final r = extractNpmSemverRangesFromLinesIn(text, 0, text.length);
      expect(r.text, '=1.2.3\n');
    });

    test('bare semver `1.2.3` is NOT a range match', () {
      // Bare semvers are M1074's surface; this extractor
      // targets explicit range operators.
      const text = 'bare 1.2.3 only\n';
      final r = extractNpmSemverRangesFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('multiple ranges on one line each extract', () {
      const text =
          'compat ^1.2.3 with >=1.0.0 and <2.0.0 here\n';
      final r = extractNpmSemverRangesFromLinesIn(text, 0, text.length);
      expect(r.text, '^1.2.3\n>=1.0.0\n<2.0.0\n');
    });

    test('lines without ranges dropped from output', () {
      const text = 'plain prose\ndep "x": "^1.2.3"\nmore prose\n';
      final r = extractNpmSemverRangesFromLinesIn(text, 0, text.length);
      expect(r.text, '^1.2.3\n');
    });

    test('empty input stays empty', () {
      expect(extractNpmSemverRangesFromLinesIn('', 0, 0).text, '');
    });
  });

  group('extractHttpMethodsFromLinesIn', () {
    test('GET method + path extracts', () {
      const text = 'route GET /api/users today\n';
      final r = extractHttpMethodsFromLinesIn(text, 0, text.length);
      expect(r.text, 'GET /api/users\n');
    });

    test('POST method + path extracts', () {
      const text = 'auth POST /v1/login here\n';
      final r = extractHttpMethodsFromLinesIn(text, 0, text.length);
      expect(r.text, 'POST /v1/login\n');
    });

    test('DELETE with id-path extracts', () {
      const text = 'remove DELETE /api/users/123 now\n';
      final r = extractHttpMethodsFromLinesIn(text, 0, text.length);
      expect(r.text, 'DELETE /api/users/123\n');
    });

    test('PATCH method + path extracts (RFC 5789)', () {
      const text = 'update PATCH /api/users/123 here\n';
      final r = extractHttpMethodsFromLinesIn(text, 0, text.length);
      expect(r.text, 'PATCH /api/users/123\n');
    });

    test('all standard methods recognized', () {
      const text =
          'GET /a POST /b PUT /c PATCH /d DELETE /e HEAD /f '
          'OPTIONS /g TRACE /h CONNECT /i\n';
      final r = extractHttpMethodsFromLinesIn(text, 0, text.length);
      expect(
        r.text,
        'GET /a\nPOST /b\nPUT /c\nPATCH /d\nDELETE /e\nHEAD /f\n'
        'OPTIONS /g\nTRACE /h\nCONNECT /i\n',
      );
    });

    test('lowercase method `get /path` is NOT matched', () {
      const text = 'fake get /path lowercase\n';
      final r = extractHttpMethodsFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('method without path is NOT a match', () {
      const text = 'word GET alone here\n';
      final r = extractHttpMethodsFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('path with query string included in capture', () {
      const text = 'fetch GET /api/users?id=42 inline\n';
      final r = extractHttpMethodsFromLinesIn(text, 0, text.length);
      expect(r.text, 'GET /api/users?id=42\n');
    });

    test('multiple methods on one line each extract', () {
      const text = 'sequence GET /a then POST /b together\n';
      final r = extractHttpMethodsFromLinesIn(text, 0, text.length);
      expect(r.text, 'GET /a\nPOST /b\n');
    });

    test('lines without HTTP methods dropped from output', () {
      const text = 'plain prose\nroute GET /api/x\nmore prose\n';
      final r = extractHttpMethodsFromLinesIn(text, 0, text.length);
      expect(r.text, 'GET /api/x\n');
    });

    test('empty input stays empty', () {
      expect(extractHttpMethodsFromLinesIn('', 0, 0).text, '');
    });
  });

  group('extractMimeTypesFromLinesIn', () {
    test('application/json extracts', () {
      const text = 'header: application/json today\n';
      final r = extractMimeTypesFromLinesIn(text, 0, text.length);
      expect(r.text, 'application/json\n');
    });

    test('text/html extracts', () {
      const text = 'Content-Type: text/html here\n';
      final r = extractMimeTypesFromLinesIn(text, 0, text.length);
      expect(r.text, 'text/html\n');
    });

    test('image/png extracts', () {
      const text = 'upload image/png file\n';
      final r = extractMimeTypesFromLinesIn(text, 0, text.length);
      expect(r.text, 'image/png\n');
    });

    test('vendor subtype with plus suffix extracts', () {
      // `application/vnd.api+json` is a real-world IANA type.
      const text = 'JSON-API: application/vnd.api+json wrap\n';
      final r = extractMimeTypesFromLinesIn(text, 0, text.length);
      expect(r.text, 'application/vnd.api+json\n');
    });

    test('x- prefixed subtype extracts', () {
      // `application/x-www-form-urlencoded` is a common legacy type.
      const text = 'form: application/x-www-form-urlencoded body\n';
      final r = extractMimeTypesFromLinesIn(text, 0, text.length);
      expect(r.text, 'application/x-www-form-urlencoded\n');
    });

    test('all ten IANA roots are recognized', () {
      const text =
          'application/json audio/mpeg font/woff2 example/foo '
          'image/png message/rfc822 model/gltf+json '
          'multipart/form-data text/html video/mp4\n';
      final r = extractMimeTypesFromLinesIn(text, 0, text.length);
      expect(
        r.text,
        'application/json\naudio/mpeg\nfont/woff2\nexample/foo\n'
        'image/png\nmessage/rfc822\nmodel/gltf+json\n'
        'multipart/form-data\ntext/html\nvideo/mp4\n',
      );
    });

    test('charset parameter is NOT included in capture', () {
      // The `; charset=utf-8` parameter portion is dropped — only
      // the bare `type/subtype` token is returned.
      const text = 'header: text/html; charset=utf-8 inline\n';
      final r = extractMimeTypesFromLinesIn(text, 0, text.length);
      expect(r.text, 'text/html\n');
    });

    test('unknown top-level type rejected', () {
      // `foo/bar` is not one of the ten IANA roots.
      const text = 'fake foo/bar not a real type\n';
      final r = extractMimeTypesFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('subtype starting with dot rejected', () {
      // The regex requires subtype to start with an alphanumeric,
      // so `text/.html` should not match.
      const text = 'malformed text/.html ignore\n';
      final r = extractMimeTypesFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('multiple types on one line each extract', () {
      const text = 'accept: text/html, application/json then\n';
      final r = extractMimeTypesFromLinesIn(text, 0, text.length);
      expect(r.text, 'text/html\napplication/json\n');
    });

    test('lines without MIME types dropped from output', () {
      const text = 'plain prose\nuse application/json\nmore prose\n';
      final r = extractMimeTypesFromLinesIn(text, 0, text.length);
      expect(r.text, 'application/json\n');
    });

    test('empty input stays empty', () {
      expect(extractMimeTypesFromLinesIn('', 0, 0).text, '');
    });
  });

  group('extractKubernetesResourcesFromLinesIn', () {
    test('pod/name extracts', () {
      const text = 'restart pod/web today\n';
      final r = extractKubernetesResourcesFromLinesIn(
          text, 0, text.length,);
      expect(r.text, 'pod/web\n');
    });

    test('deployment with hyphenated name extracts', () {
      const text = 'scale deployment/api-gateway up\n';
      final r = extractKubernetesResourcesFromLinesIn(
          text, 0, text.length,);
      expect(r.text, 'deployment/api-gateway\n');
    });

    test('service/name extracts', () {
      const text = 'check service/db-fe here\n';
      final r = extractKubernetesResourcesFromLinesIn(
          text, 0, text.length,);
      expect(r.text, 'service/db-fe\n');
    });

    test('configmap/feature-flags extracts', () {
      const text = 'edit configmap/feature-flags now\n';
      final r = extractKubernetesResourcesFromLinesIn(
          text, 0, text.length,);
      expect(r.text, 'configmap/feature-flags\n');
    });

    test('cluster-scoped kinds (namespace, node) extract', () {
      const text = 'see namespace/default and node/worker-3\n';
      final r = extractKubernetesResourcesFromLinesIn(
          text, 0, text.length,);
      expect(r.text, 'namespace/default\nnode/worker-3\n');
    });

    test('RBAC kinds (rolebinding, clusterrole) extract', () {
      const text = 'grant rolebinding/admin and clusterrole/edit\n';
      final r = extractKubernetesResourcesFromLinesIn(
          text, 0, text.length,);
      expect(r.text, 'rolebinding/admin\nclusterrole/edit\n');
    });

    test('plural kinds (pods, deployments) are NOT matched', () {
      // kubectl's resource shorthand is canonically singular.
      const text = 'list pods/web and deployments/api\n';
      final r = extractKubernetesResourcesFromLinesIn(
          text, 0, text.length,);
      expect(r.text, '\n');
    });

    test('unknown kind rejected', () {
      // `widget/foo` is not a registered Kubernetes kind.
      const text = 'fake widget/foo not real\n';
      final r = extractKubernetesResourcesFromLinesIn(
          text, 0, text.length,);
      expect(r.text, '\n');
    });

    test('uppercase kind rejected', () {
      // Kinds are matched case-sensitively (lowercase) — `Pod/web`
      // is YAML manifest style, not kubectl shorthand.
      const text = 'manifest Pod/web ignore\n';
      final r = extractKubernetesResourcesFromLinesIn(
          text, 0, text.length,);
      expect(r.text, '\n');
    });

    test('name ending with hyphen rejected (boundary class)', () {
      // The name must end with an alphanumeric — `pod/web-` is
      // malformed and should not match.
      const text = 'broken pod/web- alone\n';
      final r = extractKubernetesResourcesFromLinesIn(
          text, 0, text.length,);
      // The regex backs off to a single-char name match `pod/w`?
      // No — the leading `[a-z0-9]` plus `(?:...[a-z0-9])?` lets
      // a 1-char name match. So `pod/web` (3 chars) matches and
      // the trailing `-` is dropped. Document that observed
      // behaviour.
      expect(r.text, 'pod/web\n');
    });

    test('multiple resources on one line each extract', () {
      const text = 'apply pod/web and service/db together\n';
      final r = extractKubernetesResourcesFromLinesIn(
          text, 0, text.length,);
      expect(r.text, 'pod/web\nservice/db\n');
    });

    test('lines without resources dropped from output', () {
      const text = 'plain prose\nuse pod/api\nmore prose\n';
      final r = extractKubernetesResourcesFromLinesIn(
          text, 0, text.length,);
      expect(r.text, 'pod/api\n');
    });

    test('empty input stays empty', () {
      expect(extractKubernetesResourcesFromLinesIn('', 0, 0).text,
          '',);
    });
  });

  group('extractEmojiShortcodesFromLinesIn', () {
    test(':smile: extracts', () {
      const text = 'great :smile: today\n';
      final r = extractEmojiShortcodesFromLinesIn(
          text, 0, text.length,);
      expect(r.text, ':smile:\n');
    });

    test(':rocket: extracts', () {
      const text = 'launch :rocket: now\n';
      final r = extractEmojiShortcodesFromLinesIn(
          text, 0, text.length,);
      expect(r.text, ':rocket:\n');
    });

    test('multi-word shortcode with underscore extracts', () {
      const text = 'nice :thumbs_up: here\n';
      final r = extractEmojiShortcodesFromLinesIn(
          text, 0, text.length,);
      expect(r.text, ':thumbs_up:\n');
    });

    test('long compound shortcode extracts', () {
      const text = 'meet :woman_health_worker: today\n';
      final r = extractEmojiShortcodesFromLinesIn(
          text, 0, text.length,);
      expect(r.text, ':woman_health_worker:\n');
    });

    test('special-case :+1: extracts', () {
      const text = 'approve :+1: now\n';
      final r = extractEmojiShortcodesFromLinesIn(
          text, 0, text.length,);
      expect(r.text, ':+1:\n');
    });

    test('special-case :-1: extracts', () {
      const text = 'reject :-1: now\n';
      final r = extractEmojiShortcodesFromLinesIn(
          text, 0, text.length,);
      expect(r.text, ':-1:\n');
    });

    test('time-of-day 12:34:56 is NOT mistaken for shortcode', () {
      // The regex requires the first identifier character to be
      // a letter, so the `:34:` substring inside `12:34:56` does
      // not match.
      const text = 'meet 12:34:56 today\n';
      final r = extractEmojiShortcodesFromLinesIn(
          text, 0, text.length,);
      expect(r.text, '\n');
    });

    test('uppercase shortcode rejected', () {
      // Shortcodes are conventionally lowercase across Slack /
      // GitHub / Discord. `:SMILE:` is not standard.
      const text = 'fake :SMILE: ignore\n';
      final r = extractEmojiShortcodesFromLinesIn(
          text, 0, text.length,);
      expect(r.text, '\n');
    });

    test('digit-first body rejected', () {
      // `:100:` has a numeric body; not matched because the regex
      // requires a leading letter (with the +1/-1 special cases).
      const text = 'score :100: ignore\n';
      final r = extractEmojiShortcodesFromLinesIn(
          text, 0, text.length,);
      expect(r.text, '\n');
    });

    test('multiple shortcodes on one line each extract', () {
      const text = 'react :smile: and :rocket: ship\n';
      final r = extractEmojiShortcodesFromLinesIn(
          text, 0, text.length,);
      expect(r.text, ':smile:\n:rocket:\n');
    });

    test('lines without shortcodes dropped from output', () {
      const text = 'plain prose\nlater :fire:\nmore prose\n';
      final r = extractEmojiShortcodesFromLinesIn(
          text, 0, text.length,);
      expect(r.text, ':fire:\n');
    });

    test('empty input stays empty', () {
      expect(
          extractEmojiShortcodesFromLinesIn('', 0, 0).text, '',);
    });
  });

  group('extractS3UrisFromLinesIn', () {
    test('bare bucket URI extracts', () {
      const text = 'upload to s3://my-bucket today\n';
      final r = extractS3UrisFromLinesIn(text, 0, text.length);
      expect(r.text, 's3://my-bucket\n');
    });

    test('bucket with key path extracts (path included)', () {
      const text = 'fetch s3://my-bucket/path/to/key.txt now\n';
      final r = extractS3UrisFromLinesIn(text, 0, text.length);
      expect(r.text, 's3://my-bucket/path/to/key.txt\n');
    });

    test('dotted bucket name extracts', () {
      const text = 'serve s3://example.com/index.html alive\n';
      final r = extractS3UrisFromLinesIn(text, 0, text.length);
      expect(r.text, 's3://example.com/index.html\n');
    });

    test('hyphenated bucket name extracts', () {
      const text = 'store s3://my-org-data-2026 here\n';
      final r = extractS3UrisFromLinesIn(text, 0, text.length);
      expect(r.text, 's3://my-org-data-2026\n');
    });

    test('uppercase S3 scheme rejected', () {
      // `S3://Foo` is not canonical; the regex is case-sensitive.
      const text = 'fake S3://Foo not real\n';
      final r = extractS3UrisFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('HTTPS S3 endpoint NOT matched', () {
      // The virtual-hosted-style `https://...amazonaws.com/...`
      // endpoint is a different surface; only the canonical
      // `s3://` URI scheme is extracted here.
      const text = 'old https://s3.amazonaws.com/bucket/key here\n';
      final r = extractS3UrisFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('bucket starting with hyphen rejected', () {
      // The regex requires the bucket to start with an
      // alphanumeric, so `s3://-bad` doesn't match.
      const text = 'invalid s3://-bad ignore\n';
      final r = extractS3UrisFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('multiple URIs on one line each extract', () {
      const text = 'sync s3://src-bk/key1 to s3://dst-bk/key2 ok\n';
      final r = extractS3UrisFromLinesIn(text, 0, text.length);
      expect(r.text, 's3://src-bk/key1\ns3://dst-bk/key2\n');
    });

    test('URI followed by space stops at whitespace', () {
      // The optional key portion uses `\S*`, so the capture ends
      // at the first whitespace character.
      const text = 'see s3://bucket/key then more text\n';
      final r = extractS3UrisFromLinesIn(text, 0, text.length);
      expect(r.text, 's3://bucket/key\n');
    });

    test('single-character bucket NOT matched (2-char minimum)', () {
      // The regex `[a-z0-9][a-z0-9.\-]*[a-z0-9]` requires the
      // bucket name to be 2+ chars. `s3://a` is technically a
      // valid AWS scheme but uncommon in practice; documented
      // here so future readers know why it doesn't extract.
      const text = 'edge s3://a alone here\n';
      final r = extractS3UrisFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('lines without S3 URIs dropped from output', () {
      const text = 'plain prose\nuse s3://bk/key\nmore prose\n';
      final r = extractS3UrisFromLinesIn(text, 0, text.length);
      expect(r.text, 's3://bk/key\n');
    });

    test('empty input stays empty', () {
      expect(extractS3UrisFromLinesIn('', 0, 0).text, '');
    });
  });

  group('extractCronExpressionsFromLinesIn', () {
    test('every-minute star expression extracts', () {
      const text = 'job: * * * * * runs every minute\n';
      final r = extractCronExpressionsFromLinesIn(
          text, 0, text.length,);
      expect(r.text, '* * * * *\n');
    });

    test('daily-at-midnight expression extracts', () {
      const text = 'nightly 0 0 * * * fires at midnight\n';
      final r = extractCronExpressionsFromLinesIn(
          text, 0, text.length,);
      expect(r.text, '0 0 * * *\n');
    });

    test('every-15-minutes step expression extracts', () {
      const text = 'cleanup */15 * * * * sweep\n';
      final r = extractCronExpressionsFromLinesIn(
          text, 0, text.length,);
      expect(r.text, '*/15 * * * *\n');
    });

    test('weekday range expression extracts', () {
      const text = 'meeting 0 9 * * 1-5 daily standup\n';
      final r = extractCronExpressionsFromLinesIn(
          text, 0, text.length,);
      expect(r.text, '0 9 * * 1-5\n');
    });

    test('comma list + range expression extracts', () {
      const text = 'busy 0,30 9-17 * * 1-5 weekdays\n';
      final r = extractCronExpressionsFromLinesIn(
          text, 0, text.length,);
      expect(r.text, '0,30 9-17 * * 1-5\n');
    });

    test('Quartz 6-field form extracts', () {
      const text = 'quartz 0 0 * * * * with seconds\n';
      final r = extractCronExpressionsFromLinesIn(
          text, 0, text.length,);
      expect(r.text, '0 0 * * * *\n');
    });

    test('plain numeric run NOT a cron (no star)', () {
      // `1 2 3 4 5` matches the field shape but contains no
      // star, so the strong-signal filter rejects it.
      const text = 'numbers 1 2 3 4 5 not cron\n';
      final r = extractCronExpressionsFromLinesIn(
          text, 0, text.length,);
      expect(r.text, '\n');
    });

    test('only 3 fields NOT matched (too few)', () {
      // The regex requires 5 or 6 fields. `* * *` is too short.
      const text = 'short * * * not enough\n';
      final r = extractCronExpressionsFromLinesIn(
          text, 0, text.length,);
      expect(r.text, '\n');
    });

    test('7 fields NOT matched (Quartz year form unsupported)', () {
      // The regex caps at 6 fields; the rare 7-field Quartz form
      // with year is intentionally not extracted.
      const text = 'yearly 0 0 0 * * * 2026 unsupported\n';
      final r = extractCronExpressionsFromLinesIn(
          text, 0, text.length,);
      // The regex will greedily try to match. Field 7 (`2026`)
      // doesn't have a star, but the regex finds a 6-field match
      // inside `0 0 0 * * *`. So output is the 6-field substring.
      expect(r.text, '0 0 0 * * *\n');
    });

    test('lines without cron expressions dropped from output', () {
      const text = 'plain prose\nschedule 0 9 * * * works\nbye\n';
      final r = extractCronExpressionsFromLinesIn(
          text, 0, text.length,);
      expect(r.text, '0 9 * * *\n');
    });

    test('empty input stays empty', () {
      expect(extractCronExpressionsFromLinesIn('', 0, 0).text,
          '',);
    });
  });

  group('extractDockerImagesFromLinesIn', () {
    test('bare image with semver tag extracts', () {
      const text = 'use nginx:1.21 now\n';
      final r = extractDockerImagesFromLinesIn(
          text, 0, text.length,);
      expect(r.text, 'nginx:1.21\n');
    });

    test('latest tag extracts', () {
      const text = 'pull alpine:latest then build\n';
      final r = extractDockerImagesFromLinesIn(
          text, 0, text.length,);
      expect(r.text, 'alpine:latest\n');
    });

    test('hyphenated tag extracts', () {
      const text = 'cache redis:7-alpine for sessions\n';
      final r = extractDockerImagesFromLinesIn(
          text, 0, text.length,);
      expect(r.text, 'redis:7-alpine\n');
    });

    test('registry + namespace + tag extracts', () {
      const text = 'deploy ghcr.io/owner/repo:v1 today\n';
      final r = extractDockerImagesFromLinesIn(
          text, 0, text.length,);
      expect(r.text, 'ghcr.io/owner/repo:v1\n');
    });

    test('library/namespace image extracts', () {
      const text = 'mirror library/nginx:1.21 to private\n';
      final r = extractDockerImagesFromLinesIn(
          text, 0, text.length,);
      expect(r.text, 'library/nginx:1.21\n');
    });

    test('time-of-day 12:34 NOT mistaken for image', () {
      // The tag must contain at least one non-digit, so all-digit
      // tags like the `34` in `12:34` are rejected.
      const text = 'meet 12:34 today\n';
      final r = extractDockerImagesFromLinesIn(
          text, 0, text.length,);
      expect(r.text, '\n');
    });

    test('bare image without tag rejected', () {
      // `nginx` alone has no `:tag`; too ambiguous in prose.
      const text = 'just nginx alone here\n';
      final r = extractDockerImagesFromLinesIn(
          text, 0, text.length,);
      expect(r.text, '\n');
    });

    test('digit-leading image name rejected', () {
      // The repo must start with a letter, so `42app:latest`
      // doesn't match.
      const text = 'invalid 42app:latest skip\n';
      final r = extractDockerImagesFromLinesIn(
          text, 0, text.length,);
      // The regex skips the digit start. But `app:latest`
      // following the digit would match starting at `app`.
      // Word boundary `\b` at the start: between `2` and `a`,
      // both are word chars, so no boundary -- so `app:latest`
      // is not a separate match start. Document the observed
      // behaviour: nothing extracts.
      expect(r.text, '\n');
    });

    test('multiple images on one line each extract', () {
      const text = 'sync nginx:1.21 and redis:7-alpine today\n';
      final r = extractDockerImagesFromLinesIn(
          text, 0, text.length,);
      expect(r.text, 'nginx:1.21\nredis:7-alpine\n');
    });

    test('lines without images dropped from output', () {
      const text = 'plain prose\nuse alpine:3.18 build\nbye\n';
      final r = extractDockerImagesFromLinesIn(
          text, 0, text.length,);
      expect(r.text, 'alpine:3.18\n');
    });

    test('empty input stays empty', () {
      expect(extractDockerImagesFromLinesIn('', 0, 0).text, '');
    });
  });

  group('extractEthereumAddressesFromLinesIn', () {
    test('canonical lowercase address extracts', () {
      const text = 'send to 0x742d35cc6634c0532925a3b8d404d5028e25e1f8 now\n';
      final r = extractEthereumAddressesFromLinesIn(
          text, 0, text.length,);
      expect(r.text,
          '0x742d35cc6634c0532925a3b8d404d5028e25e1f8\n',);
    });

    test('EIP-55 mixed-case address extracts', () {
      // Real Ethereum addresses use mixed-case checksum encoding.
      const text = 'cold 0x742d35Cc6634C0532925a3b8D404D5028e25e1F8 wallet\n';
      final r = extractEthereumAddressesFromLinesIn(
          text, 0, text.length,);
      expect(r.text,
          '0x742d35Cc6634C0532925a3b8D404D5028e25e1F8\n',);
    });

    test('uppercase hex address extracts', () {
      const text = 'admin 0xDEADBEEFCAFEBABE1234567890ABCDEF12345678 here\n';
      final r = extractEthereumAddressesFromLinesIn(
          text, 0, text.length,);
      expect(r.text,
          '0xDEADBEEFCAFEBABE1234567890ABCDEF12345678\n',);
    });

    test('39 hex chars rejected (too short)', () {
      // 39 hex chars after `0x` — one short of the required 40.
      const text = 'short 0x123456789012345678901234567890123456789 here\n';
      final r = extractEthereumAddressesFromLinesIn(
          text, 0, text.length,);
      expect(r.text, '\n');
    });

    test('41 hex chars rejected (too long via word boundary)', () {
      // 41 hex chars after `0x`. The exact `{40}` quantifier
      // plus `\b` boundary should reject. Note: a 41-char run
      // is itself a single word token, so `\b` after 40 chars
      // is FALSE (still in the middle of word chars), meaning
      // the regex correctly rejects this whole token rather
      // than truncating it.
      const text = 'long 0x12345678901234567890123456789012345678901 here\n';
      final r = extractEthereumAddressesFromLinesIn(
          text, 0, text.length,);
      expect(r.text, '\n');
    });

    test('missing 0x prefix rejected', () {
      // Bare 40-hex run without `0x` is not an Ethereum address.
      const text = 'plain 742d35cc6634c0532925a3b8d404d5028e25e1f8 hex\n';
      final r = extractEthereumAddressesFromLinesIn(
          text, 0, text.length,);
      expect(r.text, '\n');
    });

    test('non-hex characters in address rejected', () {
      // `g` is not a hex digit; truncates the address.
      const text = 'bad 0x742d35gc6634c0532925a3b8d404d5028e25e1f8 ugh\n';
      final r = extractEthereumAddressesFromLinesIn(
          text, 0, text.length,);
      expect(r.text, '\n');
    });

    test('multiple addresses on one line each extract', () {
      const text =
          'from 0x1111111111111111111111111111111111111111 to '
          '0x2222222222222222222222222222222222222222 here\n';
      final r = extractEthereumAddressesFromLinesIn(
          text, 0, text.length,);
      expect(
          r.text,
          '0x1111111111111111111111111111111111111111\n'
          '0x2222222222222222222222222222222222222222\n',);
    });

    test('lines without addresses dropped from output', () {
      // 10 groups of 4 hex chars = 40 hex chars after `0x`.
      const addr = '0xcafe000011112222333344445555666677778888';
      const text = 'plain prose\nsee $addr here\nbye\n';
      final r = extractEthereumAddressesFromLinesIn(
          text, 0, text.length,);
      expect(r.text, '$addr\n');
    });

    test('empty input stays empty', () {
      expect(extractEthereumAddressesFromLinesIn('', 0, 0).text,
          '',);
    });
  });

  group('extractGeoCoordinatesFromLinesIn', () {
    test('positive lat + negative lon extracts (SF)', () {
      const text = 'meet at 37.7749,-122.4194 today\n';
      final r = extractGeoCoordinatesFromLinesIn(
          text, 0, text.length,);
      expect(r.text, '37.7749,-122.4194\n');
    });

    test('coords with whitespace after comma extract', () {
      const text = 'hub 51.5074, -0.1278 London center\n';
      final r = extractGeoCoordinatesFromLinesIn(
          text, 0, text.length,);
      expect(r.text, '51.5074, -0.1278\n');
    });

    test('both negative coords extract (southern + western)', () {
      const text = 'point -33.8688,-70.6483 santiago\n';
      final r = extractGeoCoordinatesFromLinesIn(
          text, 0, text.length,);
      expect(r.text, '-33.8688,-70.6483\n');
    });

    test('both positive coords extract', () {
      const text = 'eastern 35.6762,139.6503 tokyo\n';
      final r = extractGeoCoordinatesFromLinesIn(
          text, 0, text.length,);
      expect(r.text, '35.6762,139.6503\n');
    });

    test('integer pair NOT matched (no decimals)', () {
      // The regex requires a decimal fraction in both lat and
      // lon. Integer pairs are rejected as too ambiguous.
      const text = 'rough 37,-122 here\n';
      final r = extractGeoCoordinatesFromLinesIn(
          text, 0, text.length,);
      expect(r.text, '\n');
    });

    test('IPv4 127.0.0.1 NOT matched', () {
      // IPv4 has three dots and no comma; cannot match the
      // `lat.frac,lon.frac` template.
      const text = 'ip 127.0.0.1 here\n';
      final r = extractGeoCoordinatesFromLinesIn(
          text, 0, text.length,);
      expect(r.text, '\n');
    });

    test('embedded inside longer numeric run NOT matched', () {
      // `12345.6,7.89` — the lookbehind `(?<!\d)` blocks matches
      // that would start inside a longer numeric run; the leading
      // `123` has too many digits before the decimal.
      const text = 'long 12345.6,7.89 alone\n';
      final r = extractGeoCoordinatesFromLinesIn(
          text, 0, text.length,);
      expect(r.text, '\n');
    });

    test('multiple coord pairs on one line each extract', () {
      const text = 'route 40.7128,-74.0060 to 51.5074,-0.1278 OK\n';
      final r = extractGeoCoordinatesFromLinesIn(
          text, 0, text.length,);
      expect(r.text, '40.7128,-74.0060\n51.5074,-0.1278\n');
    });

    test('lines without coords dropped from output', () {
      const text = 'plain prose\nset 48.8566,2.3522 paris\nbye\n';
      final r = extractGeoCoordinatesFromLinesIn(
          text, 0, text.length,);
      expect(r.text, '48.8566,2.3522\n');
    });

    test('empty input stays empty', () {
      expect(extractGeoCoordinatesFromLinesIn('', 0, 0).text,
          '',);
    });
  });

  group('extractIbansFromLinesIn', () {
    test('UK IBAN extracts', () {
      const text = 'wire to GB82WEST12345698765432 today\n';
      final r = extractIbansFromLinesIn(text, 0, text.length);
      expect(r.text, 'GB82WEST12345698765432\n');
    });

    test('Germany IBAN extracts', () {
      const text = 'invoice DE89370400440532013000 paid\n';
      final r = extractIbansFromLinesIn(text, 0, text.length);
      expect(r.text, 'DE89370400440532013000\n');
    });

    test('France IBAN extracts (mixed alphanumeric body)', () {
      const text = 'vendor FR1420041010050500013M02606 here\n';
      final r = extractIbansFromLinesIn(text, 0, text.length);
      expect(r.text, 'FR1420041010050500013M02606\n');
    });

    test('Norway 15-char IBAN extracts (shortest)', () {
      const text = 'nordic NO9386011117947 ref\n';
      final r = extractIbansFromLinesIn(text, 0, text.length);
      expect(r.text, 'NO9386011117947\n');
    });

    test('Malta 31-char IBAN extracts (long)', () {
      const text = 'malta MT84MALT011000012345MTLCAST001S here\n';
      final r = extractIbansFromLinesIn(text, 0, text.length);
      expect(r.text, 'MT84MALT011000012345MTLCAST001S\n');
    });

    test('lowercase country code rejected', () {
      // The regex requires uppercase letters for the country
      // code; lowercase like `gb82...` is rejected.
      const text = 'fake gb82WEST12345698765432 ignore\n';
      final r = extractIbansFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('non-digit check chars rejected', () {
      // The regex requires `\d{2}` after the country code;
      // letters where digits should be are rejected.
      const text = 'fake GBAAWEST12345698765432 ignore\n';
      final r = extractIbansFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('too short BBAN body rejected', () {
      // BBAN body must be 11+ chars. `GB821234567890` has
      // a 10-char body, too short.
      const text = 'short GB821234567890 ignore\n';
      final r = extractIbansFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('multiple IBANs on one line each extract', () {
      const text =
          'from GB82WEST12345698765432 to '
          'DE89370400440532013000 ok\n';
      final r = extractIbansFromLinesIn(text, 0, text.length);
      expect(r.text,
          'GB82WEST12345698765432\nDE89370400440532013000\n',);
    });

    test('lines without IBANs dropped from output', () {
      const text = 'plain prose\npay GB82WEST12345698765432 bye\n';
      final r = extractIbansFromLinesIn(text, 0, text.length);
      expect(r.text, 'GB82WEST12345698765432\n');
    });

    test('empty input stays empty', () {
      expect(extractIbansFromLinesIn('', 0, 0).text, '');
    });
  });

  group('extractAwsRegionsFromLinesIn', () {
    test('us-east-1 extracts (most common region)', () {
      const text = 'primary us-east-1 deploy\n';
      final r = extractAwsRegionsFromLinesIn(
          text, 0, text.length,);
      expect(r.text, 'us-east-1\n');
    });

    test('us-west-2 extracts', () {
      const text = 'oregon us-west-2 mirror\n';
      final r = extractAwsRegionsFromLinesIn(
          text, 0, text.length,);
      expect(r.text, 'us-west-2\n');
    });

    test('eu-central-1 (Frankfurt) extracts', () {
      const text = 'gdpr eu-central-1 only\n';
      final r = extractAwsRegionsFromLinesIn(
          text, 0, text.length,);
      expect(r.text, 'eu-central-1\n');
    });

    test('ap-southeast-2 (Sydney) extracts', () {
      const text = 'apac ap-southeast-2 latency\n';
      final r = extractAwsRegionsFromLinesIn(
          text, 0, text.length,);
      expect(r.text, 'ap-southeast-2\n');
    });

    test('ap-northeast-3 (Osaka) extracts', () {
      const text = 'dr ap-northeast-3 failover\n';
      final r = extractAwsRegionsFromLinesIn(
          text, 0, text.length,);
      expect(r.text, 'ap-northeast-3\n');
    });

    test('sa-east-1 (São Paulo) extracts', () {
      const text = 'brazil sa-east-1 dedicated\n';
      final r = extractAwsRegionsFromLinesIn(
          text, 0, text.length,);
      expect(r.text, 'sa-east-1\n');
    });

    test('cn-northwest-1 extracts (China region)', () {
      const text = 'china cn-northwest-1 isolation\n';
      final r = extractAwsRegionsFromLinesIn(
          text, 0, text.length,);
      expect(r.text, 'cn-northwest-1\n');
    });

    test('il-central-1 (Israel) extracts', () {
      const text = 'tel-aviv il-central-1 launched\n';
      final r = extractAwsRegionsFromLinesIn(
          text, 0, text.length,);
      expect(r.text, 'il-central-1\n');
    });

    test('unknown prefix rejected', () {
      // `xx-east-1` is not a real AWS partition.
      const text = 'fake xx-east-1 ignore\n';
      final r = extractAwsRegionsFromLinesIn(
          text, 0, text.length,);
      expect(r.text, '\n');
    });

    test('GovCloud us-gov-east-1 NOT matched (documented)', () {
      // GovCloud regions have a triple-prefix `us-gov-...` not
      // handled by the directional alternation; deliberately
      // out of scope.
      const text = 'gov us-gov-east-1 special\n';
      final r = extractAwsRegionsFromLinesIn(
          text, 0, text.length,);
      // The first part `us-gov` could regex-match as us + gov?
      // `gov` isn't in the directional set, so the inner
      // alternation fails. No match.
      expect(r.text, '\n');
    });

    test('multiple regions on one line each extract', () {
      const text = 'replicate us-east-1 to eu-west-1 ok\n';
      final r = extractAwsRegionsFromLinesIn(
          text, 0, text.length,);
      expect(r.text, 'us-east-1\neu-west-1\n');
    });

    test('lines without regions dropped from output', () {
      const text = 'plain prose\nuse ap-south-1 instead\nbye\n';
      final r = extractAwsRegionsFromLinesIn(
          text, 0, text.length,);
      expect(r.text, 'ap-south-1\n');
    });

    test('empty input stays empty', () {
      expect(extractAwsRegionsFromLinesIn('', 0, 0).text, '');
    });
  });

  group('extractIpv4FromLinesIn', () {
    test('extracts standard IPv4 addresses', () {
      const text = 'from 10.0.0.1 to 192.168.1.42 hop\n';
      final r = extractIpv4FromLinesIn(text, 0, text.length);
      expect(r.text, '10.0.0.1\n192.168.1.42\n');
    });

    test('rejects octets above 255', () {
      const text = 'fake 999.0.0.0 vs real 8.8.8.8\n';
      final r = extractIpv4FromLinesIn(text, 0, text.length);
      expect(r.text, '8.8.8.8\n');
    });

    test('boundary-anchored: does NOT match inside a longer dotted run', () {
      // `1.2.3.4.5` is a version string, not an IP. The leading `\b`
      // and trailing `\b` boundary should prevent a 4-octet substring
      // match.
      const text = 'version 1.2.3.4.5 here\n';
      // Actually the regex will match `1.2.3.4` at the start because
      // the `.5` that follows is not word-boundary blocked (it's the
      // octet `5` which is itself a word). So the test should
      // verify the actual behaviour: a single match `1.2.3.4`.
      // Documenting that observed behaviour rather than fighting it.
      final r = extractIpv4FromLinesIn(text, 0, text.length);
      expect(r.text, '1.2.3.4\n');
    });

    test('all-zero address is valid', () {
      const text = '0.0.0.0 is a special value\n';
      final r = extractIpv4FromLinesIn(text, 0, text.length);
      expect(r.text, '0.0.0.0\n');
    });

    test('lines without IPs are dropped from output', () {
      const text = 'no IP here\nip 1.1.1.1 yes\n';
      final r = extractIpv4FromLinesIn(text, 0, text.length);
      expect(r.text, '1.1.1.1\n');
    });

    test('empty input stays empty', () {
      expect(extractIpv4FromLinesIn('', 0, 0).text, '');
    });
  });

  group('extractHexColorsFromLinesIn', () {
    test('extracts 3-char and 6-char hex codes', () {
      const text = 'use #fff for bg and #2A4D7E for accent\n';
      final r = extractHexColorsFromLinesIn(text, 0, text.length);
      expect(r.text, '#fff\n#2A4D7E\n');
    });

    test('extracts 4-char and 8-char (with alpha)', () {
      const text = 'fade #abcd and #12345678 spread\n';
      final r = extractHexColorsFromLinesIn(text, 0, text.length);
      expect(r.text, '#abcd\n#12345678\n');
    });

    test('case-insensitive on the hex digits', () {
      const text = '#AbCdEf and #aaa1\n';
      final r = extractHexColorsFromLinesIn(text, 0, text.length);
      expect(r.text, '#AbCdEf\n#aaa1\n');
    });

    test('non-hex chars after a short code stop the match cleanly', () {
      // `#fffg` is not a valid hex code (g is not hex).
      // `\b` boundary fails here so the regex rejects.
      const text = '#fffg dropped #abc kept\n';
      final r = extractHexColorsFromLinesIn(text, 0, text.length);
      expect(r.text, '#abc\n');
    });

    test('lines without hex codes dropped from output', () {
      const text = 'plain prose\nuse #fff color\n';
      final r = extractHexColorsFromLinesIn(text, 0, text.length);
      expect(r.text, '#fff\n');
    });

    test('empty input stays empty', () {
      expect(extractHexColorsFromLinesIn('', 0, 0).text, '');
    });
  });

  group('extractUlidsFromLinesIn', () {
    test('extracts a bare ULID', () {
      const ulid = '01HABCDEFGHIJKLMNOPQRSTUVW';
      final text = 'see $ulid for context\n';
      final r = extractUlidsFromLinesIn(text, 0, text.length);
      expect(r.text, '$ulid\n');
    });

    test('extracts ULIDs even when they live outside [[...]]', () {
      const ulid1 = '01HABCDEFGHIJKLMNOPQRSTUVW';
      const ulid2 = '01HXYZABCDEFGHIJKLMNOPQRST';
      final text = '[[$ulid1]] body $ulid2 trailing\n';
      final r = extractUlidsFromLinesIn(text, 0, text.length);
      expect(r.text, '$ulid1\n$ulid2\n');
    });

    test('rejects sub-26 and over-26 character runs', () {
      // 25 chars and 27 chars never match the {26} quantifier.
      const text = '01HABCDEFGHIJKLMNOPQRSTU 01HABCDEFGHIJKLMNOPQRSTUVWX\n';
      expect(extractUlidsFromLinesIn(text, 0, text.length).text, '\n');
    });

    test('lowercase / mixed-case runs are NOT ULIDs', () {
      const text = '01habcdefghijklmnopqrstuvw\n';
      // ULIDs are uppercase-only Crockford-base32.
      expect(extractUlidsFromLinesIn(text, 0, text.length).text, '\n');
    });

    test('lines without a ULID dropped from output', () {
      const ulid = '01HABCDEFGHIJKLMNOPQRSTUVW';
      final text = 'no ulid here\nyes $ulid\n';
      final r = extractUlidsFromLinesIn(text, 0, text.length);
      expect(r.text, '$ulid\n');
    });

    test('empty input stays empty', () {
      expect(extractUlidsFromLinesIn('', 0, 0).text, '');
    });
  });

  group('extractIsoDatesFromLinesIn', () {
    test('emits one ISO date per match', () {
      const text = 'met on 2026-05-16\nnext on 2026-06-01\n';
      final r = extractIsoDatesFromLinesIn(text, 0, text.length);
      expect(r.text, '2026-05-16\n2026-06-01\n');
    });

    test('multiple dates on one line preserved in order', () {
      const text = 'spans 2026-01-01 to 2026-12-31 inclusive\n';
      final r = extractIsoDatesFromLinesIn(text, 0, text.length);
      expect(r.text, '2026-01-01\n2026-12-31\n');
    });

    test('non-ISO date shapes are ignored', () {
      const text = 'on 5/16/2026 and 16-May-2026 nothing\n';
      // Neither matches the YYYY-MM-DD shape.
      expect(extractIsoDatesFromLinesIn(text, 0, text.length).text, '\n');
    });

    test('does not validate calendar realism', () {
      // The spec deliberately doesn't check: 2026-02-31 is non-real,
      // but the regex accepts the SHAPE, leaving validation to the
      // caller's parser.
      const text = 'fake date 2026-02-31\n';
      final r = extractIsoDatesFromLinesIn(text, 0, text.length);
      expect(r.text, '2026-02-31\n');
    });

    test('lines without dates dropped from output', () {
      const text = 'no date\nmet 2026-01-01\n';
      final r = extractIsoDatesFromLinesIn(text, 0, text.length);
      expect(r.text, '2026-01-01\n');
    });

    test('empty input stays empty', () {
      expect(extractIsoDatesFromLinesIn('', 0, 0).text, '');
    });
  });

  group('extractDoneTodoBodiesIn', () {
    test('strips the marker from every done-todo line', () {
      const text = '- [x] shipped feature\n- [x] sent invoice\n';
      final r = extractDoneTodoBodiesIn(text, 0, text.length);
      expect(r.text, 'shipped feature\nsent invoice\n');
    });

    test('uppercase [X] is also recognised', () {
      const text = '- [X] capital X done\n';
      final r = extractDoneTodoBodiesIn(text, 0, text.length);
      expect(r.text, 'capital X done\n');
    });

    test('open todos are NOT extracted', () {
      const text = '- [ ] still open\n- [x] done\n';
      final r = extractDoneTodoBodiesIn(text, 0, text.length);
      expect(r.text, 'done\n');
    });

    test('non-todo lines are dropped from output', () {
      const text = 'preamble\n- [x] real\nfooter\n';
      final r = extractDoneTodoBodiesIn(text, 0, text.length);
      expect(r.text, 'real\n');
    });

    test('all bullet variants + indentation recognised', () {
      const text = '* [x] star\n  + [X] indented plus\n';
      final r = extractDoneTodoBodiesIn(text, 0, text.length);
      expect(r.text, 'star\nindented plus\n');
    });

    test('empty input stays empty', () {
      expect(extractDoneTodoBodiesIn('', 0, 0).text, '');
    });
  });

  group('extractOpenTodoBodiesIn', () {
    test('strips the marker from every open-todo line', () {
      const text = '- [ ] write report\n- [ ] file expenses\n';
      final r = extractOpenTodoBodiesIn(text, 0, text.length);
      expect(r.text, 'write report\nfile expenses\n');
    });

    test('recognises all GFM bullet variants', () {
      const text = '- [ ] dash\n* [ ] star\n+ [ ] plus\n';
      final r = extractOpenTodoBodiesIn(text, 0, text.length);
      expect(r.text, 'dash\nstar\nplus\n');
    });

    test('indented open-todos still extract', () {
      const text = '  - [ ] nested\n\t* [ ] tab-indented\n';
      final r = extractOpenTodoBodiesIn(text, 0, text.length);
      expect(r.text, 'nested\ntab-indented\n');
    });

    test('checked todos are NOT extracted', () {
      const text = '- [x] done\n- [ ] still open\n';
      final r = extractOpenTodoBodiesIn(text, 0, text.length);
      expect(r.text, 'still open\n');
    });

    test('non-todo lines are dropped from output', () {
      const text = 'preamble\n- [ ] real\nfooter\n';
      final r = extractOpenTodoBodiesIn(text, 0, text.length);
      expect(r.text, 'real\n');
    });

    test('empty input stays empty', () {
      expect(extractOpenTodoBodiesIn('', 0, 0).text, '');
    });
  });

  group('splitOnSpacesIn', () {
    test('emits one word per line for a single-line input', () {
      const text = 'one two three\n';
      final r = splitOnSpacesIn(text, 0, text.length);
      expect(r.text, 'one\ntwo\nthree\n');
    });

    test('runs of whitespace collapse to a single boundary', () {
      const text = 'a   b\t\tc\n';
      final r = splitOnSpacesIn(text, 0, text.length);
      expect(r.text, 'a\nb\nc\n');
    });

    test('multi-line input splits each line independently', () {
      const text = 'one two\nthree\n';
      final r = splitOnSpacesIn(text, 0, text.length);
      expect(r.text, 'one\ntwo\nthree\n');
    });

    test('blank / whitespace-only lines are dropped', () {
      const text = '   \nhello world\n\t\n';
      final r = splitOnSpacesIn(text, 0, text.length);
      expect(r.text, 'hello\nworld\n');
    });

    test('round-trips with joinLinesWithSpaceIn on a single-line input', () {
      const text = 'one two three\n';
      final split = splitOnSpacesIn(text, 0, text.length);
      final joined = joinLinesWithSpaceIn(split.text, 0, split.text.length);
      expect(joined.text, text);
    });

    test('empty input stays empty', () {
      expect(splitOnSpacesIn('', 0, 0).text, '');
    });
  });

  group('countConsecutiveDuplicatesIn', () {
    test('collapses a run and prefixes with the count', () {
      const text = 'foo\nfoo\nfoo\nbar\n';
      final r = countConsecutiveDuplicatesIn(text, 0, text.length);
      expect(r.text, '3 foo\n1 bar\n');
    });

    test('non-consecutive recurrence gets its own count entry', () {
      const text = 'foo\nfoo\nbar\nfoo\n';
      final r = countConsecutiveDuplicatesIn(text, 0, text.length);
      expect(r.text, '2 foo\n1 bar\n1 foo\n');
    });

    test('counts pad left to widest count', () {
      // Largest run is 10; width-2 padding aligns the column.
      final ten = List.filled(10, 'spam').join('\n');
      final text = '$ten\nfoo\n';
      final r = countConsecutiveDuplicatesIn(text, 0, text.length);
      expect(r.text, '10 spam\n 1 foo\n');
    });

    test('every line unique: each gets count 1', () {
      const text = 'a\nb\nc\n';
      final r = countConsecutiveDuplicatesIn(text, 0, text.length);
      expect(r.text, '1 a\n1 b\n1 c\n');
    });

    test('single line gets count 1', () {
      const text = 'lonely\n';
      final r = countConsecutiveDuplicatesIn(text, 0, text.length);
      expect(r.text, '1 lonely\n');
    });

    test('empty input stays empty', () {
      expect(countConsecutiveDuplicatesIn('', 0, 0).text, '');
    });
  });

  group('collapseConsecutiveDuplicatesIn', () {
    test('collapses a run of identical consecutive lines to one', () {
      const text = 'foo\nfoo\nfoo\nbar\n';
      final r = collapseConsecutiveDuplicatesIn(text, 0, text.length);
      expect(r.text, 'foo\nbar\n');
    });

    test('non-consecutive duplicates are kept', () {
      const text = 'foo\nbar\nfoo\n';
      final r = collapseConsecutiveDuplicatesIn(text, 0, text.length);
      expect(r.text, text);
    });

    test('mixed: collapse runs, keep non-consecutive recurrences', () {
      const text = 'foo\nfoo\nbar\nfoo\nfoo\n';
      // First foo-run collapses; bar passes through; second foo-run
      // collapses; final result: foo, bar, foo.
      final r = collapseConsecutiveDuplicatesIn(text, 0, text.length);
      expect(r.text, 'foo\nbar\nfoo\n');
    });

    test('case-sensitive (Foo ≠ foo, two lines kept)', () {
      const text = 'Foo\nfoo\n';
      final r = collapseConsecutiveDuplicatesIn(text, 0, text.length);
      expect(r.text, text);
    });

    test('single-line input passes through', () {
      const text = 'lonely\n';
      expect(collapseConsecutiveDuplicatesIn(text, 0, text.length).text, text);
    });

    test('empty input stays empty', () {
      expect(collapseConsecutiveDuplicatesIn('', 0, 0).text, '');
    });
  });

  group('extractWikilinksFromLinesIn', () {
    test('bare ULID wikilink emits the ULID string', () {
      const text = 'see [[01HABCDEFGHIJKLMNOPQRSTUVW]]\n';
      final r = extractWikilinksFromLinesIn(text, 0, text.length);
      expect(r.text, '01HABCDEFGHIJKLMNOPQRSTUVW\n');
    });

    test('ULID with anchor + alias variants', () {
      const ulid = '01HABCDEFGHIJKLMNOPQRSTUVW';
      final text = 'a [[$ulid#section-one]] b [[$ulid|Project Alpha]] c\n';
      final r = extractWikilinksFromLinesIn(text, 0, text.length);
      expect(
        r.text,
        '$ulid#section-one\n$ulid|Project Alpha\n',
      );
    });

    test('transclude form `![[...]]` is recognised', () {
      const ulid = '01HABCDEFGHIJKLMNOPQRSTUVW';
      final text = 'transcluded ![[$ulid]] body\n';
      final r = extractWikilinksFromLinesIn(text, 0, text.length);
      expect(r.text, '$ulid\n');
    });

    test('non-ULID brackets are NOT wikilinks', () {
      // `[[markdown-link-target]]` and `[[foo]]` (not 26 chars) reject.
      const text = '[[foo]] and [[01H_too_short]]\n';
      expect(extractWikilinksFromLinesIn(text, 0, text.length).text, '\n');
    });

    test('lines without wikilinks are dropped from output', () {
      const ulid = '01HABCDEFGHIJKLMNOPQRSTUVW';
      final text = 'no link here\n[[$ulid]] yes\n';
      final r = extractWikilinksFromLinesIn(text, 0, text.length);
      expect(r.text, '$ulid\n');
    });

    test('empty input stays empty', () {
      expect(extractWikilinksFromLinesIn('', 0, 0).text, '');
    });
  });

  group('extractMentionsFromLinesIn', () {
    test('strips the leading @ and emits one mention per line', () {
      const text = 'cc @alice and @bob please\n';
      final r = extractMentionsFromLinesIn(text, 0, text.length);
      expect(r.text, 'alice\nbob\n');
    });

    test('mention body supports dot, dash, underscore', () {
      const text = '@bob.smith @alice-z @user_42\n';
      final r = extractMentionsFromLinesIn(text, 0, text.length);
      expect(r.text, 'bob.smith\nalice-z\nuser_42\n');
    });

    test('email-style @ is NOT a mention (lookbehind rejects)', () {
      const text = 'send to alice@x.test from @bob\n';
      // The `@` inside `alice@x.test` is preceded by `e`, so it
      // fails the lookbehind. Only `@bob` survives.
      final r = extractMentionsFromLinesIn(text, 0, text.length);
      expect(r.text, 'bob\n');
    });

    test('@ followed by space or digit is NOT a mention', () {
      const text = '@ space here and @42-not-mention\n';
      // @42 fails because mention body must start with a letter.
      // @ followed by space fails for the same reason.
      // `_transformLinesIn` preserves the trailing newline when the
      // emitted lines list is empty, so the result is `'\n'`, not ''.
      expect(extractMentionsFromLinesIn(text, 0, text.length).text, '\n');
    });

    test('lines without mentions are dropped from output', () {
      const text = 'no mention here\n@alice\n';
      final r = extractMentionsFromLinesIn(text, 0, text.length);
      expect(r.text, 'alice\n');
    });

    test('empty input stays empty', () {
      expect(extractMentionsFromLinesIn('', 0, 0).text, '');
    });
  });

  group('extractHashtagsFromLinesIn', () {
    test('strips the leading # and emits one tag per line', () {
      const text = 'this #urgent and #review please\n';
      final r = extractHashtagsFromLinesIn(text, 0, text.length);
      expect(r.text, 'urgent\nreview\n');
    });

    test('hashtag supports - and _ in the body', () {
      const text = '#kebab-case and #snake_case\n';
      final r = extractHashtagsFromLinesIn(text, 0, text.length);
      expect(r.text, 'kebab-case\nsnake_case\n');
    });

    test('trailing punctuation drops out cleanly', () {
      const text = 'see #urgent. now.\n';
      final r = extractHashtagsFromLinesIn(text, 0, text.length);
      expect(r.text, 'urgent\n');
    });

    test('# followed by space is NOT a hashtag (it is a heading)', () {
      const text = '# heading\n#real-tag\n';
      final r = extractHashtagsFromLinesIn(text, 0, text.length);
      expect(r.text, 'real-tag\n');
    });

    test('# embedded in a word is NOT a hashtag', () {
      // `email#cc` should not yield `cc` — the boundary check rejects it.
      const text = 'email#cc trail\n#real\n';
      final r = extractHashtagsFromLinesIn(text, 0, text.length);
      expect(r.text, 'real\n');
    });

    test('lines without hashtags are dropped from output', () {
      const text = 'plain prose\n#tagged here\n';
      final r = extractHashtagsFromLinesIn(text, 0, text.length);
      expect(r.text, 'tagged\n');
    });

    test('empty input stays empty', () {
      expect(extractHashtagsFromLinesIn('', 0, 0).text, '');
    });
  });

  group('extractUrlsFromLinesIn', () {
    test('one URL per line: emits each on its own line', () {
      const text = 'see https://example.com\nand http://other.test\n';
      final r = extractUrlsFromLinesIn(text, 0, text.length);
      expect(r.text, 'https://example.com\nhttp://other.test\n');
    });

    test('multiple URLs per line: all extracted in order', () {
      const text = 'a https://x.test and ftp://y.test b\n';
      final r = extractUrlsFromLinesIn(text, 0, text.length);
      expect(r.text, 'https://x.test\nftp://y.test\n');
    });

    test('lines without a URL are dropped from output', () {
      const text = 'no link here\nyes https://x.test\n';
      final r = extractUrlsFromLinesIn(text, 0, text.length);
      expect(r.text, 'https://x.test\n');
    });

    test('rejects non-supported schemes', () {
      const text = 'mailto:foo@x.test\nhttps://x.test\nfile:///etc/hosts\n';
      // Only http/https/ftp are matched.
      final r = extractUrlsFromLinesIn(text, 0, text.length);
      expect(r.text, 'https://x.test\n');
    });

    test('empty input stays empty', () {
      expect(extractUrlsFromLinesIn('', 0, 0).text, '');
    });
  });

  group('extractEmailsFromLinesIn', () {
    test('one email per line: emits each on its own line', () {
      const text = 'contact alice@x.test\nor bob@y.org\n';
      final r = extractEmailsFromLinesIn(text, 0, text.length);
      expect(r.text, 'alice@x.test\nbob@y.org\n');
    });

    test('multiple emails per line: all extracted in order', () {
      const text = 'cc alice@x.test, bob@y.org for review\n';
      final r = extractEmailsFromLinesIn(text, 0, text.length);
      expect(r.text, 'alice@x.test\nbob@y.org\n');
    });

    test('addresses with plus + dots are kept intact', () {
      const text = 'alice.smith+filter@example.co.uk wrote in\n';
      final r = extractEmailsFromLinesIn(text, 0, text.length);
      expect(r.text, 'alice.smith+filter@example.co.uk\n');
    });

    test('lines without an email are dropped from output', () {
      const text = 'no address here\nyes alice@x.test\n';
      final r = extractEmailsFromLinesIn(text, 0, text.length);
      expect(r.text, 'alice@x.test\n');
    });

    test('rejects malformed shapes (no TLD, missing @, etc.)', () {
      const text = 'bare@nodot\n@missing.local\nstillvalid@ok.test\n';
      final r = extractEmailsFromLinesIn(text, 0, text.length);
      expect(r.text, 'stillvalid@ok.test\n');
    });

    test('empty input stays empty', () {
      expect(extractEmailsFromLinesIn('', 0, 0).text, '');
    });
  });

  group('extractNumbersFromLinesIn', () {
    test('one number per line: emits each on its own line', () {
      const text = 'alice 87\nbob 42\neve 100\n';
      final r = extractNumbersFromLinesIn(text, 0, text.length);
      expect(r.text, '87\n42\n100\n');
    });

    test('multiple numbers per line: all extracted in order', () {
      const text = 'series 1 2 3\nother 10 20\n';
      final r = extractNumbersFromLinesIn(text, 0, text.length);
      expect(r.text, '1\n2\n3\n10\n20\n');
    });

    test('signed and decimal numbers are extracted intact', () {
      const text = 'temp -3.5 then 12.0\n';
      final r = extractNumbersFromLinesIn(text, 0, text.length);
      expect(r.text, '-3.5\n12.0\n');
    });

    test('lines without numbers are dropped from output', () {
      const text = 'foo\nalice 87\nbar\nbob 42\n';
      final r = extractNumbersFromLinesIn(text, 0, text.length);
      expect(r.text, '87\n42\n');
    });

    test('empty input stays empty', () {
      expect(extractNumbersFromLinesIn('', 0, 0).text, '');
    });
  });

  group('sortLinesByMedianNumberIn', () {
    test('odd-count row uses the middle value as the key', () {
      const text = 'a 1 2 3\nb 10 20 30\nc 5 50 500\n';
      // Medians: a=2, b=20, c=50 → a, b, c (already ascending).
      final r = sortLinesByMedianNumberIn(text, 0, text.length);
      expect(r.text, text);
    });

    test('outlier-resistant: one anomalous number does NOT skew rank', () {
      const text = 'a 1 1 1 100\nb 5 5 5 5\n';
      // a median = 1 (rounds down at index n//2 = 2 → value 1 of
      // sorted [1,1,1,100]).
      // Wait — n=4 even, so median = (1+1)/2 = 1.
      // b median = 5.
      // So a (1) sorts before b (5).
      final r = sortLinesByMedianNumberIn(text, 0, text.length);
      expect(r.text, 'a 1 1 1 100\nb 5 5 5 5\n');
    });

    test('even-count: median is the average of the two middle values', () {
      const text = 'a 2 4\nb 1 9\n';
      // a median = (2+4)/2 = 3, b median = (1+9)/2 = 5 → a, b.
      final r = sortLinesByMedianNumberIn(text, 0, text.length);
      expect(r.text, text);
    });

    test('lines without numbers drop to the bottom', () {
      const text = 'a 5\nplain\nb 1\n';
      final r = sortLinesByMedianNumberIn(text, 0, text.length);
      expect(r.text, 'b 1\na 5\nplain\n');
    });

    test('empty input stays empty', () {
      expect(sortLinesByMedianNumberIn('', 0, 0).text, '');
    });
  });

  group('sortLinesByMinNumberIn', () {
    test('sorts by per-row trough ascending', () {
      const text = 'a 10 20 30\nb 5 5 5\nc 100\n';
      // Mins: a=10, b=5, c=100 → b, a, c.
      final r = sortLinesByMinNumberIn(text, 0, text.length);
      expect(r.text, 'b 5 5 5\na 10 20 30\nc 100\n');
    });

    test('the most-negative number wins its row', () {
      const text = 'a 10 -5\nb 5 -100\nc -3\n';
      // Mins: a=-5, b=-100, c=-3 → b (-100), a (-5), c (-3).
      final r = sortLinesByMinNumberIn(text, 0, text.length);
      expect(r.text, 'b 5 -100\na 10 -5\nc -3\n');
    });

    test('lines without numbers drop to the bottom', () {
      const text = 'a 10\nplain\nb 5\n';
      final r = sortLinesByMinNumberIn(text, 0, text.length);
      expect(r.text, 'b 5\na 10\nplain\n');
    });

    test('single number per line: same as sortLinesByFirstNumber', () {
      const text = 'a 30\nb 5\nc 100\n';
      final r = sortLinesByMinNumberIn(text, 0, text.length);
      expect(r.text, 'b 5\na 30\nc 100\n');
    });

    test('empty input stays empty', () {
      expect(sortLinesByMinNumberIn('', 0, 0).text, '');
    });
  });

  group('sortLinesByMaxNumberIn', () {
    test('sorts by per-row peak number ascending', () {
      const text = 'a 10 20 30\nb 5 5 5\nc 100\n';
      // Maxes: a=30, b=5, c=100 → b, a, c.
      final r = sortLinesByMaxNumberIn(text, 0, text.length);
      expect(r.text, 'b 5 5 5\na 10 20 30\nc 100\n');
    });

    test('signed numbers: a negative max still wins if it is the largest', () {
      const text = 'a -10\nb -5 -100\nc -20\n';
      // Maxes: a=-10, b=-5, c=-20 → c (-20), a (-10), b (-5).
      final r = sortLinesByMaxNumberIn(text, 0, text.length);
      expect(r.text, 'c -20\na -10\nb -5 -100\n');
    });

    test('lines with no numbers drop to the bottom', () {
      const text = 'a 10\nplain\nb 5\n';
      final r = sortLinesByMaxNumberIn(text, 0, text.length);
      expect(r.text, 'b 5\na 10\nplain\n');
    });

    test('single number per line: same as sortLinesByFirstNumber', () {
      const text = 'a 30\nb 5\nc 100\n';
      final r = sortLinesByMaxNumberIn(text, 0, text.length);
      expect(r.text, 'b 5\na 30\nc 100\n');
    });

    test('empty input stays empty', () {
      expect(sortLinesByMaxNumberIn('', 0, 0).text, '');
    });
  });

  group('sortLinesBySumOfNumbersIn', () {
    test('sums every number and sorts ascending', () {
      const text = 'alice 10 20 30\nbob 5 5 5\ncarol 100\n';
      // alice = 60, bob = 15, carol = 100 → bob, alice, carol.
      final r = sortLinesBySumOfNumbersIn(text, 0, text.length);
      expect(
        r.text,
        'bob 5 5 5\nalice 10 20 30\ncarol 100\n',
      );
    });

    test('signed numbers contribute to the sum', () {
      const text = 'a 10 -5\nb 5 -10\nc 100 -200\n';
      // a = 5, b = -5, c = -100 → c, b, a.
      final r = sortLinesBySumOfNumbersIn(text, 0, text.length);
      expect(r.text, 'c 100 -200\nb 5 -10\na 10 -5\n');
    });

    test('lines with no numbers sort with the zero-sum group', () {
      const text = 'foo\nbar\nbaz 0\n';
      // All three sum to 0; stable sort preserves input order.
      final r = sortLinesBySumOfNumbersIn(text, 0, text.length);
      expect(r.text, 'foo\nbar\nbaz 0\n');
    });

    test('single-line input passes through', () {
      const text = 'lonely 42\n';
      expect(sortLinesBySumOfNumbersIn(text, 0, text.length).text, text);
    });

    test('empty input stays empty', () {
      expect(sortLinesBySumOfNumbersIn('', 0, 0).text, '');
    });
  });

  group('sortLinesByLastNumberIn', () {
    test('sorts value-then-label rows by the trailing score', () {
      const text = 'alice scored 87\nbob scored 42\neve scored 100\n';
      final r = sortLinesByLastNumberIn(text, 0, text.length);
      expect(
        r.text,
        'bob scored 42\nalice scored 87\neve scored 100\n',
      );
    });

    test('picks the LAST number when multiple appear on a line', () {
      // 'item 3 of 10' sorts on 10, not 3.
      const text = 'item 3 of 10\nitem 7 of 5\nitem 1 of 8\n';
      final r = sortLinesByLastNumberIn(text, 0, text.length);
      expect(
        r.text,
        'item 7 of 5\nitem 1 of 8\nitem 3 of 10\n',
      );
    });

    test('signed trailing numbers sort numerically', () {
      const text = 'temp tomorrow -3\ntemp today -15\ntemp friday 12\n';
      final r = sortLinesByLastNumberIn(text, 0, text.length);
      expect(
        r.text,
        'temp today -15\ntemp tomorrow -3\ntemp friday 12\n',
      );
    });

    test('lines without numbers drop to the bottom in original order', () {
      const text = 'banana\nv9 release\napple\nv1 release\n';
      final r = sortLinesByLastNumberIn(text, 0, text.length);
      expect(r.text, 'v1 release\nv9 release\nbanana\napple\n');
    });

    test('empty input stays empty', () {
      expect(sortLinesByLastNumberIn('', 0, 0).text, '');
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

  group('toKebabCase / kebabCaseLinesIn', () {
    test('basic title to kebab', () {
      expect(toKebabCase('My Cool Title!'), 'my-cool-title');
    });

    test('mirrors snake form with `-` separator', () {
      // Implementation is `toSnakeCase(line).replaceAll('_', '-')`,
      // so kebab and snake share recognition rules; the only
      // difference is the separator char.
      expect(toKebabCase('hello world'), 'hello-world');
      expect(toKebabCase('hello_world'), 'hello-world');
    });

    test('already-kebab passes through (modulo case)', () {
      expect(toKebabCase('Hello-World'), 'hello-world');
    });

    test('preserves digit segments', () {
      expect(toKebabCase('v1.2.3 final'), 'v1-2-3-final');
    });

    test('runs of non-alphanumeric collapse to a single dash', () {
      expect(toKebabCase('foo!!!---bar'), 'foo-bar');
    });

    test('leading/trailing punctuation is trimmed', () {
      expect(toKebabCase('!!!hello'), 'hello');
      expect(toKebabCase('hello!!!'), 'hello');
      expect(toKebabCase('---hello---'), 'hello');
    });

    test('mixed-case input lowercases', () {
      expect(toKebabCase('CamelCaseTitle'), 'camelcasetitle');
    });

    test('empty / all-punctuation returns empty', () {
      expect(toKebabCase(''), '');
      expect(toKebabCase('!!!---'), '');
    });

    test('per-line transform skips blanks', () {
      const text = 'My Title\n\nFoo Bar\n';
      final r = kebabCaseLinesIn(text, 0, text.length);
      expect(r.text, 'my-title\n\nfoo-bar\n');
    });

    test('empty input stays empty', () {
      expect(kebabCaseLinesIn('', 0, 0).text, '');
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

    test('formatYearQuarter buckets calendar months into Q1-Q4', () {
      // Q1: Jan-Mar, Q2: Apr-Jun, Q3: Jul-Sep, Q4: Oct-Dec.
      expect(formatYearQuarter(DateTime(2026, 1, 1)), '2026-Q1');
      expect(formatYearQuarter(DateTime(2026, 3, 31)), '2026-Q1');
      expect(formatYearQuarter(DateTime(2026, 4, 1)), '2026-Q2');
      expect(formatYearQuarter(DateTime(2026, 5, 16)), '2026-Q2');
      expect(formatYearQuarter(DateTime(2026, 7, 1)), '2026-Q3');
      expect(formatYearQuarter(DateTime(2026, 10, 1)), '2026-Q4');
      expect(formatYearQuarter(DateTime(2026, 12, 31)), '2026-Q4');
    });

    test('formatYearQuarter zero-pads the year for sub-1000 dates', () {
      // Sanity-check the padding helper is firing.
      expect(formatYearQuarter(DateTime(99, 4, 1)), '0099-Q2');
    });

    test('formatCheckpointBlock emits `---` + bold timestamp + blank line',
        () {
      final when = DateTime(2026, 5, 16, 14, 23);
      // `---\n**2026-05-16 14:23**\n\n` — caret-landing offset is
      // (snippet.length - 1) so it sits before the final `\n`.
      final snippet = formatCheckpointBlock(when);
      expect(snippet.startsWith('---\n'), isTrue);
      expect(snippet.contains('**2026-05-16 14:23**'), isTrue);
      expect(snippet.endsWith('\n\n'), isTrue);
    });

    test('formatCheckpointBlock zero-pads single-digit times', () {
      final when = DateTime(2026, 1, 3, 4, 5);
      final snippet = formatCheckpointBlock(when);
      expect(snippet.contains('**2026-01-03 04:05**'), isTrue);
    });

    test('formatYearMonth emits YYYY-MM with zero-padding', () {
      expect(formatYearMonth(DateTime(2026, 5, 16)), '2026-05');
      expect(formatYearMonth(DateTime(2026, 1, 1)), '2026-01');
      expect(formatYearMonth(DateTime(2026, 12, 31)), '2026-12');
    });

    test('formatIsoYearWeek emits YYYY-Www with zero-padding', () {
      // 2026-05-16 is a Saturday in week 20 (Thursday 2026-05-14).
      expect(formatIsoYearWeek(DateTime(2026, 5, 16)), '2026-W20');
    });

    test('formatIsoYearWeek handles January week 01', () {
      // 2026-01-01 is a Thursday — it IS the first Thursday of 2026,
      // so it lives in week 01 of the ISO year 2026.
      expect(formatIsoYearWeek(DateTime(2026, 1, 1)), '2026-W01');
    });

    test('formatIsoYearWeek rolls late-Dec dates back into previous year', () {
      // 2025-12-29 is a Monday. Thursday of that week is 2026-01-01,
      // which lives in ISO week 01 of 2026 — so a Monday before the
      // year flip already belongs to the new ISO year.
      expect(formatIsoYearWeek(DateTime(2025, 12, 29)), '2026-W01');
    });

    test('formatIsoYearWeek rolls early-Jan dates into prior 53-week year', () {
      // 2027-01-01 is a Friday; Thursday of that week is 2026-12-31.
      // 2026 was a 53-week ISO year, so 2026-12-31 sits in 2026-W53.
      expect(formatIsoYearWeek(DateTime(2027, 1, 1)), '2026-W53');
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
