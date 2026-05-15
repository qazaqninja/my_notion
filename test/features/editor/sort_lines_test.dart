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
