import 'package:super_editor/super_editor.dart';

import 'block_conversion.dart';
import 'block_selection.dart';
import 'heading_conversion.dart';

/// Build the list of [EditRequest]s that deletes every node currently
/// in [selection]. Iterates in REVERSE document order so that each
/// `DeleteNodeRequest` operates on a stable index — deleting a later
/// node first doesn't shift the index of an earlier one.
///
/// Returns an empty list when [selection] is empty.
///
/// Caller is responsible for the "last-node" invariant (super_editor
/// rejects an empty document). When the selection covers all nodes,
/// drop the final id before dispatching.
List<EditRequest> deleteSelectedBlocks({
  required BlockSelection selection,
  required Document document,
}) {
  if (selection.isEmpty) return const [];
  final sorted = selection.nodeIds.toList()
    ..sort(
      (a, b) =>
          document.getNodeIndexById(b).compareTo(document.getNodeIndexById(a)),
    );
  return [for (final id in sorted) DeleteNodeRequest(nodeId: id)];
}

/// Build the list of [EditRequest]s that converts every paragraph
/// node in [selection] to [target]'s block type. Non-`ParagraphNode`
/// entries (ListItem/Task/HorizontalRule/Image) are silently skipped
/// — the caller can use [applyBlockConversionToSelection] when the
/// target is list-or-task.
///
/// Returns an empty list when [selection] is empty.
List<EditRequest> applyHeadingToSelection({
  required BlockSelection selection,
  required Document document,
  required HeadingLevel target,
}) {
  if (selection.isEmpty) return const [];
  final requests = <EditRequest>[];
  for (final nodeId in selection.nodeIds) {
    final node = document.getNodeById(nodeId);
    if (node is! ParagraphNode) continue;
    final blockType = switch (target) {
      HeadingLevel.h1 => header1Attribution,
      HeadingLevel.h2 => header2Attribution,
      HeadingLevel.h3 => header3Attribution,
      HeadingLevel.paragraph => null,
    };
    requests.add(
      ChangeParagraphBlockTypeRequest(nodeId: nodeId, blockType: blockType),
    );
  }
  return requests;
}

/// Build the list of [EditRequest]s that converts every selected
/// node to a list-item or task per [target]. Delegates per-node to
/// [requestsForBlockConversion] (M1587 / M1589) so cross-type
/// switches (ListItem↔Task) chain through paragraph automatically.
/// Non-TextNode entries are silently skipped.
///
/// Returns an empty list when [selection] is empty.
List<EditRequest> applyBlockConversionToSelection({
  required BlockSelection selection,
  required Document document,
  required BlockConversion target,
}) {
  if (selection.isEmpty) return const [];
  final requests = <EditRequest>[];
  for (final nodeId in selection.nodeIds) {
    final node = document.getNodeById(nodeId);
    if (node == null) continue;
    final perNode = requestsForBlockConversion(source: node, target: target);
    if (perNode != null) requests.addAll(perNode);
  }
  return requests;
}
