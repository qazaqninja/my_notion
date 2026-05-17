import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/editor/domain/heading_conversion.dart';
import 'package:my_notion/features/editor/presentation/controllers/heading_conversion_keyboard_action.dart';

void main() {
  group('parseHeadingConversionKey', () {
    const digit1Down = KeyDownEvent(
      physicalKey: PhysicalKeyboardKey.digit1,
      logicalKey: LogicalKeyboardKey.digit1,
      timeStamp: Duration.zero,
    );
    const digit2Down = KeyDownEvent(
      physicalKey: PhysicalKeyboardKey.digit2,
      logicalKey: LogicalKeyboardKey.digit2,
      timeStamp: Duration.zero,
    );
    const digit3Down = KeyDownEvent(
      physicalKey: PhysicalKeyboardKey.digit3,
      logicalKey: LogicalKeyboardKey.digit3,
      timeStamp: Duration.zero,
    );
    const digit0Down = KeyDownEvent(
      physicalKey: PhysicalKeyboardKey.digit0,
      logicalKey: LogicalKeyboardKey.digit0,
      timeStamp: Duration.zero,
    );
    const digit1Up = KeyUpEvent(
      physicalKey: PhysicalKeyboardKey.digit1,
      logicalKey: LogicalKeyboardKey.digit1,
      timeStamp: Duration.zero,
    );
    const digit5Down = KeyDownEvent(
      physicalKey: PhysicalKeyboardKey.digit5,
      logicalKey: LogicalKeyboardKey.digit5,
      timeStamp: Duration.zero,
    );

    group('happy path', () {
      test('Cmd+Opt+1 returns HeadingLevel.h1', () {
        expect(
          parseHeadingConversionKey(
            keyEvent: digit1Down,
            isAltPressed: true,
            isPrimaryShortcutPressed: true,
          ),
          HeadingLevel.h1,
        );
      });

      test('Cmd+Opt+2 returns HeadingLevel.h2', () {
        expect(
          parseHeadingConversionKey(
            keyEvent: digit2Down,
            isAltPressed: true,
            isPrimaryShortcutPressed: true,
          ),
          HeadingLevel.h2,
        );
      });

      test('Cmd+Opt+3 returns HeadingLevel.h3', () {
        expect(
          parseHeadingConversionKey(
            keyEvent: digit3Down,
            isAltPressed: true,
            isPrimaryShortcutPressed: true,
          ),
          HeadingLevel.h3,
        );
      });

      test('Cmd+Opt+0 returns HeadingLevel.paragraph', () {
        expect(
          parseHeadingConversionKey(
            keyEvent: digit0Down,
            isAltPressed: true,
            isPrimaryShortcutPressed: true,
          ),
          HeadingLevel.paragraph,
        );
      });
    });

    group('no match', () {
      test('KeyUpEvent — only Down/Repeat trigger', () {
        expect(
          parseHeadingConversionKey(
            keyEvent: digit1Up,
            isAltPressed: true,
            isPrimaryShortcutPressed: true,
          ),
          isNull,
        );
      });

      test('alt not pressed (plain Cmd+1) — does not trigger', () {
        expect(
          parseHeadingConversionKey(
            keyEvent: digit1Down,
            isAltPressed: false,
            isPrimaryShortcutPressed: true,
          ),
          isNull,
        );
      });

      test('primary shortcut not pressed (Opt+1 alone) — does not trigger',
          () {
        expect(
          parseHeadingConversionKey(
            keyEvent: digit1Down,
            isAltPressed: true,
            isPrimaryShortcutPressed: false,
          ),
          isNull,
        );
      });

      test('non-matching digit (Cmd+Opt+5) does not trigger', () {
        expect(
          parseHeadingConversionKey(
            keyEvent: digit5Down,
            isAltPressed: true,
            isPrimaryShortcutPressed: true,
          ),
          isNull,
        );
      });
    });
  });
}
