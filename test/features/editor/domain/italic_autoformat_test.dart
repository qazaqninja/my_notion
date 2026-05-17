import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/editor/domain/italic_autoformat.dart';

void main() {
  group('detectItalicAutoformat', () {
    group('asterisk happy path', () {
      test('"*italic*" with caret at end → match (0..8, "italic")', () {
        final m = detectItalicAutoformat(text: '*italic*', caret: 8);
        expect(m, isNotNull);
        expect(m!.markerStart, 0);
        expect(m.markerEnd, 8);
        expect(m.inner, 'italic');
      });

      test('mid-line "hi *world*" → match', () {
        final m = detectItalicAutoformat(text: 'hi *world*', caret: 10);
        expect(m?.inner, 'world');
        expect(m?.markerStart, 3);
        expect(m?.markerEnd, 10);
      });

      test('inner with spaces "a *two words*" → match', () {
        final m =
            detectItalicAutoformat(text: 'a *two words*', caret: 13);
        expect(m?.inner, 'two words');
      });
    });

    group('underscore happy path', () {
      test('"_italic_" with caret at end → match', () {
        final m = detectItalicAutoformat(text: '_italic_', caret: 8);
        expect(m?.inner, 'italic');
        expect(m?.markerStart, 0);
        expect(m?.markerEnd, 8);
      });

      test('mid-line "hi _world_" → match', () {
        final m = detectItalicAutoformat(text: 'hi _world_', caret: 10);
        expect(m?.inner, 'world');
      });

      test('underscore preceded by space "foo _bar_" → match', () {
        final m = detectItalicAutoformat(text: 'foo _bar_', caret: 9);
        expect(m?.inner, 'bar');
      });
    });

    group('no match — bold collisions', () {
      test('"**bold**" caret at end → no match (bold owns this pattern)', () {
        expect(detectItalicAutoformat(text: '**bold**', caret: 8), isNull);
      });

      test('"**" caret 2 → no match (bold opener still being typed)', () {
        expect(detectItalicAutoformat(text: '**', caret: 2), isNull);
      });

      test('"***" caret 3 → no match (ambiguous, refuse to fire)', () {
        expect(detectItalicAutoformat(text: '***', caret: 3), isNull);
      });

      test('"*a**" caret 4 → no match (closer is part of a `**` run)', () {
        // The trailing `**` could be bold close + italic open. Skip.
        expect(detectItalicAutoformat(text: '*a**', caret: 4), isNull);
      });
    });

    group('no match — general', () {
      test('still typing — only opener "*" or "_" no closing yet', () {
        expect(detectItalicAutoformat(text: '*', caret: 1), isNull);
        expect(detectItalicAutoformat(text: '_', caret: 1), isNull);
        expect(detectItalicAutoformat(text: '*foo', caret: 4), isNull);
        expect(detectItalicAutoformat(text: '_foo', caret: 4), isNull);
      });

      test('empty inner "**" or "__" → no match', () {
        // For asterisk these are still bold-territory; either way no italic.
        expect(detectItalicAutoformat(text: '**', caret: 2), isNull);
        expect(detectItalicAutoformat(text: '__', caret: 2), isNull);
      });

      test('newline between markers → no match', () {
        expect(
          detectItalicAutoformat(text: '*foo\nbar*', caret: 9),
          isNull,
        );
        expect(
          detectItalicAutoformat(text: '_foo\nbar_', caret: 9),
          isNull,
        );
      });

      test('intra-word underscore "snake_case_x" → no match', () {
        // Caret right after the second `_`. The opener `_` is preceded
        // by a word char (`e`), which disqualifies it for italic.
        expect(
          detectItalicAutoformat(text: 'snake_case_', caret: 11),
          isNull,
        );
      });

      test('caret < 3 → no match (need at least `*X*`)', () {
        expect(detectItalicAutoformat(text: '*X', caret: 2), isNull);
      });

      test('caret past end → no match (defensive)', () {
        expect(detectItalicAutoformat(text: '*X*', caret: 99), isNull);
      });

      test('caret on non-marker char → no match', () {
        expect(detectItalicAutoformat(text: '*X*y', caret: 4), isNull);
      });
    });

    group('edge cases', () {
      test('most recent opener wins (greedy from caret backwards)', () {
        // `a *b* c *d*` — closer at index 10. Walking back for opener,
        // the most recent unflanked `*` is at index 8.
        final m =
            detectItalicAutoformat(text: 'a *b* c *d*', caret: 11);
        expect(m?.inner, 'd');
        expect(m?.markerStart, 8);
      });

      test('asterisk italic does NOT match when closer would form `**` '
          'with the character before it', () {
        // `a**b**` — caret 6. text[5]='*', text[4]='*' → caret-2 is `*`
        // which means the closing `*` belongs to a bold pair; italic
        // refuses.
        expect(detectItalicAutoformat(text: 'a**b**', caret: 6), isNull);
      });
    });
  });
}
