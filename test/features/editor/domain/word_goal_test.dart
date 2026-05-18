import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/editor/domain/word_goal.dart';

void main() {
  group('wordGoalLabel', () {
    test('1 word uses singular', () {
      expect(wordGoalLabel(1), '1 word');
    });

    test('2+ words uses plural', () {
      expect(wordGoalLabel(2), '2 words');
      expect(wordGoalLabel(500), '500 words');
    });

    test('0 words uses plural (matches legacy editor)', () {
      // Mirrors the legacy editor's plural-for-zero choice.
      expect(wordGoalLabel(0), '0 words');
    });
  });

  group('wordGoalActionFor', () {
    test('empty input with no existing field is a no-op', () {
      expect(
        wordGoalActionFor(picked: '', existing: null),
        WordGoalAction.noop,
      );
    });

    test('whitespace-only input with no existing field is a no-op', () {
      // The trim() inside the planner means "   " is equivalent to "".
      expect(
        wordGoalActionFor(picked: '   ', existing: null),
        WordGoalAction.noop,
      );
    });

    test('empty input with an existing field schedules remove', () {
      expect(
        wordGoalActionFor(picked: '', existing: '500'),
        WordGoalAction.remove,
      );
    });

    test('non-numeric input is invalid', () {
      expect(
        wordGoalActionFor(picked: 'five', existing: null),
        WordGoalAction.invalid,
      );
    });

    test('zero is invalid (legacy editor requires n >= 1)', () {
      expect(
        wordGoalActionFor(picked: '0', existing: null),
        WordGoalAction.invalid,
      );
    });

    test('negative number is invalid', () {
      expect(
        wordGoalActionFor(picked: '-1', existing: null),
        WordGoalAction.invalid,
      );
    });

    test('valid input matching the existing rawScalar is a no-op', () {
      // Matches the "Word count goal already 500 words" branch.
      expect(
        wordGoalActionFor(picked: '500', existing: '500'),
        WordGoalAction.noopAlreadySet,
      );
    });

    test('whitespace around the existing rawScalar still counts as matching',
        () {
      // The existing rawScalar may carry incidental spaces from YAML
      // serialisation; trim before comparing.
      expect(
        wordGoalActionFor(picked: '500', existing: '  500  '),
        WordGoalAction.noopAlreadySet,
      );
    });

    test('valid input with no existing field schedules add', () {
      expect(
        wordGoalActionFor(picked: '500', existing: null),
        WordGoalAction.add,
      );
    });

    test('valid input differing from existing rawScalar schedules edit', () {
      expect(
        wordGoalActionFor(picked: '750', existing: '500'),
        WordGoalAction.edit,
      );
    });

    test('valid input with surrounding whitespace is parsed', () {
      // showQuillPrompt typically trims, but defend against drift.
      expect(
        wordGoalActionFor(picked: '  500  ', existing: null),
        WordGoalAction.add,
      );
    });
  });
}
