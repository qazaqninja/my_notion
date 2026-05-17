import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/editor/domain/block_reorder.dart';
import 'package:my_notion/features/editor/presentation/controllers/block_reorder_keyboard_action.dart';

void main() {
  group('parseBlockReorderKey', () {
    const arrowUpDown = KeyDownEvent(
      physicalKey: PhysicalKeyboardKey.arrowUp,
      logicalKey: LogicalKeyboardKey.arrowUp,
      timeStamp: Duration.zero,
    );
    const arrowDownDown = KeyDownEvent(
      physicalKey: PhysicalKeyboardKey.arrowDown,
      logicalKey: LogicalKeyboardKey.arrowDown,
      timeStamp: Duration.zero,
    );
    const arrowUpRepeat = KeyRepeatEvent(
      physicalKey: PhysicalKeyboardKey.arrowUp,
      logicalKey: LogicalKeyboardKey.arrowUp,
      timeStamp: Duration.zero,
    );
    const arrowUpUp = KeyUpEvent(
      physicalKey: PhysicalKeyboardKey.arrowUp,
      logicalKey: LogicalKeyboardKey.arrowUp,
      timeStamp: Duration.zero,
    );
    const keyA = KeyDownEvent(
      physicalKey: PhysicalKeyboardKey.keyA,
      logicalKey: LogicalKeyboardKey.keyA,
      timeStamp: Duration.zero,
    );

    group('happy path (modifiers + arrow)', () {
      test('Cmd+Shift+ArrowUp returns up', () {
        expect(
          parseBlockReorderKey(
            keyEvent: arrowUpDown,
            isShiftPressed: true,
            isPrimaryShortcutPressed: true,
          ),
          BlockMoveDirection.up,
        );
      });

      test('Cmd+Shift+ArrowDown returns down', () {
        expect(
          parseBlockReorderKey(
            keyEvent: arrowDownDown,
            isShiftPressed: true,
            isPrimaryShortcutPressed: true,
          ),
          BlockMoveDirection.down,
        );
      });

      test('KeyRepeatEvent also matches (held-key repeat)', () {
        expect(
          parseBlockReorderKey(
            keyEvent: arrowUpRepeat,
            isShiftPressed: true,
            isPrimaryShortcutPressed: true,
          ),
          BlockMoveDirection.up,
        );
      });
    });

    group('no match (filtered)', () {
      test('KeyUpEvent — only Down/Repeat trigger', () {
        expect(
          parseBlockReorderKey(
            keyEvent: arrowUpUp,
            isShiftPressed: true,
            isPrimaryShortcutPressed: true,
          ),
          isNull,
        );
      });

      test('shift not pressed', () {
        expect(
          parseBlockReorderKey(
            keyEvent: arrowUpDown,
            isShiftPressed: false,
            isPrimaryShortcutPressed: true,
          ),
          isNull,
        );
      });

      test('primary shortcut (Cmd/Ctrl) not pressed', () {
        expect(
          parseBlockReorderKey(
            keyEvent: arrowUpDown,
            isShiftPressed: true,
            isPrimaryShortcutPressed: false,
          ),
          isNull,
        );
      });

      test('non-arrow key (Cmd+Shift+A) — does not trigger', () {
        expect(
          parseBlockReorderKey(
            keyEvent: keyA,
            isShiftPressed: true,
            isPrimaryShortcutPressed: true,
          ),
          isNull,
        );
      });
    });
  });
}
