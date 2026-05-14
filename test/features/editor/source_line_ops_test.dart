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

  group('moveLineUp', () {
    test('swaps the middle line with the one above', () {
      final r = moveLineUp('aaa\nbbb\nccc', 5); // caret on 'b' col 1
      expect(r.text, 'bbb\naaa\nccc');
      expect(r.caret, 1);
    });

    test('no-op on first line', () {
      final r = moveLineUp('aaa\nbbb', 1);
      expect(r.text, 'aaa\nbbb');
      expect(r.caret, 1);
    });

    test('swap with an empty previous line preserves trailing content', () {
      // text:  "\nccc"  caret on 'c' (col 0)
      final r = moveLineUp('\nccc', 1);
      expect(r.text, 'ccc\n');
      expect(r.caret, 0);
    });

    test('keeps caret column when previous line is shorter', () {
      // "ab\nlonger"  caret on 'g' (col 4 of "longer")
      final r = moveLineUp('ab\nlonger', 7);
      expect(r.text, 'longer\nab');
      expect(r.caret, 4); // column 4 on "longer"
    });
  });

  group('moveLineDown', () {
    test('swaps the middle line with the one below', () {
      final r = moveLineDown('aaa\nbbb\nccc', 5); // caret on 'b' col 1
      expect(r.text, 'aaa\nccc\nbbb');
      expect(r.caret, 9); // col 1 on "bbb" which now starts at 8
    });

    test('no-op when caret is on the only line (no newline)', () {
      final r = moveLineDown('only', 2);
      expect(r.text, 'only');
      expect(r.caret, 2);
    });

    test('no-op when on the final content line followed by trailing \\n', () {
      // "aaa\nbbb\n" caret on 'b' (col 1) — there's a '\n' after but no
      // real line beneath.
      final r = moveLineDown('aaa\nbbb\n', 5);
      expect(r.text, 'aaa\nbbb\n');
      expect(r.caret, 5);
    });

    test('swap with an empty following line', () {
      // "aaa\n\nbbb" → move "aaa" down past empty line.
      final r = moveLineDown('aaa\n\nbbb', 1);
      expect(r.text, '\naaa\nbbb');
      expect(r.caret, 2); // col 1 on "aaa" which now starts at 1
    });
  });

  group('toggleCommentLine', () {
    test('wraps a plain line', () {
      final r = toggleCommentLine('hello', 2);
      expect(r.text, '<!-- hello -->');
      expect(r.caret, 7); // shifted right by len("<!-- ") = 5
    });

    test('unwraps a commented line', () {
      final r = toggleCommentLine('<!-- hello -->', 7);
      expect(r.text, 'hello');
      expect(r.caret, 2); // shifted left by 5
    });

    test('preserves leading whitespace on wrap and unwrap', () {
      final w = toggleCommentLine('  body', 4);
      expect(w.text, '  <!-- body -->');
      expect(w.caret, 9);
      final u = toggleCommentLine('  <!-- body -->', 9);
      expect(u.text, '  body');
      expect(u.caret, 4);
    });

    test('caret in leading whitespace does not shift', () {
      final r = toggleCommentLine('  hello', 1);
      expect(r.text, '  <!-- hello -->');
      expect(r.caret, 1);
    });

    test('operates on the middle line of a multi-line text', () {
      final r = toggleCommentLine('a\nbody\nc', 3); // caret on 'o' of body
      expect(r.text, 'a\n<!-- body -->\nc');
      expect(r.caret, 8); // 'o' shifted right by 5
    });

    test('round-trips: wrap then unwrap returns the original', () {
      const original = 'something here';
      final w = toggleCommentLine(original, 0);
      final u = toggleCommentLine(w.text, w.caret);
      expect(u.text, original);
    });
  });

  group('deleteLineAt', () {
    test('removes a middle line and lands caret on the line below', () {
      // caret on 'b' col 1 of "bbb"
      final r = deleteLineAt('aaa\nbbb\nccc\n', 5);
      expect(r.text, 'aaa\nccc\n');
      expect(r.caret, 5); // col 1 on "ccc"
    });

    test('removes the final line and moves caret up to the new last line',
        () {
      final r = deleteLineAt('aaa\nbbb', 5); // caret on "bbb"
      expect(r.text, 'aaa');
      expect(r.caret, 1); // col 1 on "aaa"
    });

    test('removes the only line → empties the text', () {
      final r = deleteLineAt('alone', 2);
      expect(r.text, '');
      expect(r.caret, 0);
    });

    test('removes the first line of a 2-line text', () {
      final r = deleteLineAt('aaa\nbbb\n', 1);
      expect(r.text, 'bbb\n');
      expect(r.caret, 1); // col 1 on "bbb"
    });

    test('caret column is clamped to the new line\'s length', () {
      // "abcdef\nxy" — delete first line, caret col 5 → end of "xy" (2)
      final r = deleteLineAt('abcdef\nxy', 5);
      expect(r.text, 'xy');
      expect(r.caret, 2);
    });

    test('removes the trailing empty line after a final \\n', () {
      // Caret at offset 4 is on the empty line after "abc\n". Column 0,
      // so after delete the caret lands at column 0 of "abc".
      final r = deleteLineAt('abc\n', 4);
      expect(r.text, 'abc');
      expect(r.caret, 0);
    });
  });

  group('lineRangeAt', () {
    test('returns bounds of the line under the caret', () {
      final r = lineRangeAt('aaa\nbbb\nccc', 5); // on "bbb"
      expect(r.start, 4);
      expect(r.end, 7);
    });

    test('first line — start 0, end before \\n', () {
      final r = lineRangeAt('hello\nworld', 2);
      expect(r.start, 0);
      expect(r.end, 5);
    });

    test('final line without trailing newline — end = text.length', () {
      final r = lineRangeAt('a\nbb', 3);
      expect(r.start, 2);
      expect(r.end, 4);
    });

    test('empty text → (0, 0)', () {
      final r = lineRangeAt('', 0);
      expect(r.start, 0);
      expect(r.end, 0);
    });
  });

  group('continueListAtNewline', () {
    test('continues `- ` bullet at end of an item', () {
      final r = continueListAtNewline('- one', 5);
      expect(r, isNotNull);
      expect(r!.text, '- one\n- ');
      expect(r.caret, 8);
    });

    test('continues `1. ` ordered list and increments number', () {
      final r = continueListAtNewline('1. first', 8);
      expect(r, isNotNull);
      expect(r!.text, '1. first\n2. ');
      expect(r.caret, 12);
    });

    test('continues 9. → 10. (multi-digit)', () {
      final r = continueListAtNewline('9. ninth', 8);
      expect(r!.text, '9. ninth\n10. ');
      expect(r.caret, 13);
    });

    test('continues `* ` star bullet', () {
      final r = continueListAtNewline('* a', 3);
      expect(r!.text, '* a\n* ');
    });

    test('continues `- [ ] ` todo as another unchecked todo', () {
      final r = continueListAtNewline('- [ ] task', 10);
      expect(r!.text, '- [ ] task\n- [ ] ');
    });

    test('continues `- [x] ` checked todo as a fresh `- [ ] `', () {
      final r = continueListAtNewline('- [x] done', 10);
      expect(r!.text, '- [x] done\n- [ ] ');
    });

    test('preserves indentation for nested items', () {
      final r = continueListAtNewline('  - nested', 10);
      expect(r!.text, '  - nested\n  - ');
    });

    test('terminates the list when the current item is empty', () {
      // "  - " with caret at end (offset 4): body is empty.
      final r = continueListAtNewline('  - ', 4);
      expect(r, isNotNull);
      expect(r!.text, '\n');
      expect(r.caret, 1);
    });

    test('returns null for a plain non-list line', () {
      expect(continueListAtNewline('hello world', 5), isNull);
    });

    test('returns null for a heading line', () {
      expect(continueListAtNewline('## Heading', 5), isNull);
    });
  });

  group('backspaceListMarker', () {
    test('strips `- ` when caret sits right after the marker', () {
      final r = backspaceListMarker('- ', 2);
      expect(r, isNotNull);
      expect(r!.text, '');
      expect(r.caret, 0);
    });

    test('strips `1. ` ordered marker', () {
      final r = backspaceListMarker('1. ', 3);
      expect(r!.text, '');
      expect(r.caret, 0);
    });

    test('strips `- [ ] ` unchecked todo marker', () {
      final r = backspaceListMarker('- [ ] ', 6);
      expect(r!.text, '');
      expect(r.caret, 0);
    });

    test('preserves leading indentation', () {
      final r = backspaceListMarker('  - ', 4);
      expect(r!.text, '  ');
      expect(r.caret, 2);
    });

    test('returns null when the item has body content', () {
      expect(backspaceListMarker('- hi', 4), isNull);
    });

    test('returns null when caret is mid-marker', () {
      // "- " caret at offset 1 (between `-` and ` `) — user is still
      // editing the marker. Don't fire.
      expect(backspaceListMarker('- ', 1), isNull);
    });

    test('only operates on the line under the caret in a multi-line text',
        () {
      final r = backspaceListMarker('first\n- ', 8);
      expect(r!.text, 'first\n');
      expect(r.caret, 6);
    });

    test('returns null for a plain line', () {
      expect(backspaceListMarker('hello', 5), isNull);
    });
  });
}
