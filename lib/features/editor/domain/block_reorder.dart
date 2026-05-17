import 'package:super_editor/super_editor.dart';

/// Direction for a block reorder operation.
enum BlockMoveDirection {
  /// Move the active block up one position (toward index 0).
  up,

  /// Move the active block down one position (toward `nodeCount - 1`).
  down,
}

/// Pure-Dart resolver for the Cmd+Shift+ArrowUp/Down block reorder
/// keyboard action in the WYSIWYG editor. Sibling of source-mode's
/// [moveLineUp] / [moveLineDown] helpers.
///
/// Contract:
/// - Returns null when [selection] is null or non-collapsed (block
///   reorder operates on the active block under the caret, not a
///   range).
/// - Returns null when the extent node id is not present in [document].
/// - Returns null when the resolved move would leave the bounds of
///   the document (already at top for `up`, already at bottom for
///   `down`).
/// - Otherwise returns `(nodeId, newIndex)` where [newIndex] is the
///   index the caller should pass to a super_editor `MoveNodeRequest`.
({String nodeId, int newIndex})? resolveBlockReorder({
  required Document document,
  required DocumentSelection? selection,
  required BlockMoveDirection direction,
}) {
  if (selection == null || !selection.isCollapsed) return null;
  final nodeId = selection.extent.nodeId;
  final currentIndex = document.getNodeIndexById(nodeId);
  if (currentIndex < 0) return null;
  final newIndex = switch (direction) {
    BlockMoveDirection.up => currentIndex - 1,
    BlockMoveDirection.down => currentIndex + 1,
  };
  if (newIndex < 0 || newIndex >= document.nodeCount) return null;
  return (nodeId: nodeId, newIndex: newIndex);
}
