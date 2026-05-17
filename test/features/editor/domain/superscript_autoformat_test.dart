import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/editor/domain/superscript_autoformat.dart';

void main() {
  group('detectSuperscriptAutoformat', () {
    group('happy path', () {
      test('basic single-char `^2^` triggers at end', () {
        final match = detectSuperscriptAutoformat(text: '^2^', caret: 3);
        expect(match, isNotNull);
        expect(match!.markerStart, 0);
        expect(match.markerEnd, 3);
        expect(match.inner, '2');
      });

      test('mid-line `x^2^` (mathematical exponent)', () {
        const text = 'x^2^';
        final match =
            detectSuperscriptAutoformat(text: text, caret: text.length);
        expect(match, isNotNull);
        expect(match!.markerStart, 1);
        expect(match.markerEnd, 4);
        expect(match.inner, '2');
      });

      test('multi-char inner `^TM^`', () {
        final match = detectSuperscriptAutoformat(text: '^TM^', caret: 4);
        expect(match, isNotNull);
        expect(match!.markerStart, 0);
        expect(match.inner, 'TM');
      });
    });

    group('no match', () {
      test('caret not at closing caret (still typing inner)', () {
        expect(detectSuperscriptAutoformat(text: '^x', caret: 2), isNull);
      });

      test('opener only — no closing caret yet', () {
        expect(detectSuperscriptAutoformat(text: '^', caret: 1), isNull);
      });

      test('empty text', () {
        expect(detectSuperscriptAutoformat(text: '', caret: 0), isNull);
      });

      test('whitespace inside inner `^h o^` fails Pandoc rule', () {
        expect(detectSuperscriptAutoformat(text: '^h o^', caret: 5), isNull);
      });

      test('newline inside inner `^h\\no^` fails', () {
        expect(detectSuperscriptAutoformat(text: '^h\no^', caret: 5), isNull);
      });

      test('caret mid-span before closer', () {
        expect(detectSuperscriptAutoformat(text: '^hello^', caret: 3), isNull);
      });

      test('two-char `^^` cannot match (caret < 3 guard)', () {
        expect(detectSuperscriptAutoformat(text: '^^', caret: 2), isNull);
      });

      test('empty inner `^^^` — opener-adjacent-to-closer returns null', () {
        expect(detectSuperscriptAutoformat(text: '^^^', caret: 3), isNull);
      });
    });

    group('edge cases', () {
      test('greedy: picks most recent opener `^a^b^`', () {
        final match = detectSuperscriptAutoformat(text: '^a^b^', caret: 5);
        expect(match, isNotNull);
        expect(match!.markerStart, 2);
        expect(match.inner, 'b');
      });

      test('caret past end returns null', () {
        expect(detectSuperscriptAutoformat(text: '^2^', caret: 4), isNull);
      });

      test('caret negative returns null', () {
        expect(detectSuperscriptAutoformat(text: '^2^', caret: -1), isNull);
      });

      test('inner with digits and punctuation `^h&o^`', () {
        final match = detectSuperscriptAutoformat(text: '^h&o^', caret: 5);
        expect(match, isNotNull);
        expect(match!.inner, 'h&o');
      });

      test('caret == text.length on text shorter than 3 returns null', () {
        expect(detectSuperscriptAutoformat(text: '^^', caret: 2), isNull);
      });
    });
  });
}
