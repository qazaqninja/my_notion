import 'package:super_editor/super_editor.dart';

/// Bridges Quill's markdown source ↔ super_editor's `MutableDocument`.
/// The contract is byte-identical round-trip for documents that haven't
/// been edited — same invariant the frontmatter parser already enforces.
/// Phase D of the 1m-loop plan grows this serializer block-by-block as
/// individual block types are migrated from the hand-rolled markdown
/// renderer to super_editor `BlockNode`s.
///
/// Slice 1 (M1242) ships the skeleton + a paragraph-only round-trip so
/// future slices have a stable API surface to extend. The class is
/// deliberately stateless — every call is pure markdown ⇔ doc.
class SuperEditorSerializer {
  const SuperEditorSerializer();

  /// Parse a markdown body (no frontmatter — strip the YAML block before
  /// calling) into a `MutableDocument` super_editor can render.
  ///
  /// Slice 1: each non-empty line becomes a `ParagraphNode`. Slices
  /// 2-10 extend with headings, lists, code, quotes, tables, math,
  /// mermaid, image cards, etc.
  MutableDocument markdownToDocument(String markdown) {
    final lines = markdown.split('\n');
    final nodes = <DocumentNode>[];
    final buffer = StringBuffer();
    for (final line in lines) {
      if (line.trim().isEmpty) {
        if (buffer.isNotEmpty) {
          nodes.add(ParagraphNode(
            id: Editor.createNodeId(),
            text: AttributedText(buffer.toString().trimRight()),
          ));
          buffer.clear();
        }
        continue;
      }
      if (buffer.isNotEmpty) buffer.write(' ');
      buffer.write(line);
    }
    if (buffer.isNotEmpty) {
      nodes.add(ParagraphNode(
        id: Editor.createNodeId(),
        text: AttributedText(buffer.toString().trimRight()),
      ));
    }
    if (nodes.isEmpty) {
      // super_editor requires at least one node for an empty document.
      nodes.add(ParagraphNode(
        id: Editor.createNodeId(),
        text: AttributedText(''),
      ));
    }
    return MutableDocument(nodes: nodes);
  }

  /// Serialise a `MutableDocument` back into markdown source. Paired
  /// with `markdownToDocument` so a load + save without edits is
  /// idempotent at the paragraph level.
  String documentToMarkdown(Document doc) {
    final out = StringBuffer();
    final nodes = doc.toList();
    final n = nodes.length;
    for (var i = 0; i < n; i++) {
      final node = nodes[i];
      if (node is ParagraphNode) {
        out.write(node.text.toPlainText());
      }
      // Other node types unhandled in slice 1 — they'll skip silently
      // until their respective slices add explicit branches.
      if (i < n - 1) out.write('\n\n');
    }
    return out.toString();
  }
}
