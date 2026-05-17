import 'package:super_editor/super_editor.dart';

import '../../domain/inline_code_autoformat.dart';

/// `EditReaction` for the inline code autoformat trigger `` `X` ``.
/// Sister of [BoldAutoformatReaction] / [ItalicAutoformatReaction] /
/// [StrikeAutoformatReaction]; registered after them in
/// `reactionPipeline`. Single-char backtick marker — no flanking
/// concerns, no double-char sibling to disambiguate, so this reaction
/// could in principle run earlier in the pipeline. Order preserved for
/// reading symmetry with the rest of the inline-mark stack.
class InlineCodeAutoformatReaction extends EditReaction {
  /// Construct a reaction. Stateless, safe as a const singleton.
  const InlineCodeAutoformatReaction();

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

    final match = detectInlineCodeAutoformat(
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
        // Non-const: NamedAttribution overrides ==/hashCode. Note:
        // super_editor reuses `codeAttribution` for code-block blockType
        // metadata, but applied as a text attribution it renders as
        // inline-code styling. The dual use is intentional in the
        // super_editor API.
        attributions: {codeAttribution},
      ),
    ]);
  }
}
