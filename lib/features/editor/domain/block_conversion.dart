import 'package:super_editor/super_editor.dart';

/// Target block type for the Cmd+Shift+7/8/9 keyboard shortcut in
/// WYSIWYG. Maps to super_editor's `ConvertParagraphToListItemRequest`
/// (ordered/unordered) or `ConvertParagraphToTaskRequest` (task) at
/// the handler in slice 2 — with appropriate type-switching dispatch
/// when the source is already a `ListItemNode` or `TaskNode`.
enum BlockConversion {
  /// `Cmd+Shift+8` — bulleted list.
  unorderedList,

  /// `Cmd+Shift+7` — numbered list.
  orderedList,

  /// `Cmd+Shift+9` — to-do checklist.
  task,
}

/// Pure-Dart resolver for the list/todo conversion keyboard shortcut
/// in the WYSIWYG editor (Cmd+Shift+7/8/9). Sibling of
/// [resolveHeadingConversion] (M1583) and the D24-family resolvers.
///
/// Contract:
/// - Returns null when [selection] is null or non-collapsed.
/// - Returns null when the extent node id is not present in
///   [document].
/// - Returns null when the extent node is NOT a [TextNode] (only
///   ParagraphNode / ListItemNode / TaskNode are convertible — the
///   slice-2 handler dispatches the right super_editor request pair
///   based on the source's runtime type).
/// - Otherwise returns `(nodeId, target)`.
({String nodeId, BlockConversion target})? resolveBlockConversion({
  required Document document,
  required DocumentSelection? selection,
  required BlockConversion target,
}) {
  if (selection == null || !selection.isCollapsed) return null;
  final nodeId = selection.extent.nodeId;
  final node = document.getNodeById(nodeId);
  if (node is! TextNode) return null;
  return (nodeId: nodeId, target: target);
}
