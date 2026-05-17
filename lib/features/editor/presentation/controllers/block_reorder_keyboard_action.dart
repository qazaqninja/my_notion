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
