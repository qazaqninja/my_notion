import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/editor/domain/inline_code_autoformat.dart';

void main() {
  group('detectInlineCodeAutoformat', () {
    group('happy path', () {
      test('"`foo`" with caret at end → match (0..5, "foo")', () {
        final m = detectInlineCodeAutoformat(text: '`foo`', caret: 5);
        expect(m, isNotNull);
        expect(m!.markerStart, 0);
        expect(m.markerEnd, 5);
        expect(m.inner, 'foo');
      });

      test('mid-line "see `x` here" → match', () {
        final m =
            detectInlineCodeAutoformat(text: 'see `x` here', caret: 7);
        expect(m, isNotNull);
        expect(m!.markerStart, 4);
        expect(m.markerEnd, 7);
        expect(m.inner, 'x');
      });

      test('inner with spaces "`hello world`" → match', () {
        final m = detectInlineCodeAutoformat(
          text: '`hello world`',
          caret: 13,
        );
        expect(m?.inner, 'hello world');
      });
    });

    group('no match', () {
      test('still typing — no closing backtick yet', () {
        expect(
          detectInlineCodeAutoformat(text: '`foo', caret: 4),
          isNull,
        );
      });

      test('empty inner — `` ` ` `` (caret at second backtick) → no match',
          () {
        // `` `` `` is two adjacent backticks with nothing between them.
        expect(detectInlineCodeAutoformat(text: '``', caret: 2), isNull);
      });

      test('only opening backtick typed → no match', () {
        expect(detectInlineCodeAutoformat(text: '`', caret: 1), isNull);
      });

      test('newline between markers → no match', () {
        expect(
          detectInlineCodeAutoformat(text: '`foo\nbar`', caret: 9),
          isNull,
        );
      });

      test('caret before the closing marker → no match', () {
        expect(
          detectInlineCodeAutoformat(text: '`foo`', caret: 3),
          isNull,
        );
      });

      test('empty text → no match', () {
        expect(
          detectInlineCodeAutoformat(text: '', caret: 0),
          isNull,
        );
      });

      test('caret on non-marker char → no match', () {
        expect(
          detectInlineCodeAutoformat(text: '`foo`x', caret: 6),
          isNull,
        );
      });
    });

    group('edge cases', () {
      test('most recent opening backtick wins (greedy from caret backwards)',
          () {
        // text = `a` + `b` + `c` + `` ` `` → indices a=0, `=1, b=2,
        // `=3, c=4, `=5. caret=6, closer at index 5. Walking back from
        // index 4 finds the opener at index 3 (the most recent
        // backtick before the closer). Inner = text.substring(4, 5) = "c".
        final m = detectInlineCodeAutoformat(text: 'a`b`c`', caret: 6);
        expect(m, isNotNull);
        expect(m!.markerStart, 3);
        expect(m.inner, 'c');
      });

      test('inner cannot contain a backtick (it would have closed earlier)',
          () {
        // `a`b` — caret 5. Walking back finds opening backtick at offset
        // 2. Inner is `b` which is "b" (1 char). markerStart=2,
        // markerEnd=5, inner='b'.
        final m = detectInlineCodeAutoformat(text: '`a`b`', caret: 5);
        expect(m, isNotNull);
        expect(m!.markerStart, 2);
        expect(m.inner, 'b');
      });

      test('caret < 3 → no match (need at least "`X`")', () {
        expect(detectInlineCodeAutoformat(text: '`X', caret: 2), isNull);
      });

      test('caret past end of text → no match (defensive)', () {
        expect(
          detectInlineCodeAutoformat(text: '`foo`', caret: 99),
          isNull,
        );
      });

      test('caret negative → no match (defensive)', () {
        expect(
          detectInlineCodeAutoformat(text: '`foo`', caret: -1),
          isNull,
        );
      });
    });
  });
}
