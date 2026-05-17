import 'package:super_editor/super_editor.dart';

/// Snapshot of a `super_editor` document's plain-text projection paired
/// with the caret offset within that projection. Suitable for feeding the
/// `slash_trigger` helpers (or any other markdown-mode logic) without
/// caring about node identities.
class DocumentPlainSelection {
  /// Construct a snapshot.
  const DocumentPlainSelection({required this.text, required this.caret});

  /// Plain-text concatenation of every node's text content. TextNodes
  /// contribute their `toPlainText()`; non-text nodes (`HorizontalRuleNode`,
  /// `ImageNode`, etc.) contribute an empty slot. Nodes are joined with `\n`.
  final String text;

  /// Caret offset inside [text]. `0` when the composer has no selection
  /// or the selected node isn't in the document. Equal to the selection's
  /// extent for expanded selections.
  final int caret;
}

/// Compute the plain-text + caret offset projection of [doc] given
/// [composer]'s current selection.
///
/// Used by the WYSIWYG slash-menu wiring inside EditorBetaPage (slice 2d)
/// so it can call the M1518 slash_trigger helpers identically to how
/// SourceView feeds them from a flat `TextEditingController`.
///
/// Contract:
/// - Concatenate every node's plain text in document order. Non-text
///   nodes contribute an empty string. Nodes are separated by `\n` so
///   the cross-node math matches what users see on screen.
/// - The caret is the extent of the composer's selection mapped to the
///   concatenated string. Returns `0` when there's no selection.
DocumentPlainSelection plainTextAndCaret({
  required Document doc,
  required DocumentComposer composer,
}) {
  final nodes = doc.toList();
  final buffer = StringBuffer();
  final offsets = <String, int>{};
  for (var i = 0; i < nodes.length; i++) {
    offsets[nodes[i].id] = buffer.length;
    final node = nodes[i];
    if (node is TextNode) {
      buffer.write(node.text.toPlainText());
    }
    if (i < nodes.length - 1) {
      buffer.write('\n');
    }
  }
  final text = buffer.toString();

  final selection = composer.selection;
  if (selection == null) {
    return DocumentPlainSelection(text: text, caret: 0);
  }
  final extent = selection.extent;
  final base = offsets[extent.nodeId];
  if (base == null) {
    return DocumentPlainSelection(text: text, caret: 0);
  }
  final inner = extent.nodePosition;
  final innerOffset = inner is TextNodePosition ? inner.offset : 0;
  return DocumentPlainSelection(text: text, caret: base + innerOffset);
}
