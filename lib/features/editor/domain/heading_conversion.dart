import 'package:super_editor/super_editor.dart';

/// Target heading level for the Cmd+Opt+1/2/3/0 keyboard shortcut in
/// WYSIWYG. [paragraph] converts back to a plain paragraph (clears the
/// `blockType` metadata via a null attribution).
enum HeadingLevel { h1, h2, h3, paragraph }

/// Pure-Dart resolver for the heading-conversion keyboard shortcut in
/// the WYSIWYG editor (Cmd+Opt+1/2/3 → h1/h2/h3, Cmd+Opt+0 →
/// paragraph). Sibling of the D24-family resolvers
/// (`resolveBlockReorder`, `resolveBlockDuplicate`,
/// `resolveBlockDelete`).
///
/// Contract:
/// - Returns null when [selection] is null or non-collapsed.
/// - Returns null when the extent node id is not present in
///   [document].
/// - Returns null when the extent node is NOT a [ParagraphNode] —
///   super_editor's `ChangeParagraphBlockTypeRequest` only operates
///   on paragraphs. ListItem/Task nodes carry their own type; the
///   slash menu or a node-type conversion request handles those.
/// - Otherwise returns `(nodeId, blockType)` where blockType maps to
///   `header1/2/3Attribution` for h1/h2/h3 or null for paragraph
///   (resets the metadata).
({String nodeId, Attribution? blockType})? resolveHeadingConversion({
  required Document document,
  required DocumentSelection? selection,
  required HeadingLevel target,
}) {
  if (selection == null || !selection.isCollapsed) return null;
  final nodeId = selection.extent.nodeId;
  final node = document.getNodeById(nodeId);
  if (node is! ParagraphNode) return null;
  final blockType = switch (target) {
    HeadingLevel.h1 => header1Attribution,
    HeadingLevel.h2 => header2Attribution,
    HeadingLevel.h3 => header3Attribution,
    HeadingLevel.paragraph => null,
  };
  return (nodeId: nodeId, blockType: blockType);
}
