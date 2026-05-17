import 'package:super_editor/super_editor.dart';

/// Pure-Dart resolver for the Cmd+D block duplicate keyboard action
/// in the WYSIWYG editor. Sibling of source-mode's
/// [duplicateLineAt] helper at
/// `lib/features/editor/domain/source_line_ops.dart:350`.
///
/// Contract:
/// - Returns null when [selection] is null or non-collapsed (block
///   duplicate operates on the active block under the caret, not a
///   range — Notion behaves the same way).
/// - Returns null when the extent node id is not present in
///   [document].
/// - Otherwise returns `(sourceNodeId, newIndex)` where [newIndex] is
///   the index the caller should pass to a super_editor
///   `InsertNodeAtIndexRequest`. `newIndex == document.nodeCount` is
///   valid (append at the end) — the caller is free to clone the
///   node and insert it at that position.
///
/// The clone-with-fresh-ULID logic lives in the slice-2 keyboard
/// handler (it depends on super_editor's `Editor.createNodeId()` and
/// per-node `copyTextNodeWith` APIs); this resolver intentionally
/// stays index-only so its branching is exhaustively unit-testable
/// without touching the framework.
({String sourceNodeId, int newIndex})? resolveBlockDuplicate({
  required Document document,
  required DocumentSelection? selection,
}) {
  if (selection == null || !selection.isCollapsed) return null;
  final nodeId = selection.extent.nodeId;
  final currentIndex = document.getNodeIndexById(nodeId);
  if (currentIndex < 0) return null;
  return (sourceNodeId: nodeId, newIndex: currentIndex + 1);
}
