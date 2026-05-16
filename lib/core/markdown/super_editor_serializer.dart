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
  /// - Slice 3: lists.
  ///   - `- foo` / `* foo` → `ListItemNode.unordered`.
  ///   - `<n>. foo` → `ListItemNode.ordered` (re-numbered on serialise).
  ///   - `- [ ] foo` / `- [x] foo` → `TaskNode(isComplete: …)`.
  /// - Slice 4: code blocks + horizontal rules.
  ///   - ` ```lang\nbody\n``` ` → `ParagraphNode` with `blockType:
  ///     codeAttribution` (language stored under metadata key `language`).
  ///   - `---` / `***` / `___` (≥3 of same char, line-only) →
  ///     `HorizontalRuleNode`.
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

    var i = 0;
    while (i < lines.length) {
      final line = lines[i];
      // Code fence open?
      final fenceOpen = RegExp(r'^```([\w-]*)$').firstMatch(line);
      if (fenceOpen != null) {
        flushBuffer();
        final lang = fenceOpen.group(1) ?? '';
        final body = StringBuffer();
        i += 1;
        while (i < lines.length && lines[i].trimRight() != '```') {
          if (body.isNotEmpty) body.write('\n');
          body.write(lines[i]);
          i += 1;
        }
        // Consume the closing fence (or end of input if unclosed).
        if (i < lines.length) i += 1;
        nodes.add(ParagraphNode(
          id: Editor.createNodeId(),
          text: AttributedText(body.toString()),
          metadata: {
            'blockType': codeAttribution,
            if (lang.isNotEmpty) 'language': lang,
          },
        ));
        continue;
      }
      // Horizontal rule? `---`, `***`, `___` (3+ of same char, no text).
      if (RegExp(r'^(\*{3,}|-{3,}|_{3,})\s*$').hasMatch(line)) {
        flushBuffer();
        nodes.add(HorizontalRuleNode(id: Editor.createNodeId()));
        i += 1;
        continue;
      }
      if (line.trim().isEmpty) {
        flushBuffer();
        i += 1;
        continue;
      }
      // Order matters: todo before unordered (todos start with `- [` which
      // would otherwise match the unordered prefix and lose the checkbox).
      final todo = _matchTodo(line);
      if (todo != null) {
        flushBuffer();
        nodes.add(TaskNode(
          id: Editor.createNodeId(),
          text: AttributedText(todo.text),
          isComplete: todo.isComplete,
        ));
        continue;
      }
      final unordered = _matchUnordered(line);
      if (unordered != null) {
        flushBuffer();
        nodes.add(ListItemNode.unordered(
          id: Editor.createNodeId(),
          text: AttributedText(unordered),
        ));
        continue;
      }
      final ordered = _matchOrdered(line);
      if (ordered != null) {
        flushBuffer();
        nodes.add(ListItemNode.ordered(
          id: Editor.createNodeId(),
          text: AttributedText(ordered),
        ));
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
      i += 1;
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
    var orderedCounter = 0;
    DocumentNode? prev;
    for (var i = 0; i < n; i++) {
      final node = nodes[i];
      // Re-number ordered list items as 1., 2., 3., resetting when the
      // run of consecutive ordered list items is broken.
      if (node is ListItemNode && node.type == ListItemType.ordered) {
        if (prev is! ListItemNode || prev.type != ListItemType.ordered) {
          orderedCounter = 0;
        }
        orderedCounter += 1;
      } else {
        orderedCounter = 0;
      }

      if (node is TaskNode) {
        out.write(node.isComplete ? '- [x] ' : '- [ ] ');
        out.write(node.text.toPlainText());
      } else if (node is ListItemNode) {
        if (node.type == ListItemType.unordered) {
          out.write('- ');
        } else {
          out.write('$orderedCounter. ');
        }
        out.write(node.text.toPlainText());
      } else if (node is HorizontalRuleNode) {
        out.write('---');
      } else if (node is ParagraphNode) {
        final block = node.getMetadataValue('blockType');
        if (block == codeAttribution) {
          final lang = node.getMetadataValue('language') as String? ?? '';
          out.write('```$lang\n');
          out.write(node.text.toPlainText());
          out.write('\n```');
        } else {
          final prefix = _headingPrefix(node);
          if (prefix.isNotEmpty) out.write('$prefix ');
          out.write(node.text.toPlainText());
        }
      }
      if (i < n - 1) {
        // Consecutive list items of the *same* kind share a single
        // newline; type boundaries (ordered ↔ unordered, list ↔ task)
        // get the standard blank-line separator so the reverse parse
        // re-emits two distinct list blocks.
        out.write(_separator(node, nodes[i + 1]));
      }
      prev = node;
    }
    return out.toString();
  }

  /// Return `\n` for two list-family items that share the same markdown
  /// marker (`- ` for unordered bullets *and* todos; `<n>. ` for ordered).
  /// Type boundaries — ordered ↔ unordered, list ↔ paragraph, list ↔
  /// heading — get the standard blank-line separator so the parse and
  /// serialise stay round-trip stable.
  String _separator(DocumentNode a, DocumentNode b) {
    bool isDashFamily(DocumentNode n) =>
        n is TaskNode ||
        (n is ListItemNode && n.type == ListItemType.unordered);
    bool isOrdered(DocumentNode n) =>
        n is ListItemNode && n.type == ListItemType.ordered;
    if (isDashFamily(a) && isDashFamily(b)) return '\n';
    if (isOrdered(a) && isOrdered(b)) return '\n';
    return '\n\n';
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

// Slice 3 list matchers — module-private extension functions on
// `SuperEditorSerializer` would have been nicer but Dart doesn't allow
// private extensions inside a class, so they're plain top-level matches
// reached via the methods on the class.
extension _ListMatchers on SuperEditorSerializer {
  /// Match `- [ ] body` / `- [x] body` (incomplete / complete todo).
  /// Returns null for non-todo lines.
  _TodoMatch? _matchTodo(String line) {
    final m = RegExp(r'^[-*]\s+\[( |x|X)\]\s+(.+)$').firstMatch(line);
    if (m == null) return null;
    return _TodoMatch(
      isComplete: m.group(1)!.toLowerCase() == 'x',
      text: m.group(2)!.trim(),
    );
  }

  /// Match an unordered bullet `- body` / `* body`. Returns the body text
  /// without the marker, or null for non-matches.
  String? _matchUnordered(String line) {
    final m = RegExp(r'^[-*]\s+(.+)$').firstMatch(line);
    return m?.group(1)?.trim();
  }

  /// Match an ordered bullet `<n>. body`. Returns the body without the
  /// number; the number itself is discarded (we re-emit 1., 2., 3. on
  /// serialise so reorderings stay consistent).
  String? _matchOrdered(String line) {
    final m = RegExp(r'^\d+\.\s+(.+)$').firstMatch(line);
    return m?.group(1)?.trim();
  }
}

class _TodoMatch {
  const _TodoMatch({required this.isComplete, required this.text});
  final bool isComplete;
  final String text;
}
