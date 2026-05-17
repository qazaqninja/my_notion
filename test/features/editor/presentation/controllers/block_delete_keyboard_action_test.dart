import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/editor/presentation/controllers/block_delete_keyboard_action.dart';

void main() {
  group('parseBlockDeleteKey', () {
    const backspaceDown = KeyDownEvent(
      physicalKey: PhysicalKeyboardKey.backspace,
      logicalKey: LogicalKeyboardKey.backspace,
      timeStamp: Duration.zero,
    );
    const backspaceRepeat = KeyRepeatEvent(
      physicalKey: PhysicalKeyboardKey.backspace,
      logicalKey: LogicalKeyboardKey.backspace,
      timeStamp: Duration.zero,
    );
    const backspaceUp = KeyUpEvent(
      physicalKey: PhysicalKeyboardKey.backspace,
      logicalKey: LogicalKeyboardKey.backspace,
      timeStamp: Duration.zero,
    );
    const keyA = KeyDownEvent(
      physicalKey: PhysicalKeyboardKey.keyA,
      logicalKey: LogicalKeyboardKey.keyA,
      timeStamp: Duration.zero,
    );

    group('happy path', () {
      test('Cmd+Shift+Backspace returns true', () {
        expect(
          parseBlockDeleteKey(
            keyEvent: backspaceDown,
            isShiftPressed: true,
            isPrimaryShortcutPressed: true,
          ),
          isTrue,
        );
      });

      test('Cmd+Shift+Backspace KeyRepeat returns true', () {
        expect(
          parseBlockDeleteKey(
            keyEvent: backspaceRepeat,
            isShiftPressed: true,
            isPrimaryShortcutPressed: true,
          ),
          isTrue,
        );
      });
    });

    group('no match', () {
      test('KeyUpEvent — only Down/Repeat trigger', () {
        expect(
          parseBlockDeleteKey(
            keyEvent: backspaceUp,
            isShiftPressed: true,
            isPrimaryShortcutPressed: true,
          ),
          isFalse,
        );
      });

      test('shift not pressed (plain Cmd+Backspace) — does not trigger', () {
        expect(
          parseBlockDeleteKey(
            keyEvent: backspaceDown,
            isShiftPressed: false,
            isPrimaryShortcutPressed: true,
          ),
          isFalse,
        );
      });

      test('primary shortcut not pressed (Shift+Backspace alone) — '
          'does not trigger', () {
        expect(
          parseBlockDeleteKey(
            keyEvent: backspaceDown,
            isShiftPressed: true,
            isPrimaryShortcutPressed: false,
          ),
          isFalse,
        );
      });

      test('non-backspace key (Cmd+Shift+A) does not trigger', () {
        expect(
          parseBlockDeleteKey(
            keyEvent: keyA,
            isShiftPressed: true,
            isPrimaryShortcutPressed: true,
          ),
          isFalse,
        );
      });
    });
  });
}
