import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/editor/presentation/controllers/find_in_page_keyboard_action.dart';

KeyDownEvent _down(LogicalKeyboardKey key) => KeyDownEvent(
  physicalKey: PhysicalKeyboardKey.keyA, // physical key not inspected
  logicalKey: key,
  timeStamp: Duration.zero,
);

KeyUpEvent _up(LogicalKeyboardKey key) => KeyUpEvent(
  physicalKey: PhysicalKeyboardKey.keyA,
  logicalKey: key,
  timeStamp: Duration.zero,
);

KeyRepeatEvent _repeat(LogicalKeyboardKey key) => KeyRepeatEvent(
  physicalKey: PhysicalKeyboardKey.keyA,
  logicalKey: key,
  timeStamp: Duration.zero,
);

void main() {
  group('parseFindInPageKey', () {
    group('open (Cmd+F)', () {
      test('returns open on Cmd+F keydown', () {
        expect(
          parseFindInPageKey(
            keyEvent: _down(LogicalKeyboardKey.keyF),
            isShiftPressed: false,
            isPrimaryShortcutPressed: true,
          ),
          FindInPageKeyIntent.open,
        );
      });

      test('returns none on Cmd+F with shift', () {
        expect(
          parseFindInPageKey(
            keyEvent: _down(LogicalKeyboardKey.keyF),
            isShiftPressed: true,
            isPrimaryShortcutPressed: true,
          ),
          FindInPageKeyIntent.none,
        );
      });

      test('returns none on F without Cmd', () {
        expect(
          parseFindInPageKey(
            keyEvent: _down(LogicalKeyboardKey.keyF),
            isShiftPressed: false,
            isPrimaryShortcutPressed: false,
          ),
          FindInPageKeyIntent.none,
        );
      });
    });

    group('next (Cmd+G)', () {
      test('returns next on Cmd+G keydown', () {
        expect(
          parseFindInPageKey(
            keyEvent: _down(LogicalKeyboardKey.keyG),
            isShiftPressed: false,
            isPrimaryShortcutPressed: true,
          ),
          FindInPageKeyIntent.next,
        );
      });

      test('repeat (held key) also fires next', () {
        expect(
          parseFindInPageKey(
            keyEvent: _repeat(LogicalKeyboardKey.keyG),
            isShiftPressed: false,
            isPrimaryShortcutPressed: true,
          ),
          FindInPageKeyIntent.next,
        );
      });
    });

    group('previous (Cmd+Shift+G)', () {
      test('returns previous on Cmd+Shift+G keydown', () {
        expect(
          parseFindInPageKey(
            keyEvent: _down(LogicalKeyboardKey.keyG),
            isShiftPressed: true,
            isPrimaryShortcutPressed: true,
          ),
          FindInPageKeyIntent.previous,
        );
      });
    });

    group('close (Esc)', () {
      test('returns close on Esc keydown', () {
        expect(
          parseFindInPageKey(
            keyEvent: _down(LogicalKeyboardKey.escape),
            isShiftPressed: false,
            isPrimaryShortcutPressed: false,
          ),
          FindInPageKeyIntent.close,
        );
      });

      test('returns close even when Cmd held (Cmd+Esc → close)', () {
        expect(
          parseFindInPageKey(
            keyEvent: _down(LogicalKeyboardKey.escape),
            isShiftPressed: false,
            isPrimaryShortcutPressed: true,
          ),
          FindInPageKeyIntent.close,
        );
      });
    });

    group('none', () {
      test('returns none on KeyUpEvent', () {
        expect(
          parseFindInPageKey(
            keyEvent: _up(LogicalKeyboardKey.keyF),
            isShiftPressed: false,
            isPrimaryShortcutPressed: true,
          ),
          FindInPageKeyIntent.none,
        );
      });

      test('returns none on irrelevant keydown (Cmd+A)', () {
        expect(
          parseFindInPageKey(
            keyEvent: _down(LogicalKeyboardKey.keyA),
            isShiftPressed: false,
            isPrimaryShortcutPressed: true,
          ),
          FindInPageKeyIntent.none,
        );
      });

      test('returns none on plain key without modifier (G alone)', () {
        expect(
          parseFindInPageKey(
            keyEvent: _down(LogicalKeyboardKey.keyG),
            isShiftPressed: false,
            isPrimaryShortcutPressed: false,
          ),
          FindInPageKeyIntent.none,
        );
      });
    });
  });
}
