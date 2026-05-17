import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/editor/domain/block_selection_gesture.dart';

void main() {
  group('interpretBlockClick', () {
    group('missed click (no nodeId)', () {
      test('plain click clears', () {
        expect(
          interpretBlockClick(
            nodeId: null,
            isPrimaryShortcutPressed: false,
            isShiftPressed: false,
          ),
          BlockSelectionGestureIntent.clear,
        );
      });

      test('Cmd+Click on empty also clears', () {
        expect(
          interpretBlockClick(
            nodeId: null,
            isPrimaryShortcutPressed: true,
            isShiftPressed: false,
          ),
          BlockSelectionGestureIntent.clear,
        );
      });
    });

    group('block hit (nodeId present)', () {
      test('Cmd+Shift+Click → extend', () {
        expect(
          interpretBlockClick(
            nodeId: 'a',
            isPrimaryShortcutPressed: true,
            isShiftPressed: true,
          ),
          BlockSelectionGestureIntent.extend,
        );
      });

      test('Cmd+Click → toggle', () {
        expect(
          interpretBlockClick(
            nodeId: 'a',
            isPrimaryShortcutPressed: true,
            isShiftPressed: false,
          ),
          BlockSelectionGestureIntent.toggle,
        );
      });

      test('Shift+Click (no Cmd) → passthrough (super_editor caret-extend)',
          () {
        expect(
          interpretBlockClick(
            nodeId: 'a',
            isPrimaryShortcutPressed: false,
            isShiftPressed: true,
          ),
          BlockSelectionGestureIntent.passthrough,
        );
      });

      test('plain click → replace', () {
        expect(
          interpretBlockClick(
            nodeId: 'a',
            isPrimaryShortcutPressed: false,
            isShiftPressed: false,
          ),
          BlockSelectionGestureIntent.replace,
        );
      });
    });
  });
}
