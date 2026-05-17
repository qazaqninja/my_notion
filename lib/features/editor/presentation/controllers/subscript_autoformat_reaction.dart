import 'package:super_editor/super_editor.dart';

import '../../domain/subscript_autoformat.dart';

/// `EditReaction` for the subscript autoformat trigger `~X~`
/// (Pandoc convention). Sister of [BoldAutoformatReaction] /
/// [ItalicAutoformatReaction] / [StrikeAutoformatReaction] /
/// [InlineCodeAutoformatReaction] / [HighlightAutoformatReaction].
///
/// Uses super_editor's built-in [subscriptAttribution]. Must be
/// registered AFTER [StrikeAutoformatReaction] in the editor's
/// reaction pipeline so strike's double-`~` closer is consumed first.
/// (The detector also defends against the strike collision directly,
/// but ordering keeps the pipeline cheaper.)
class SubscriptAutoformatReaction extends EditReaction {
  /// Construct a reaction. Stateless, safe as a const singleton.
  const SubscriptAutoformatReaction();

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

    final match = detectSubscriptAutoformat(
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
        attributions: {subscriptAttribution},
      ),
    ]);
  }
}
