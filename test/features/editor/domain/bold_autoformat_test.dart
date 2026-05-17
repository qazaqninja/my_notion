import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/editor/domain/bold_autoformat.dart';

void main() {
  group('detectBoldAutoformat', () {
    group('happy path', () {
      test('"**bold**" with caret at end → match (0..8, "bold")', () {
        final m = detectBoldAutoformat(text: '**bold**', caret: 8);
        expect(m, isNotNull);
        expect(m!.markerStart, 0);
        expect(m.markerEnd, 8);
        expect(m.inner, 'bold');
      });

      test('mid-line "hello **world**" → match (6..15, "world")', () {
        final m =
            detectBoldAutoformat(text: 'hello **world**', caret: 15);
        expect(m, isNotNull);
        expect(m!.markerStart, 6);
        expect(m.markerEnd, 15);
        expect(m.inner, 'world');
      });

      test('inner with spaces "a **two words**" → match', () {
        final m = detectBoldAutoformat(
          text: 'a **two words**',
          caret: 15,
        );
        expect(m?.inner, 'two words');
      });
    });

    group('no match', () {
      test('caret not immediately after closing `**` → no match', () {
        // `**bold**x` — caret after the trailing `x`, so the last 2
        // chars aren't `**`.
        expect(
          detectBoldAutoformat(text: '**bold**x', caret: 9),
          isNull,
        );
      });

      test('still typing — no closing `**` yet → no match', () {
        expect(
          detectBoldAutoformat(text: '**bold', caret: 6),
          isNull,
        );
      });

      test('empty inner — `****` is not bold → no match', () {
        expect(
          detectBoldAutoformat(text: '****', caret: 4),
          isNull,
        );
      });

      test('only opening `**` typed → no match', () {
        expect(
          detectBoldAutoformat(text: '**', caret: 2),
          isNull,
        );
      });

      test('newline between markers → no match', () {
        expect(
          detectBoldAutoformat(text: '**foo\nbar**', caret: 11),
          isNull,
        );
      });

      test('caret before the closing markers → no match', () {
        // The detector only fires once the closing `**` is typed.
        expect(
          detectBoldAutoformat(text: '**bold**', caret: 6),
          isNull,
        );
      });

      test('empty text → no match', () {
        expect(detectBoldAutoformat(text: '', caret: 0), isNull);
      });
    });

    group('edge cases', () {
      test('most recent `**` opener wins (greedy from caret backwards)', () {
        // `a**b** c**d**` — at caret 13 the most recent close is at 13,
        // walking back the most recent opening `**` is at offset 8.
        final m = detectBoldAutoformat(
          text: 'a**b** c**d**',
          caret: 13,
        );
        expect(m, isNotNull);
        expect(m!.markerStart, 8);
        expect(m.inner, 'd');
      });

      test('matched span contains a single `*` (not `**`) — still matches', () {
        // `**a*b**` — inner is `a*b`. Strikethrough doesn't apply
        // because tilde isn't involved.
        final m = detectBoldAutoformat(text: '**a*b**', caret: 7);
        expect(m, isNotNull);
        expect(m!.inner, 'a*b');
      });

      test('caret past end of text → no match (defensive)', () {
        expect(
          detectBoldAutoformat(text: '**bold**', caret: 99),
          isNull,
        );
      });

      test('caret negative → no match (defensive)', () {
        expect(
          detectBoldAutoformat(text: '**bold**', caret: -1),
          isNull,
        );
      });
    });
  });
}
