import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/editor/domain/strike_autoformat.dart';

void main() {
  group('detectStrikeAutoformat', () {
    group('happy path', () {
      test('"~~strike~~" with caret at end → match (0..10, "strike")', () {
        final m =
            detectStrikeAutoformat(text: '~~strike~~', caret: 10);
        expect(m, isNotNull);
        expect(m!.markerStart, 0);
        expect(m.markerEnd, 10);
        expect(m.inner, 'strike');
      });

      test('mid-line "hello ~~world~~" → match', () {
        final m = detectStrikeAutoformat(
          text: 'hello ~~world~~',
          caret: 15,
        );
        expect(m, isNotNull);
        expect(m!.markerStart, 6);
        expect(m.markerEnd, 15);
        expect(m.inner, 'world');
      });

      test('inner with spaces "a ~~two words~~" → match', () {
        final m = detectStrikeAutoformat(
          text: 'a ~~two words~~',
          caret: 15,
        );
        expect(m?.inner, 'two words');
      });
    });

    group('no match', () {
      test('caret not immediately after closing `~~` → no match', () {
        expect(
          detectStrikeAutoformat(text: '~~strike~~x', caret: 11),
          isNull,
        );
      });

      test('still typing — no closing `~~` yet → no match', () {
        expect(
          detectStrikeAutoformat(text: '~~strike', caret: 8),
          isNull,
        );
      });

      test('empty inner — `~~~~` is not strike → no match', () {
        expect(detectStrikeAutoformat(text: '~~~~', caret: 4), isNull);
      });

      test('only opening `~~` typed → no match', () {
        expect(detectStrikeAutoformat(text: '~~', caret: 2), isNull);
      });

      test('newline between markers → no match', () {
        expect(
          detectStrikeAutoformat(text: '~~foo\nbar~~', caret: 11),
          isNull,
        );
      });

      test('caret before the closing markers → no match', () {
        expect(
          detectStrikeAutoformat(text: '~~strike~~', caret: 8),
          isNull,
        );
      });

      test('empty text → no match', () {
        expect(detectStrikeAutoformat(text: '', caret: 0), isNull);
      });

      test("single tilde `~X~` is NOT strike — that's subscript (later "
          'slice)', () {
        expect(
          detectStrikeAutoformat(text: '~sub~', caret: 5),
          isNull,
        );
      });
    });

    group('edge cases', () {
      test('most recent `~~` opener wins (greedy from caret backwards)', () {
        // `a~~b~~ c~~d~~` — at caret 13 the closer at 11..13, walking
        // back the most recent opener is at offset 8.
        final m = detectStrikeAutoformat(
          text: 'a~~b~~ c~~d~~',
          caret: 13,
        );
        expect(m, isNotNull);
        expect(m!.markerStart, 8);
        expect(m.inner, 'd');
      });

      test('inner with single `~` (not `~~`) — still matches', () {
        // `~~a~b~~` — inner is `a~b`.
        final m = detectStrikeAutoformat(text: '~~a~b~~', caret: 7);
        expect(m, isNotNull);
        expect(m!.inner, 'a~b');
      });

      test('caret past end of text → no match (defensive)', () {
        expect(
          detectStrikeAutoformat(text: '~~strike~~', caret: 99),
          isNull,
        );
      });

      test('caret negative → no match (defensive)', () {
        expect(
          detectStrikeAutoformat(text: '~~strike~~', caret: -1),
          isNull,
        );
      });
    });
  });
}
