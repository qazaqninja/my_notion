import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/editor/domain/subscript_autoformat.dart';

void main() {
  group('detectSubscriptAutoformat', () {
    group('happy path', () {
      test('basic single-char `~x~` triggers at end', () {
        final match = detectSubscriptAutoformat(text: '~x~', caret: 3);
        expect(match, isNotNull);
        expect(match!.markerStart, 0);
        expect(match.markerEnd, 3);
        expect(match.inner, 'x');
      });

      test('mid-line `hello ~h2o~`', () {
        const text = 'hello ~h2o~';
        final match = detectSubscriptAutoformat(text: text, caret: text.length);
        expect(match, isNotNull);
        expect(match!.markerStart, 6);
        expect(match.markerEnd, 11);
        expect(match.inner, 'h2o');
      });

      test('multi-char inner `~CO2~`', () {
        final match = detectSubscriptAutoformat(text: '~CO2~', caret: 5);
        expect(match, isNotNull);
        expect(match!.markerStart, 0);
        expect(match.inner, 'CO2');
      });
    });

    group('no match', () {
      test('caret not at closing tilde (still typing inner)', () {
        expect(detectSubscriptAutoformat(text: '~x', caret: 2), isNull);
      });

      test('opener only — no closing tilde yet', () {
        expect(detectSubscriptAutoformat(text: '~', caret: 1), isNull);
      });

      test('empty text', () {
        expect(detectSubscriptAutoformat(text: '', caret: 0), isNull);
      });

      test('strike closer `~~strike~~` — caret-2 is also tilde', () {
        const text = '~~strike~~';
        final match = detectSubscriptAutoformat(text: text, caret: text.length);
        expect(match, isNull);
      });

      test('whitespace inside inner `~h o~` fails Pandoc rule', () {
        expect(detectSubscriptAutoformat(text: '~h o~', caret: 5), isNull);
      });

      test('newline inside inner `~h\\no~` fails', () {
        expect(detectSubscriptAutoformat(text: '~h\no~', caret: 5), isNull);
      });

      test('caret mid-span before closer', () {
        expect(detectSubscriptAutoformat(text: '~hello~', caret: 3), isNull);
      });

      test('opener flanked by tilde `~~x~` — refuses (no single-`~` opener)',
          () {
        expect(detectSubscriptAutoformat(text: '~~x~', caret: 4), isNull);
      });

      test('two-char `~~` cannot match (caret < 3 guard)', () {
        expect(detectSubscriptAutoformat(text: '~~', caret: 2), isNull);
      });

      test('empty inner `~~`-like with caret at 3 — refuses (closer flanked)',
          () {
        expect(detectSubscriptAutoformat(text: '~~~', caret: 3), isNull);
      });
    });

    group('edge cases', () {
      test('greedy: picks most recent valid opener `~a~b~`', () {
        final match = detectSubscriptAutoformat(text: '~a~b~', caret: 5);
        expect(match, isNotNull);
        expect(match!.markerStart, 2);
        expect(match.inner, 'b');
      });

      test('caret past end returns null', () {
        expect(detectSubscriptAutoformat(text: '~x~', caret: 4), isNull);
      });

      test('caret negative returns null', () {
        expect(detectSubscriptAutoformat(text: '~x~', caret: -1), isNull);
      });

      test('inner with digits and punctuation `~h&o~`', () {
        final match = detectSubscriptAutoformat(text: '~h&o~', caret: 5);
        expect(match, isNotNull);
        expect(match!.inner, 'h&o');
      });
    });
  });
}
