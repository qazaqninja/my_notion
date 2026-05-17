import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/editor/domain/highlight_autoformat.dart';

void main() {
  group('detectHighlightAutoformat', () {
    group('happy path', () {
      test('"==hi==" with caret at end → match (0..6, "hi")', () {
        final m = detectHighlightAutoformat(text: '==hi==', caret: 6);
        expect(m, isNotNull);
        expect(m!.markerStart, 0);
        expect(m.markerEnd, 6);
        expect(m.inner, 'hi');
      });

      test('mid-line "hello ==world==" → match', () {
        final m = detectHighlightAutoformat(
          text: 'hello ==world==',
          caret: 15,
        );
        expect(m, isNotNull);
        expect(m!.markerStart, 6);
        expect(m.markerEnd, 15);
        expect(m.inner, 'world');
      });

      test('inner with spaces "==two words==" → match', () {
        final m = detectHighlightAutoformat(
          text: '==two words==',
          caret: 13,
        );
        expect(m?.inner, 'two words');
      });
    });

    group('no match', () {
      test('caret not immediately after closing `==` → no match', () {
        expect(
          detectHighlightAutoformat(text: '==hi==x', caret: 7),
          isNull,
        );
      });

      test('still typing — no closing `==` yet → no match', () {
        expect(
          detectHighlightAutoformat(text: '==hi', caret: 4),
          isNull,
        );
      });

      test('empty inner — `====` is not highlight → no match', () {
        expect(
          detectHighlightAutoformat(text: '====', caret: 4),
          isNull,
        );
      });

      test('only opening `==` typed → no match', () {
        expect(detectHighlightAutoformat(text: '==', caret: 2), isNull);
      });

      test('newline between markers → no match', () {
        expect(
          detectHighlightAutoformat(text: '==foo\nbar==', caret: 11),
          isNull,
        );
      });

      test('caret before the closing markers → no match', () {
        expect(
          detectHighlightAutoformat(text: '==hi==', caret: 4),
          isNull,
        );
      });

      test('empty text → no match', () {
        expect(detectHighlightAutoformat(text: '', caret: 0), isNull);
      });

      test('single `=` is NOT highlight (no v1.x marker meaning)', () {
        expect(
          detectHighlightAutoformat(text: '=foo=', caret: 5),
          isNull,
        );
      });
    });

    group('edge cases', () {
      test('most recent `==` opener wins (greedy from caret backwards)', () {
        // `==a== ==b==` — closer at 11. Walking back the most recent
        // opener is at offset 6.
        final m = detectHighlightAutoformat(
          text: '==a== ==b==',
          caret: 11,
        );
        expect(m, isNotNull);
        expect(m!.markerStart, 6);
        expect(m.inner, 'b');
      });

      test('inner with single `=` (not `==`) — still matches', () {
        // `==a=b==` — inner is `a=b`.
        final m = detectHighlightAutoformat(text: '==a=b==', caret: 7);
        expect(m, isNotNull);
        expect(m!.inner, 'a=b');
      });

      test('caret past end of text → no match (defensive)', () {
        expect(
          detectHighlightAutoformat(text: '==hi==', caret: 99),
          isNull,
        );
      });

      test('caret negative → no match (defensive)', () {
        expect(
          detectHighlightAutoformat(text: '==hi==', caret: -1),
          isNull,
        );
      });
    });
  });
}
