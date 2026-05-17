import 'package:super_editor/super_editor.dart';

import '../../domain/bold_autoformat.dart';

/// `EditReaction` that auto-converts `**X**` to bold whenever the
/// composer's caret lands immediately after a completed `**...**`
/// pattern.
///
/// Wired into `_BetaEditorShellState._editor.reactionPipeline` after
/// super_editor's `defaultEditorReactions` so the block-prefix
/// reactions (Header / Unordered / Ordered / Blockquote /
/// HorizontalRule / ImageUrl / Dash) get first pass, then this one
/// handles inline marks.
///
/// Slice 1b of the D26 inline autoformat work. Sibling reactions for
/// italic / strike / inline code / highlight / sub / sup will follow
/// the same shape — detector + reaction pair per mark.
class BoldAutoformatReaction extends EditReaction {
  /// Construct a reaction. Stateless, safe as a const singleton.
  const BoldAutoformatReaction();

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

    final match = detectBoldAutoformat(
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
        // Non-const set literal — NamedAttribution overrides `==` /
        // `hashCode`, which `const_set_element_not_primitive_equality`
        // flags. Constructing per-call is the documented escape hatch.
        attributions: {boldAttribution},
      ),
    ]);
  }
}
