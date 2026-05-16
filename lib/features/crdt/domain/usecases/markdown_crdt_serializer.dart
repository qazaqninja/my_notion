import '../entities/quill_crdt_doc.dart';

/// H1 — round-trip surface between Quill's markdown bodies and the
/// CRDT representation. Today the implementation is trivial (the
/// CRDT stores raw markdown); the seam matters because the H2+
/// migration to `y_crdt` will replace `MarkdownCrdtSerializer` with
/// a Y.Text-walking impl while keeping callers unchanged.
class MarkdownCrdtSerializer {
  const MarkdownCrdtSerializer();

  /// Convert a markdown body to a CRDT doc.
  QuillCrdtDoc fromMarkdown(String markdown) =>
      QuillCrdtDoc.fromMarkdown(markdown);

  /// Convert a CRDT doc back to a markdown body. The contract is:
  /// `serializer.toMarkdown(serializer.fromMarkdown(s)) == s` for
  /// every input that doesn't go through `apply()` — every
  /// existing `frontmatter_parser_test`-shaped invariant survives.
  String toMarkdown(QuillCrdtDoc doc) => doc.toMarkdown();
}
