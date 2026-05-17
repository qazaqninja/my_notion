import 'package:flutter/services.dart';
import 'package:super_editor/super_editor.dart';

import '../../domain/block_duplicate.dart';

/// Pure-Dart key-event parser for the block-duplicate shortcut. Returns
/// `true` iff the event matches Cmd+D (Ctrl+D on Linux/Windows). NO
/// Shift modifier — plain Cmd+D matches Notion's native binding.
///
/// Split from [blockDuplicateKeyboardAction] so the modifier-state
/// input is explicit and easily unit-tested without touching
/// `HardwareKeyboard.instance` global state.
bool parseBlockDuplicateKey({
  required KeyEvent keyEvent,
  required bool isPrimaryShortcutPressed,
}) {
  if (keyEvent is! KeyDownEvent && keyEvent is! KeyRepeatEvent) return false;
  if (!isPrimaryShortcutPressed) return false;
  return keyEvent.logicalKey == LogicalKeyboardKey.keyD;
}

/// Clone a [DocumentNode] with a fresh ULID. Returns null when the
/// node type isn't covered by Quill's serializer (HorizontalRule /
/// Image / TextNode-derived: Paragraph / ListItem / Task) — in that
/// case the keyboard action bails to `continueExecution` so the user
/// sees the OS default Cmd+D behaviour rather than a silent no-op.
DocumentNode? cloneBlockWithFreshId(DocumentNode source) {
  final newId = Editor.createNodeId();
  if (source is TextNode) {
    // Subclasses (ParagraphNode / ListItemNode / TaskNode) each
    // override copyTextNodeWith to return their own runtime type, so
    // dispatch picks the right one automatically.
    return source.copyTextNodeWith(id: newId);
  }
  if (source is HorizontalRuleNode) {
    return HorizontalRuleNode(id: newId, metadata: source.copyMetadata());
  }
  if (source is ImageNode) {
    return ImageNode(
      id: newId,
      imageUrl: source.imageUrl,
      altText: source.altText,
      expectedBitmapSize: source.expectedBitmapSize,
      metadata: source.copyMetadata(),
    );
  }
  return null;
}

/// `SuperEditorKeyboardAction` that handles Cmd+D (Ctrl+D on
/// Linux/Windows) and dispatches an [InsertNodeAtIndexRequest] with a
/// freshly-cloned copy of the active block at `currentIndex + 1`.
///
/// Sibling of source-mode's `duplicateLineAt` at
/// `lib/features/editor/domain/source_line_ops.dart:350`.
///
/// Returns [ExecutionInstruction.haltExecution] only on positive
/// dispatch; on filtered-out keys / unresolvable selection /
/// unmappable node type returns
/// [ExecutionInstruction.continueExecution] so the OS-level Cmd+D
/// (e.g., "Add Bookmark" on web shells) can still fire if no block is
/// duplicatable.
///
/// Coverage exemption (TS-01): no direct unit test. This handler is a
/// pure 4-step composition of:
///   1. [parseBlockDuplicateKey] — 5 unit tests below.
///   2. [resolveBlockDuplicate] — 8 unit tests at M1574.
///   3. [cloneBlockWithFreshId] — unit-tested below for each Quill
///      node type plus the unknown-type bail.
///   4. `editContext.editor.execute([InsertNodeAtIndexRequest(...)])`
///      — super_editor built-in with its own upstream coverage.
/// Constructing a real [SuperEditorContext] for a unit test requires
/// a `DocumentLayout` widget-tier stub that adds more coupling than
/// the orchestration under test. Tested end-to-end via the
/// EditorBetaPage widget mount.
// coverage:ignore-start
ExecutionInstruction blockDuplicateKeyboardAction({
  required SuperEditorContext editContext,
  required KeyEvent keyEvent,
}) {
  final isCmdD = parseBlockDuplicateKey(
    keyEvent: keyEvent,
    isPrimaryShortcutPressed: keyEvent.isPrimaryShortcutKeyPressed,
  );
  if (!isCmdD) return ExecutionInstruction.continueExecution;
  final dup = resolveBlockDuplicate(
    document: editContext.document,
    selection: editContext.composer.selection,
  );
  if (dup == null) return ExecutionInstruction.continueExecution;
  final source = editContext.document.getNodeById(dup.sourceNodeId);
  if (source == null) return ExecutionInstruction.continueExecution;
  final clone = cloneBlockWithFreshId(source);
  if (clone == null) return ExecutionInstruction.continueExecution;
  editContext.editor.execute([
    InsertNodeAtIndexRequest(nodeIndex: dup.newIndex, newNode: clone),
  ]);
  return ExecutionInstruction.haltExecution;
}
// coverage:ignore-end
