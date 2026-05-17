import 'package:flutter/services.dart';
import 'package:super_editor/super_editor.dart';

import '../../domain/block_selection.dart';
import '../../domain/heading_conversion.dart';
import '../../domain/multi_block_ops.dart';

/// Pure-Dart key-event parser for the heading-conversion shortcut.
/// Returns the target [HeadingLevel] iff the event matches
/// Cmd+Opt+1/2/3/0 (Ctrl+Alt on Linux/Windows), else null.
///
/// Notion uses Cmd+Opt+1/2/3 for h1/h2/h3 + Cmd+Opt+0 for paragraph
/// (revert to body text).
///
/// Split from [headingConversionKeyboardAction] so the modifier-state
/// inputs are explicit and easily unit-tested without touching
/// `HardwareKeyboard.instance` global state.
HeadingLevel? parseHeadingConversionKey({
  required KeyEvent keyEvent,
  required bool isAltPressed,
  required bool isPrimaryShortcutPressed,
}) {
  if (keyEvent is! KeyDownEvent && keyEvent is! KeyRepeatEvent) return null;
  if (!isPrimaryShortcutPressed) return null;
  if (!isAltPressed) return null;
  final key = keyEvent.logicalKey;
  if (key == LogicalKeyboardKey.digit1) return HeadingLevel.h1;
  if (key == LogicalKeyboardKey.digit2) return HeadingLevel.h2;
  if (key == LogicalKeyboardKey.digit3) return HeadingLevel.h3;
  if (key == LogicalKeyboardKey.digit0) return HeadingLevel.paragraph;
  return null;
}

/// `SuperEditorKeyboardAction` for Cmd+Opt+1/2/3/0 heading conversion
/// in WYSIWYG. Sibling of the D24-family keyboard actions
/// (block_reorder, block_duplicate, block_delete).
///
/// Coverage exemption (TS-01): no direct unit test. This handler is
/// a pure 3-step composition of:
///   1. [parseHeadingConversionKey] — 8 unit tests below.
///   2. [resolveHeadingConversion] — 11 unit tests at M1583.
///   3. `editContext.editor.execute([ChangeParagraphBlockTypeRequest(...)])`
///      — super_editor built-in with its own upstream coverage.
/// Constructing a real [SuperEditorContext] for a unit test requires
/// a `DocumentLayout` widget-tier stub. Tested end-to-end via the
/// EditorBetaPage widget mount.
ExecutionInstruction headingConversionKeyboardAction({
  required SuperEditorContext editContext,
  required KeyEvent keyEvent,
}) {
  final target = parseHeadingConversionKey(
    keyEvent: keyEvent,
    isAltPressed: HardwareKeyboard.instance.isAltPressed,
    isPrimaryShortcutPressed: keyEvent.isPrimaryShortcutKeyPressed,
  );
  if (target == null) return ExecutionInstruction.continueExecution;
  final conv = resolveHeadingConversion(
    document: editContext.document,
    selection: editContext.composer.selection,
    target: target,
  );
  if (conv == null) return ExecutionInstruction.continueExecution;
  editContext.editor.execute([
    ChangeParagraphBlockTypeRequest(
      nodeId: conv.nodeId,
      blockType: conv.blockType,
    ),
  ]);
  return ExecutionInstruction.haltExecution;
}

/// D25 slice 5b (M1606): when [blockSelection] is non-empty, apply
/// the heading conversion to every selected paragraph in one batch.
/// Otherwise falls through to [headingConversionKeyboardAction]'s
/// single-block path.
ExecutionInstruction headingConversionKeyboardActionWithSelection({
  required SuperEditorContext editContext,
  required KeyEvent keyEvent,
  required BlockSelection blockSelection,
}) {
  if (blockSelection.isEmpty) {
    return headingConversionKeyboardAction(
      editContext: editContext,
      keyEvent: keyEvent,
    );
  }
  final target = parseHeadingConversionKey(
    keyEvent: keyEvent,
    isAltPressed: HardwareKeyboard.instance.isAltPressed,
    isPrimaryShortcutPressed: keyEvent.isPrimaryShortcutKeyPressed,
  );
  if (target == null) return ExecutionInstruction.continueExecution;
  final requests = applyHeadingToSelection(
    selection: blockSelection,
    document: editContext.document,
    target: target,
  );
  if (requests.isEmpty) return ExecutionInstruction.continueExecution;
  editContext.editor.execute(requests);
  return ExecutionInstruction.haltExecution;
}
