import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/editor/domain/slash_trigger.dart';

void main() {
  group('slashShouldOpen', () {
    test('opens when `/` is the very first character', () {
      expect(slashShouldOpen(text: '/', caret: 1), isTrue);
    });

    test('opens when `/` is preceded by a space (word boundary)', () {
      expect(slashShouldOpen(text: 'foo /', caret: 5), isTrue);
    });

    test('opens when `/` is preceded by a tab', () {
      expect(slashShouldOpen(text: 'foo\t/', caret: 5), isTrue);
    });

    test('opens when `/` is preceded by a newline', () {
      expect(slashShouldOpen(text: 'foo\n/', caret: 5), isTrue);
    });

    test('does NOT open mid-word (https:// URL case)', () {
      expect(slashShouldOpen(text: 'https:/', caret: 7), isFalse);
    });

    test('does NOT open after an alphanumeric char', () {
      expect(slashShouldOpen(text: 'a/', caret: 2), isFalse);
    });

    test('does NOT open when caret char is not `/`', () {
      expect(slashShouldOpen(text: 'foo', caret: 3), isFalse);
    });

    test('does NOT open at caret 0 (no char before caret)', () {
      expect(slashShouldOpen(text: '', caret: 0), isFalse);
    });
  });

  group('slashQueryBetween', () {
    test('returns chars typed after the trigger up to the caret', () {
      expect(
        slashQueryBetween(text: '/head', triggerStart: 1, caret: 5),
        'head',
      );
    });

    test('returns empty string when caret is right after the `/`', () {
      expect(
        slashQueryBetween(text: '/', triggerStart: 1, caret: 1),
        '',
      );
    });

    test('returns the same chars when called repeatedly (idempotent)', () {
      const text = 'foo /todo';
      expect(
        slashQueryBetween(text: text, triggerStart: 5, caret: 9),
        'todo',
      );
      expect(
        slashQueryBetween(text: text, triggerStart: 5, caret: 9),
        'todo',
      );
    });

    test('returns empty when caret is before triggerStart (guard branch)', () {
      expect(
        slashQueryBetween(text: '/foo', triggerStart: 4, caret: 2),
        '',
      );
    });

    test('returns empty when triggerStart is negative (guard branch)', () {
      expect(
        slashQueryBetween(text: 'foo', triggerStart: -1, caret: 0),
        '',
      );
    });

    test('returns empty when caret exceeds text length (guard branch)', () {
      expect(
        slashQueryBetween(text: 'ab', triggerStart: 1, caret: 99),
        '',
      );
    });
  });

  group('slashShouldDismiss', () {
    test('dismisses when the caret moves before the trigger', () {
      expect(
        slashShouldDismiss(text: '/foo', triggerStart: 1, caret: 0),
        isTrue,
      );
    });

    test('dismisses when the query span contains a space', () {
      expect(
        slashShouldDismiss(text: '/foo bar', triggerStart: 1, caret: 8),
        isTrue,
      );
    });

    test('dismisses when the query span contains a newline', () {
      expect(
        slashShouldDismiss(text: '/foo\nbar', triggerStart: 1, caret: 8),
        isTrue,
      );
    });

    test('keeps menu open while typing word chars', () {
      expect(
        slashShouldDismiss(text: '/head', triggerStart: 1, caret: 5),
        isFalse,
      );
    });

    test('dismisses when triggerStart is beyond the text length', () {
      expect(
        slashShouldDismiss(text: 'foo', triggerStart: 99, caret: 3),
        isTrue,
      );
    });
  });
}
