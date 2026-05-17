import 'package:super_editor/super_editor.dart';

import '../../../../core/markdown/super_editor_serializer.dart'
    show highlightAttribution;
import '../../domain/highlight_autoformat.dart';

/// `EditReaction` for the highlight autoformat trigger `==X==`.
/// Sister of [BoldAutoformatReaction] / [ItalicAutoformatReaction] /
/// [StrikeAutoformatReaction] / [InlineCodeAutoformatReaction].
///
/// Reuses [highlightAttribution] from
/// `lib/core/markdown/super_editor_serializer.dart:907` — Quill-side
/// custom attribution since super_editor doesn't ship one out of the
/// box. Defined at the serializer because that's where the
/// `<mark>`/`==X==` round-trip already references it.
class HighlightAutoformatReaction extends EditReaction {
  /// Construct a reaction. Stateless, safe as a const singleton.
  const HighlightAutoformatReaction();

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

    final match = detectHighlightAutoformat(
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
        attributions: {highlightAttribution},
      ),
    ]);
  }
}
