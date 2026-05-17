import 'package:super_editor/super_editor.dart';

/// Pure-Dart resolver for the Cmd+Shift+Backspace block delete keyboard
/// action in the WYSIWYG editor. Sibling of source-mode's
/// [deleteLineAt] helper at
/// `lib/features/editor/domain/source_line_ops.dart:315`.
///
/// Contract:
/// - Returns null when [selection] is null or non-collapsed (block
///   delete operates on the active block under the caret, not a
///   range).
/// - Returns null when the extent node id is not present in
///   [document].
/// - Returns null when there is only one node remaining in the
///   document — super_editor's `DeleteNodeRequest` does not allow
///   emptying the document. The user can still clear the last node's
///   text via normal backspace.
/// - Otherwise returns `(nodeId)` — the caller passes it to
///   `DeleteNodeRequest(nodeId: ...)`.
({String nodeId})? resolveBlockDelete({
  required Document document,
  required DocumentSelection? selection,
}) {
  if (selection == null || !selection.isCollapsed) return null;
  if (document.nodeCount <= 1) return null;
  final nodeId = selection.extent.nodeId;
  final currentIndex = document.getNodeIndexById(nodeId);
  if (currentIndex < 0) return null;
  return (nodeId: nodeId);
}
