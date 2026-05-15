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
}
