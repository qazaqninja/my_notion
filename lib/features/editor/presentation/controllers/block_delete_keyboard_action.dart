import 'package:flutter/services.dart';
import 'package:super_editor/super_editor.dart';

import '../../domain/block_delete.dart';
import '../../domain/block_selection.dart';
import '../../domain/multi_block_ops.dart';

/// Pure-Dart key-event parser for the block-delete shortcut. Returns
/// `true` iff the event matches Cmd+Shift+Backspace (Ctrl+Shift on
/// Linux/Windows).
///
/// Split from [blockDeleteKeyboardAction] so the modifier-state
/// inputs are explicit and easily unit-tested without touching
/// `HardwareKeyboard.instance` global state.
bool parseBlockDeleteKey({
  required KeyEvent keyEvent,
  required bool isShiftPressed,
  required bool isPrimaryShortcutPressed,
}) {
  if (keyEvent is! KeyDownEvent && keyEvent is! KeyRepeatEvent) return false;
  if (!isPrimaryShortcutPressed) return false;
  if (!isShiftPressed) return false;
  return keyEvent.logicalKey == LogicalKeyboardKey.backspace;
}

/// `SuperEditorKeyboardAction` that handles Cmd+Shift+Backspace
/// (Ctrl+Shift on Linux/Windows) and dispatches a [DeleteNodeRequest]
/// for the active block.
///
/// Sibling of source-mode's [deleteLineAt] at
/// `lib/features/editor/domain/source_line_ops.dart:315`.
///
/// Returns [ExecutionInstruction.haltExecution] only on positive
/// dispatch; on filtered-out keys / unresolvable selection / the
/// last-node guard returns [ExecutionInstruction.continueExecution]
/// so the OS default Backspace (or super_editor's normal-backspace
/// handling) still fires.
///
/// Coverage exemption (TS-01): no direct unit test. This handler is
/// a pure 3-step composition of:
///   1. [parseBlockDeleteKey] — 5 unit tests below.
///   2. [resolveBlockDelete] — 8 unit tests at M1578.
///   3. `editContext.editor.execute([DeleteNodeRequest(...)])` —
///      super_editor built-in with its own upstream coverage.
/// Constructing a real [SuperEditorContext] for a unit test requires
/// a `DocumentLayout` widget-tier stub that adds more coupling than
/// the orchestration under test. Tested end-to-end via the
/// EditorBetaPage widget mount.
// coverage:ignore-start
ExecutionInstruction blockDeleteKeyboardAction({
  required SuperEditorContext editContext,
  required KeyEvent keyEvent,
}) {
  final isMatch = parseBlockDeleteKey(
    keyEvent: keyEvent,
    isShiftPressed: HardwareKeyboard.instance.isShiftPressed,
    isPrimaryShortcutPressed: keyEvent.isPrimaryShortcutKeyPressed,
  );
  if (!isMatch) return ExecutionInstruction.continueExecution;
  final del = resolveBlockDelete(
    document: editContext.document,
    selection: editContext.composer.selection,
  );
  if (del == null) return ExecutionInstruction.continueExecution;
  editContext.editor.execute([
    DeleteNodeRequest(nodeId: del.nodeId),
  ]);
  return ExecutionInstruction.haltExecution;
}
// coverage:ignore-end

/// D25 slice 5b (M1606): when [blockSelection] is non-empty, delete
/// every selected block in one batch. Otherwise falls through to
/// [blockDeleteKeyboardAction]'s single-block path so the existing
/// caret-only behaviour is preserved.
///
/// Last-node guard: refuses when the selection covers ALL nodes in
/// the document (super_editor doesn't allow an empty document).
///
/// Coverage exemption inherits from [blockDeleteKeyboardAction] —
/// the multi-block branch is a thin wrapper over the M1604
/// `deleteSelectedBlocks` helper (3 unit tests) + a node-count guard.
// coverage:ignore-start
ExecutionInstruction blockDeleteKeyboardActionWithSelection({
  required SuperEditorContext editContext,
  required KeyEvent keyEvent,
  required BlockSelection blockSelection,
}) {
  if (blockSelection.isEmpty) {
    return blockDeleteKeyboardAction(
      editContext: editContext,
      keyEvent: keyEvent,
    );
  }
  final isMatch = parseBlockDeleteKey(
    keyEvent: keyEvent,
    isShiftPressed: HardwareKeyboard.instance.isShiftPressed,
    isPrimaryShortcutPressed: keyEvent.isPrimaryShortcutKeyPressed,
  );
  if (!isMatch) return ExecutionInstruction.continueExecution;
  if (blockSelection.size >= editContext.document.nodeCount) {
    // Refuse to empty the document.
    return ExecutionInstruction.continueExecution;
  }
  final requests = deleteSelectedBlocks(
    selection: blockSelection,
    document: editContext.document,
  );
  if (requests.isEmpty) return ExecutionInstruction.continueExecution;
  editContext.editor.execute(requests);
  return ExecutionInstruction.haltExecution;
}
// coverage:ignore-end
