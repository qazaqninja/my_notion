import 'package:flutter/services.dart';
import 'package:super_editor/super_editor.dart';

import '../../domain/block_reorder.dart';

/// Pure-Dart key-event parser for the block reorder shortcut. Returns
/// the [BlockMoveDirection] if the event matches Cmd+Shift+ArrowUp /
/// Cmd+Shift+ArrowDown (Ctrl+Shift on Linux/Windows), else null.
///
/// Split from [blockReorderKeyboardAction] so the modifier-state
/// inputs are explicit and easily exercised in unit tests without
/// touching `HardwareKeyboard.instance` global state.
BlockMoveDirection? parseBlockReorderKey({
  required KeyEvent keyEvent,
  required bool isShiftPressed,
  required bool isPrimaryShortcutPressed,
}) {
  if (keyEvent is! KeyDownEvent && keyEvent is! KeyRepeatEvent) return null;
  if (!isPrimaryShortcutPressed) return null;
  if (!isShiftPressed) return null;
  if (keyEvent.logicalKey == LogicalKeyboardKey.arrowUp) {
    return BlockMoveDirection.up;
  }
  if (keyEvent.logicalKey == LogicalKeyboardKey.arrowDown) {
    return BlockMoveDirection.down;
  }
  return null;
}

/// `SuperEditorKeyboardAction` that handles Cmd+Shift+ArrowUp /
/// Cmd+Shift+ArrowDown (Ctrl+Shift on Linux/Windows) and dispatches a
/// `MoveNodeRequest` to swap the active block with its neighbor.
///
/// Sibling of source-mode's `moveLineUp` / `moveLineDown` operations
/// at `lib/features/editor/domain/source_line_ops.dart:35,61`.
///
/// Returns [ExecutionInstruction.haltExecution] only when it
/// successfully dispatches a request; on no-op paths
/// (filtered-out key, no valid move) it returns
/// [ExecutionInstruction.continueExecution] so super_editor's default
/// arrow-key selection-move still fires.
///
/// Coverage exemption (TS-01): no direct unit test. This handler is a
/// pure 3-step composition of:
///   1. [parseBlockReorderKey] — branching covered by 7 tests in
///      `block_reorder_keyboard_action_test.dart`.
///   2. [resolveBlockReorder] — branching covered by 11 tests in
///      `block_reorder_test.dart` (M1568).
///   3. `editContext.editor.execute([MoveNodeRequest(...)])` — single
///      built-in super_editor request with its own upstream coverage.
/// Constructing a real [SuperEditorContext] for a unit test requires
/// a `DocumentLayout` stub (an abstract widget-tier interface) that
/// adds more coupling than the orchestration line under test. Tested
/// end-to-end via the EditorBetaPage widget mount.
ExecutionInstruction blockReorderKeyboardAction({
  required SuperEditorContext editContext,
  required KeyEvent keyEvent,
}) {
  final direction = parseBlockReorderKey(
    keyEvent: keyEvent,
    isShiftPressed: HardwareKeyboard.instance.isShiftPressed,
    isPrimaryShortcutPressed: keyEvent.isPrimaryShortcutKeyPressed,
  );
  if (direction == null) return ExecutionInstruction.continueExecution;
  final move = resolveBlockReorder(
    document: editContext.document,
    selection: editContext.composer.selection,
    direction: direction,
  );
  if (move == null) return ExecutionInstruction.continueExecution;
  editContext.editor.execute([
    MoveNodeRequest(nodeId: move.nodeId, newIndex: move.newIndex),
  ]);
  return ExecutionInstruction.haltExecution;
}
