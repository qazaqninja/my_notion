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
  /// Supports (cumulative across slices):
  /// - Slice 1: paragraphs (soft-wrap merge, blank-line splits).
  /// - Slice 2: ATX headings `#`, `##`, `###` → `ParagraphNode` with
  ///   `blockType: header[1-3]Attribution`.
  MutableDocument markdownToDocument(String markdown) {
    final lines = markdown.split('\n');
    final nodes = <DocumentNode>[];
    final buffer = StringBuffer();

    void flushBuffer() {
      if (buffer.isEmpty) return;
      nodes.add(ParagraphNode(
        id: Editor.createNodeId(),
        text: AttributedText(buffer.toString().trimRight()),
      ));
      buffer.clear();
    }

    for (final line in lines) {
      if (line.trim().isEmpty) {
        flushBuffer();
        continue;
      }
      final heading = _matchHeading(line);
      if (heading != null) {
        flushBuffer();
        nodes.add(ParagraphNode(
          id: Editor.createNodeId(),
          text: AttributedText(heading.text),
          metadata: {'blockType': heading.attribution},
        ));
        continue;
      }
      if (buffer.isNotEmpty) buffer.write(' ');
      buffer.write(line);
    }
    flushBuffer();
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
  /// idempotent for supported node types.
  String documentToMarkdown(Document doc) {
    final out = StringBuffer();
    final nodes = doc.toList();
    final n = nodes.length;
    for (var i = 0; i < n; i++) {
      final node = nodes[i];
      if (node is ParagraphNode) {
        final prefix = _headingPrefix(node);
        if (prefix.isNotEmpty) out.write('$prefix ');
        out.write(node.text.toPlainText());
      }
      // Other node types unhandled until their respective slices add
      // explicit branches.
      if (i < n - 1) out.write('\n\n');
    }
    return out.toString();
  }

  /// If the paragraph's `blockType` metadata is a heading attribution,
  /// returns the corresponding `#` prefix string. Empty string otherwise.
  String _headingPrefix(ParagraphNode node) {
    final block = node.getMetadataValue('blockType');
    if (block == header1Attribution) return '#';
    if (block == header2Attribution) return '##';
    if (block == header3Attribution) return '###';
    return '';
  }

  /// Match an ATX-style heading `# text` / `## text` / `### text`.
  /// Returns null for non-headings. Levels 4-6 are paragraph-encoded
  /// (super_editor's default heading attribution only ships H1-H3).
  _HeadingMatch? _matchHeading(String line) {
    final m = RegExp(r'^(#{1,3})\s+(.+)$').firstMatch(line);
    if (m == null) return null;
    final hashes = m.group(1)!.length;
    final text = m.group(2)!.trim();
    final attribution = switch (hashes) {
      1 => header1Attribution,
      2 => header2Attribution,
      _ => header3Attribution,
    };
    return _HeadingMatch(text: text, attribution: attribution);
  }
}

class _HeadingMatch {
  const _HeadingMatch({required this.text, required this.attribution});
  final String text;
  final NamedAttribution attribution;
}
