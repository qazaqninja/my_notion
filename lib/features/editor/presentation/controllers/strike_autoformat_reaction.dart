import 'package:super_editor/super_editor.dart';

import '../../domain/strike_autoformat.dart';

/// `EditReaction` for the strikethrough autoformat trigger `~~X~~`.
/// Sister of [BoldAutoformatReaction] / [ItalicAutoformatReaction];
/// registered after both in `reactionPipeline` so bold + italic's
/// patterns are handled first when overlapping.
class StrikeAutoformatReaction extends EditReaction {
  /// Construct a reaction. Stateless, safe as a const singleton.
  const StrikeAutoformatReaction();

  @override
  void react(
    EditContext editorContext,
    RequestDispatcher requestDispatcher,
    List<EditEvent> changeList,
  ) {
    final composer = editorContext.find<MutableDocumentComposer>(
      Editor.composerKey,
    );
    final document = editorContext.find<MutableDocument>(Editor.documentKey);
    final selection = composer.selection;
    if (selection == null || !selection.isCollapsed) return;
    final extent = selection.extent;
    final nodePos = extent.nodePosition;
    if (nodePos is! TextNodePosition) return;
    final node = document.getNodeById(extent.nodeId);
    if (node is! TextNode) return;

    final match = detectStrikeAutoformat(
      text: node.text.toPlainText(),
      caret: nodePos.offset,
    );
    if (match == null) return;

    final start = DocumentPosition(
      nodeId: node.id,
      nodePosition: TextNodePosition(offset: match.markerStart),
    );
    final end = DocumentPosition(
      nodeId: node.id,
      nodePosition: TextNodePosition(offset: match.markerEnd),
    );
    requestDispatcher.execute([
      DeleteContentRequest(
        documentRange: DocumentRange(start: start, end: end),
      ),
      InsertTextRequest(
        documentPosition: start,
        textToInsert: match.inner,
        // Non-const: NamedAttribution overrides ==/hashCode.
        attributions: {strikethroughAttribution},
      ),
    ]);
  }
}
