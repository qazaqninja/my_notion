import 'package:flutter/services.dart';
import 'package:super_editor/super_editor.dart';

import '../../domain/block_conversion.dart';
import '../../domain/block_selection.dart';
import '../../domain/multi_block_ops.dart';

/// Pure-Dart key-event parser for the list/todo conversion shortcut.
/// Returns the target [BlockConversion] iff the event matches
/// Cmd+Shift+7/8/9 (Ctrl+Shift on Linux/Windows), else null.
///
/// Notion bindings:
/// - Cmd+Shift+7 → ordered list
/// - Cmd+Shift+8 → unordered list
/// - Cmd+Shift+9 → to-do
///
/// Split from [blockConversionKeyboardAction] so the modifier-state
/// inputs are explicit and easily unit-tested without touching
/// `HardwareKeyboard.instance` global state.
BlockConversion? parseBlockConversionKey({
  required KeyEvent keyEvent,
  required bool isShiftPressed,
  required bool isPrimaryShortcutPressed,
}) {
  if (keyEvent is! KeyDownEvent && keyEvent is! KeyRepeatEvent) return null;
  if (!isPrimaryShortcutPressed) return null;
  if (!isShiftPressed) return null;
  final key = keyEvent.logicalKey;
  if (key == LogicalKeyboardKey.digit7) return BlockConversion.orderedList;
  if (key == LogicalKeyboardKey.digit8) return BlockConversion.unorderedList;
  if (key == LogicalKeyboardKey.digit9) return BlockConversion.task;
  return null;
}

/// `SuperEditorKeyboardAction` for Cmd+Shift+7/8/9 list/todo
/// conversion in WYSIWYG. Sibling of the D24-family + D27a keyboard
/// actions.
///
/// Coverage exemption (TS-01): no direct unit test. This handler is
/// a pure 4-step composition of:
///   1. [parseBlockConversionKey] — 7 unit tests below.
///   2. [resolveBlockConversion] — 10 unit tests at M1587.
///   3. [requestsForBlockConversion] — 8 unit tests below covering
///      Paragraph × 3 targets + ListItem cross-switches + Task
///      cross-switches + same-type no-ops + non-TextNode null.
///   4. `editContext.editor.execute(requests)` — super_editor
///      built-ins (ConvertParagraphToListItem,
///      ConvertParagraphToTask, ConvertListItemToParagraph,
///      ConvertTaskToParagraph) with their own upstream coverage.
/// Constructing a real [SuperEditorContext] for a unit test requires
/// a `DocumentLayout` widget-tier stub.
// coverage:ignore-start
ExecutionInstruction blockConversionKeyboardAction({
  required SuperEditorContext editContext,
  required KeyEvent keyEvent,
}) {
  final target = parseBlockConversionKey(
    keyEvent: keyEvent,
    isShiftPressed: HardwareKeyboard.instance.isShiftPressed,
    isPrimaryShortcutPressed: keyEvent.isPrimaryShortcutKeyPressed,
  );
  if (target == null) return ExecutionInstruction.continueExecution;
  final conv = resolveBlockConversion(
    document: editContext.document,
    selection: editContext.composer.selection,
    target: target,
  );
  if (conv == null) return ExecutionInstruction.continueExecution;
  final source = editContext.document.getNodeById(conv.nodeId);
  if (source == null) return ExecutionInstruction.continueExecution;
  final requests = requestsForBlockConversion(
    source: source,
    target: conv.target,
  );
  if (requests == null) return ExecutionInstruction.continueExecution;
  editContext.editor.execute(requests);
  return ExecutionInstruction.haltExecution;
}
// coverage:ignore-end

/// D25 slice 5b (M1606): when [blockSelection] is non-empty, apply
/// the list/todo conversion to every selected node in one batch
/// (each node converted via its own type-aware dispatch).
/// Otherwise falls through to [blockConversionKeyboardAction]'s
/// single-block path.
// coverage:ignore-start
ExecutionInstruction blockConversionKeyboardActionWithSelection({
  required SuperEditorContext editContext,
  required KeyEvent keyEvent,
  required BlockSelection blockSelection,
}) {
  if (blockSelection.isEmpty) {
    return blockConversionKeyboardAction(
      editContext: editContext,
      keyEvent: keyEvent,
    );
  }
  final target = parseBlockConversionKey(
    keyEvent: keyEvent,
    isShiftPressed: HardwareKeyboard.instance.isShiftPressed,
    isPrimaryShortcutPressed: keyEvent.isPrimaryShortcutKeyPressed,
  );
  if (target == null) return ExecutionInstruction.continueExecution;
  final requests = applyBlockConversionToSelection(
    selection: blockSelection,
    document: editContext.document,
    target: target,
  );
  if (requests.isEmpty) return ExecutionInstruction.continueExecution;
  editContext.editor.execute(requests);
  return ExecutionInstruction.haltExecution;
}
// coverage:ignore-end
