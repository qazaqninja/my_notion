import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/editor/domain/source_line_ops.dart';

void main() {
  group('duplicateLineAt', () {
    test('duplicates a middle line, caret keeps same column', () {
      // "a\nbc\nd"  caret on the 'c' (offset 3, column 1).
      final r = duplicateLineAt('a\nbc\nd', 3);
      expect(r.text, 'a\nbc\nbc\nd');
      // New caret column 1 on the duplicated 'bc' line: index 5 (b),
      //                                                  6 (c).
      expect(r.caret, 6);
    });

    test('duplicates the final line and adds a newline before the copy',
        () {
      // Final line has no trailing \n. Caret column 2 on "foo".
      final r = duplicateLineAt('hello\nfoo', 8);
      expect(r.text, 'hello\nfoo\nfoo');
      // Caret in the copied "foo", column 2 ('o') → offset 12.
      expect(r.caret, 12);
    });

    test('duplicates the first line', () {
      final r = duplicateLineAt('alpha\nbeta', 0);
      expect(r.text, 'alpha\nalpha\nbeta');
      expect(r.caret, 6); // start of the new copy
    });

    test('caret at end-of-line uses column = line length', () {
      final r = duplicateLineAt('abc\ndef', 3); // at end of "abc"
      expect(r.text, 'abc\nabc\ndef');
      expect(r.caret, 7); // end of the duplicated "abc"
    });

    test('caret clamped when negative or beyond text length', () {
      final r1 = duplicateLineAt('x', -5);
      expect(r1.text, 'x\nx');
      expect(r1.caret, 2);

      final r2 = duplicateLineAt('x', 99);
      expect(r2.text, 'x\nx');
      expect(r2.caret, 3); // end of duplicated line
    });

    test('empty text → newline + empty copy', () {
      final r = duplicateLineAt('', 0);
      expect(r.text, '\n');
      expect(r.caret, 1);
    });
  });
}
