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
  /// - Slice 5: blockquotes + GFM admonition callouts.
  ///   - `> body` (one or more `>`-prefixed lines) → `ParagraphNode` with
  ///     `blockType: blockquoteAttribution`. Multi-line quotes merge into
  ///     a single paragraph at the blockquote level.
  ///   - `> [!NOTE]\n> body` (GFM admonition) → same blockquote node but
  ///     with metadata key `callout: note|tip|important|warning|caution`.
  /// - Slice 6: math blocks.
  ///   - `$$E=mc^2$$` (single-line) and multi-line `$$\n…\n$$` →
  ///     `ParagraphNode` with `blockType: mathBlockAttribution`. Body is
  ///     the LaTeX source without surrounding `$$`. Inline math `$…$` is
  ///     part of the inline-marks pass (slices 16-22).
  ///   - Mermaid diagrams (```` ```mermaid…``` ````) already round-trip
  ///     via slice 4's code-fence path: language tag `mermaid` is
  ///     preserved in `metadata.language`. No extra work in this slice.
  /// - Slice 7: GFM pipe tables.
  ///   - `| h1 | h2 |\n|---|---|\n| a | b |` → `ParagraphNode` with
  ///     `blockType: tableAttribution`. The raw multi-line markdown is
  ///     preserved in the body text so the renderer (existing
  ///     `markdown_renderer.dart` GFM-pipe-table path) gets the source
  ///     unmodified and round-trip stays byte-identical.
  /// - Slice 8: image cards.
  ///   - Standalone `![alt](url)` (the line is exactly that), URL has
  ///     image extension (jpg/jpeg/png/gif/webp/bmp/svg/heic) or no
  ///     extension → `ImageNode(imageUrl: url, altText: alt)`. Inline
  ///     images inside a paragraph stay as raw markdown.
  /// - Slice 9: file attachment cards.
  ///   - Standalone `![label](file.pdf)` (or `.mp4`, `.mp3`, `.zip`,
  ///     etc.) — non-image extensions → `ParagraphNode` with `blockType:
  ///     fileAttachmentAttribution` and `label` / `path` metadata.
  /// - Slice 10: bookmark cards.
  ///   - Standalone `https://example.com` → `ParagraphNode` with
  ///     `blockType: bookmarkAttribution`.
  /// - Slice 11: sub-page cards.
  ///   - Standalone `[[ULID]]` or `[[ULID#anchor]]` (line is exactly a
  ///     wikilink) → `ParagraphNode` with `blockType:
  ///     subPageAttribution`. Body text holds the raw `[[…]]` so the
  ///     existing `_SubpageCard` renderer keeps working.
  /// - Slice 12: transclusion cards.
  ///   - Standalone `![[ULID]]` (image-style transclusion) →
  ///     `ParagraphNode` with `blockType: transclusionAttribution`.
  /// - Slice 13: column fences.
  ///   - `:::cols / :::col / :::` (per M66) → `columnsAttribution`.
  /// - Slice 14: meta-blocks.
  ///   - `[breadcrumb]` or `[[breadcrumb]]` → `breadcrumbAttribution`.
  ///   - `[toc]` → `tocAttribution`.
  /// - Slice 15: button fences.
  ///   - `:::button\n…\n:::` (M70) → `buttonAttribution`.
  /// - Slice 16: inline marks — bold (`**X**`) and inline code (`` `X` ``).
  /// - Slice 17: inline marks — italic (`*X*`) and strikethrough (`~~X~~`).
  ///   Bold (`**`) is checked before italic (`*`) so the greedier match
  ///   wins. Strikethrough's `~~` opens and closes a strikethroughAttribution
  ///   span the same way.
  /// - Slice 18: inline marks — underline (`<u>X</u>`) per M80.
  /// - Slice 19: inline marks — highlight (`==X==` and `<mark>X</mark>`)
  ///   per M80 / M243.
  /// - Slice 20: inline marks — subscript `~X~` + superscript `^X^` per
  ///   M244 (Pandoc extensions).
  /// - Slice 21: inline color / background spans.
  /// - Slice 22: inline wikilink chips + date pills.
  ///   - Inline `[[ULID]]` or `[[ULID#anchor]]` (mid-paragraph) gets
  ///     `inlineWikilinkAttribution` on the matching character range.
  ///     The literal `[[…]]` text is kept verbatim — the attribution is
  ///     purely a styling hint for super_editor to render a chip.
  ///   - Inline `@YYYY-MM-DD` gets `inlineDateAttribution` per M83.
  ///   - Standalone `[[ULID]]` / `![[ULID]]` continue to upgrade to the
  ///     subPage / transclusion block attributions (slices 11+12).
  MutableDocument markdownToDocument(String markdown) {
    final lines = markdown.split('\n');
    final nodes = <DocumentNode>[];
    final buffer = StringBuffer();

    void flushBuffer() {
      if (buffer.isEmpty) return;
      nodes.add(ParagraphNode(
        id: Editor.createNodeId(),
        text: _parseInline(buffer.toString().trimRight()),
      ));
      buffer.clear();
    }

    var i = 0;
    while (i < lines.length) {
      final line = lines[i];
      // Math block — `$$body$$` (single-line) or `$$\n…\n$$` (multi-line).
      // Match single-line first to avoid the multi-line consumer eating a
      // closing `$$` on the same line as the open.
      final singleLineMath =
          RegExp(r'^\$\$(.+)\$\$\s*$').firstMatch(line);
      if (singleLineMath != null) {
        flushBuffer();
        nodes.add(ParagraphNode(
          id: Editor.createNodeId(),
          text: AttributedText(singleLineMath.group(1)!.trim()),
          metadata: const {'blockType': mathBlockAttribution},
        ));
        i += 1;
        continue;
      }
      if (line.trim() == r'$$') {
        flushBuffer();
        final body = StringBuffer();
        i += 1;
        while (i < lines.length && lines[i].trimRight() != r'$$') {
          if (body.isNotEmpty) body.write('\n');
          body.write(lines[i]);
          i += 1;
        }
        if (i < lines.length) i += 1; // consume closing $$
        nodes.add(ParagraphNode(
          id: Editor.createNodeId(),
          text: AttributedText(body.toString()),
          metadata: const {'blockType': mathBlockAttribution},
        ));
        continue;
      }
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
      // Meta-blocks: standalone `[breadcrumb]` / `[[breadcrumb]]` and
      // `[toc]` on their own line. Renders as a path/outline inline.
      final trimmed = line.trim();
      if (trimmed == '[breadcrumb]' || trimmed == '[[breadcrumb]]') {
        flushBuffer();
        nodes.add(ParagraphNode(
          id: Editor.createNodeId(),
          text: AttributedText(trimmed),
          metadata: const {'blockType': breadcrumbAttribution},
        ));
        i += 1;
        continue;
      }
      if (trimmed == '[toc]') {
        flushBuffer();
        nodes.add(ParagraphNode(
          id: Editor.createNodeId(),
          text: AttributedText(trimmed),
          metadata: const {'blockType': tocAttribution},
        ));
        i += 1;
        continue;
      }
      // Button fence? `:::button` opens a multi-line button definition;
      // a matching `:::` closes it.
      if (line.trimRight() == ':::button') {
        flushBuffer();
        final body = StringBuffer(line);
        i += 1;
        while (i < lines.length && lines[i].trimRight() != ':::') {
          body
            ..write('\n')
            ..write(lines[i]);
          i += 1;
        }
        if (i < lines.length) {
          body
            ..write('\n')
            ..write(lines[i]);
          i += 1;
        }
        nodes.add(ParagraphNode(
          id: Editor.createNodeId(),
          text: AttributedText(body.toString()),
          metadata: const {'blockType': buttonAttribution},
        ));
        continue;
      }
      // Column fence? `:::cols` opens a multi-column layout. Inner
      // `:::col` / `:::` boundaries are part of the body. We track
      // nesting so the outer-most closing `:::` ends the block.
      if (line.trimRight() == ':::cols') {
        flushBuffer();
        final body = StringBuffer(line);
        var depth = 1; // opened :::cols
        i += 1;
        while (i < lines.length && depth > 0) {
          final l = lines[i];
          body.write('\n');
          body.write(l);
          final t = l.trimRight();
          if (t == ':::cols' || t == ':::col') {
            depth += 1;
          } else if (t == ':::') {
            depth -= 1;
          }
          i += 1;
        }
        nodes.add(ParagraphNode(
          id: Editor.createNodeId(),
          text: AttributedText(body.toString()),
          metadata: const {'blockType': columnsAttribution},
        ));
        continue;
      }
      // Sub-page card? Standalone `[[ULID]]` or `[[ULID#anchor]]`.
      // ULID is 26 Crockford-base32 chars; the wikilink is exactly that
      // followed by optional `#anchor`. Inline wikilinks mid-paragraph
      // are an inline mark (later slice).
      if (RegExp(r'^\[\[([0-9A-HJKMNP-TV-Z]{26})(#[^\]]*)?\]\]$')
          .hasMatch(line.trim())) {
        flushBuffer();
        nodes.add(ParagraphNode(
          id: Editor.createNodeId(),
          text: AttributedText(line.trim()),
          metadata: const {'blockType': subPageAttribution},
        ));
        i += 1;
        continue;
      }
      // Transclusion card? Standalone `![[ULID]]`.
      if (RegExp(r'^!\[\[([0-9A-HJKMNP-TV-Z]{26})\]\]$')
          .hasMatch(line.trim())) {
        flushBuffer();
        nodes.add(ParagraphNode(
          id: Editor.createNodeId(),
          text: AttributedText(line.trim()),
          metadata: const {'blockType': transclusionAttribution},
        ));
        i += 1;
        continue;
      }
      // Bookmark card? Line is exactly an http(s) URL with no other
      // text. The existing M42 renderer picks this up; serializer keeps
      // a bookmarkAttribution paragraph so future slices can layer in
      // host/title metadata without changing the round-trip contract.
      if (RegExp(r'^https?://\S+$').hasMatch(line.trim())) {
        flushBuffer();
        nodes.add(ParagraphNode(
          id: Editor.createNodeId(),
          text: AttributedText(line.trim()),
          metadata: const {'blockType': bookmarkAttribution},
        ));
        i += 1;
        continue;
      }
      // Standalone media card? Line is exactly `![label](url)`. Branch
      // on extension: image vs file attachment.
      final mediaMatch = RegExp(r'^!\[(.*?)\]\((.+?)\)\s*$').firstMatch(line);
      if (mediaMatch != null) {
        flushBuffer();
        final label = mediaMatch.group(1) ?? '';
        final url = mediaMatch.group(2)!;
        if (_isImageUrl(url)) {
          nodes.add(ImageNode(
            id: Editor.createNodeId(),
            altText: label,
            imageUrl: url,
          ));
        } else {
          // File attachment — keep the raw markdown in body text so a
          // load + save without edits is byte-identical, and stash the
          // label + path in metadata for future cell-level editing.
          nodes.add(ParagraphNode(
            id: Editor.createNodeId(),
            text: AttributedText('![$label]($url)'),
            metadata: {
              'blockType': fileAttachmentAttribution,
              'label': label,
              'path': url,
            },
          ));
        }
        i += 1;
        continue;
      }
      // GFM pipe table? Detected by two-line signature: header row
      // starts with `|` and the next line is a separator like `|---|---|`
      // (optionally with alignment colons `|:---|---:|`).
      if (i + 1 < lines.length &&
          line.startsWith('|') &&
          _isTableSeparator(lines[i + 1])) {
        flushBuffer();
        final tableLines = <String>[line, lines[i + 1]];
        i += 2;
        while (i < lines.length && lines[i].startsWith('|')) {
          tableLines.add(lines[i]);
          i += 1;
        }
        nodes.add(ParagraphNode(
          id: Editor.createNodeId(),
          text: AttributedText(tableLines.join('\n')),
          metadata: const {'blockType': tableAttribution},
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
      // Blockquote / GFM callout? `> body` (possibly multi-line).
      if (RegExp(r'^>\s?').hasMatch(line)) {
        flushBuffer();
        final quoteLines = <String>[];
        String? callout;
        while (i < lines.length && RegExp(r'^>\s?').hasMatch(lines[i])) {
          final stripped = lines[i].replaceFirst(RegExp(r'^>\s?'), '');
          final adm = RegExp(r'^\[!(NOTE|TIP|IMPORTANT|WARNING|CAUTION)\]$')
              .firstMatch(stripped.trim());
          if (adm != null && quoteLines.isEmpty) {
            callout = adm.group(1)!.toLowerCase();
          } else {
            quoteLines.add(stripped);
          }
          i += 1;
        }
        nodes.add(ParagraphNode(
          id: Editor.createNodeId(),
          text: AttributedText(quoteLines.join('\n')),
          metadata: {
            'blockType': blockquoteAttribution,
            if (callout != null) 'callout': callout,
          },
        ));
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
          text: _parseInline(heading.text),
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
      } else if (node is ImageNode) {
        out.write('![${node.altText}](${node.imageUrl})');
      } else if (node is ParagraphNode) {
        final block = node.getMetadataValue('blockType');
        if (block == tableAttribution ||
            block == fileAttachmentAttribution ||
            block == bookmarkAttribution ||
            block == subPageAttribution ||
            block == transclusionAttribution ||
            block == columnsAttribution ||
            block == buttonAttribution ||
            block == breadcrumbAttribution ||
            block == tocAttribution) {
          // Body holds the raw markdown — emit verbatim.
          out.write(node.text.toPlainText());
        } else if (block == codeAttribution) {
          final lang = node.getMetadataValue('language') as String? ?? '';
          out.write('```$lang\n');
          out.write(node.text.toPlainText());
          out.write('\n```');
        } else if (block == mathBlockAttribution) {
          final body = node.text.toPlainText();
          if (body.contains('\n')) {
            out.write(r'$$' '\n');
            out.write(body);
            out.write('\n' r'$$');
          } else {
            out.write(r'$$');
            out.write(body);
            out.write(r'$$');
          }
        } else if (block == blockquoteAttribution) {
          final callout =
              node.getMetadataValue('callout') as String? ?? '';
          final body = _serializeInline(node.text);
          if (callout.isNotEmpty) {
            out.write('> [!${callout.toUpperCase()}]\n');
          }
          final bodyLines = body.split('\n');
          for (var j = 0; j < bodyLines.length; j++) {
            if (j > 0) out.write('\n');
            out.write('> ${bodyLines[j]}');
          }
        } else {
          final prefix = _headingPrefix(node);
          if (prefix.isNotEmpty) out.write('$prefix ');
          out.write(_serializeInline(node.text));
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

/// Scan [src] for inline markdown marks recognised so far and return an
/// `AttributedText` with the visible text (markers stripped) plus
/// attribution spans on the corresponding character ranges.
///
/// Recognised (cumulative across slices):
/// - `**X**` → boldAttribution (slice 16)
/// - `` `X` `` → codeAttribution (slice 16; inline code, distinct from
///   code-block blockType which uses the same NamedAttribution on metadata)
/// - `*X*` → italicsAttribution (slice 17)
/// - `~~X~~` → strikethroughAttribution (slice 17)
///
/// Order matters: bold (`**`) is checked before italic (`*`) so the
/// greedier match wins; strike (`~~`) is its own non-overlapping marker.
/// Inline code is matched whenever a backtick opens — backticked content
/// is literal and skips further mark scanning.
AttributedText _parseInline(String src) {
  final out = StringBuffer();
  final spans = <_InlineSpan>[];
  var i = 0;
  while (i < src.length) {
    // Bold `**X**` — greedier than italic, checked first.
    if (i + 1 < src.length && src[i] == '*' && src[i + 1] == '*') {
      final close = src.indexOf('**', i + 2);
      if (close > i + 1) {
        final inner = src.substring(i + 2, close);
        final start = out.length;
        out.write(inner);
        final end = out.length - 1;
        if (end >= start) {
          spans.add(_InlineSpan(boldAttribution, start, end));
        }
        i = close + 2;
        continue;
      }
    }
    // Highlight `==X==` (Pandoc/Obsidian) or `<mark>X</mark>` (HTML).
    if (i + 1 < src.length && src[i] == '=' && src[i + 1] == '=') {
      final close = src.indexOf('==', i + 2);
      if (close > i + 1) {
        final inner = src.substring(i + 2, close);
        final start = out.length;
        out.write(inner);
        final end = out.length - 1;
        if (end >= start) {
          spans.add(_InlineSpan(highlightAttribution, start, end));
        }
        i = close + 2;
        continue;
      }
    }
    if (i + 5 < src.length && src.substring(i, i + 6) == '<mark>') {
      final close = src.indexOf('</mark>', i + 6);
      if (close > i + 5) {
        final inner = src.substring(i + 6, close);
        final start = out.length;
        out.write(inner);
        final end = out.length - 1;
        if (end >= start) {
          spans.add(_InlineSpan(highlightAttribution, start, end));
        }
        i = close + 7;
        continue;
      }
    }
    // Underline `<u>X</u>` (M80 — raw HTML tag, Quill's canonical form).
    if (i + 2 < src.length && src.substring(i, i + 3) == '<u>') {
      final close = src.indexOf('</u>', i + 3);
      if (close > i + 2) {
        final inner = src.substring(i + 3, close);
        final start = out.length;
        out.write(inner);
        final end = out.length - 1;
        if (end >= start) {
          spans.add(_InlineSpan(underlineAttribution, start, end));
        }
        i = close + 4;
        continue;
      }
    }
    // Strikethrough `~~X~~`.
    if (i + 1 < src.length && src[i] == '~' && src[i + 1] == '~') {
      final close = src.indexOf('~~', i + 2);
      if (close > i + 1) {
        final inner = src.substring(i + 2, close);
        final start = out.length;
        out.write(inner);
        final end = out.length - 1;
        if (end >= start) {
          spans.add(_InlineSpan(strikethroughAttribution, start, end));
        }
        i = close + 2;
        continue;
      }
    }
    // Subscript `~X~` — single tilde, Pandoc-style. Must come after the
    // strikethrough `~~` check above. No internal whitespace.
    if (src[i] == '~') {
      final close = src.indexOf('~', i + 1);
      if (close > i &&
          close > i + 1 &&
          !RegExp(r'\s').hasMatch(src.substring(i + 1, close))) {
        final inner = src.substring(i + 1, close);
        final start = out.length;
        out.write(inner);
        final end = out.length - 1;
        if (end >= start) {
          spans.add(_InlineSpan(subscriptAttribution, start, end));
        }
        i = close + 1;
        continue;
      }
    }
    // Superscript `^X^` — single caret, Pandoc-style. No internal
    // whitespace.
    if (src[i] == '^') {
      final close = src.indexOf('^', i + 1);
      if (close > i &&
          close > i + 1 &&
          !RegExp(r'\s').hasMatch(src.substring(i + 1, close))) {
        final inner = src.substring(i + 1, close);
        final start = out.length;
        out.write(inner);
        final end = out.length - 1;
        if (end >= start) {
          spans.add(_InlineSpan(superscriptAttribution, start, end));
        }
        i = close + 1;
        continue;
      }
    }
    // Italic `*X*` — single asterisk, only after the bold check has
    // failed. Match shortest-distance close so `*a* *b*` parses as two
    // separate italic runs.
    if (src[i] == '*') {
      final close = src.indexOf('*', i + 1);
      if (close > i) {
        final inner = src.substring(i + 1, close);
        final start = out.length;
        out.write(inner);
        final end = out.length - 1;
        if (end >= start) {
          spans.add(_InlineSpan(italicsAttribution, start, end));
        }
        i = close + 1;
        continue;
      }
    }
    if (src[i] == '`') {
      final close = src.indexOf('`', i + 1);
      if (close > i) {
        final inner = src.substring(i + 1, close);
        final start = out.length;
        out.write(inner);
        final end = out.length - 1;
        if (end >= start) {
          spans.add(_InlineSpan(codeAttribution, start, end));
        }
        i = close + 1;
        continue;
      }
    }
    // Inline wikilink chip — `[[ULID]]` or `[[ULID#anchor]]`. Keep the
    // raw `[[…]]` text in the body; just attach an attribution span so
    // super_editor's WYSIWYG renders a chip while the markdown source
    // stays unchanged.
    final inlineWiki = RegExp(r'^\[\[([0-9A-HJKMNP-TV-Z]{26})(#[^\]]*)?\]\]')
        .matchAsPrefix(src, i);
    if (inlineWiki != null) {
      final whole = inlineWiki.group(0)!;
      final start = out.length;
      out.write(whole);
      final end = out.length - 1;
      spans.add(_InlineSpan(inlineWikilinkAttribution, start, end));
      i += whole.length;
      continue;
    }
    // Inline date pill — `@YYYY-MM-DD` per M83. Keep the literal text;
    // attach an attribution span for styled rendering.
    final inlineDate =
        RegExp(r'^@(\d{4})-(\d{2})-(\d{2})\b').matchAsPrefix(src, i);
    if (inlineDate != null) {
      final whole = inlineDate.group(0)!;
      final start = out.length;
      out.write(whole);
      final end = out.length - 1;
      spans.add(_InlineSpan(inlineDateAttribution, start, end));
      i += whole.length;
      continue;
    }
    out.write(src[i]);
    i += 1;
  }
  final text = AttributedText(out.toString());
  for (final s in spans) {
    text.addAttribution(s.attr, SpanRange(s.start, s.end));
  }
  return text;
}

/// Walk an `AttributedText` and emit markdown with the inline marks
/// added in slice 16 (bold + inline code) re-wrapped. Other attributions
/// land in later slices (italic / strike / underline / highlight / sub /
/// sup / color / wikilink chip / mention / date pill).
String _serializeInline(AttributedText text) {
  final plain = text.toPlainText();
  if (plain.isEmpty) return '';
  // Build a per-character flag set for each tracked attribution.
  final bold = List<bool>.filled(plain.length, false);
  final italic = List<bool>.filled(plain.length, false);
  final strike = List<bool>.filled(plain.length, false);
  final code = List<bool>.filled(plain.length, false);
  final under = List<bool>.filled(plain.length, false);
  final hi = List<bool>.filled(plain.length, false);
  final sub = List<bool>.filled(plain.length, false);
  final sup = List<bool>.filled(plain.length, false);
  for (var i = 0; i < plain.length; i++) {
    final attrs = text.getAllAttributionsAt(i);
    if (attrs.contains(boldAttribution)) bold[i] = true;
    if (attrs.contains(italicsAttribution)) italic[i] = true;
    if (attrs.contains(strikethroughAttribution)) strike[i] = true;
    if (attrs.contains(codeAttribution)) code[i] = true;
    if (attrs.contains(underlineAttribution)) under[i] = true;
    if (attrs.contains(highlightAttribution)) hi[i] = true;
    if (attrs.contains(subscriptAttribution)) sub[i] = true;
    if (attrs.contains(superscriptAttribution)) sup[i] = true;
  }
  final out = StringBuffer();
  for (var i = 0; i < plain.length; i++) {
    // Inline code beats all formatting marks — emit only backticks and
    // suppress the others.
    if (code[i] && (i == 0 || !code[i - 1])) out.write('`');
    if (!code[i]) {
      if (bold[i] && (i == 0 || !bold[i - 1])) out.write('**');
      if (italic[i] && (i == 0 || !italic[i - 1])) out.write('*');
      if (strike[i] && (i == 0 || !strike[i - 1])) out.write('~~');
      if (under[i] && (i == 0 || !under[i - 1])) out.write('<u>');
      if (hi[i] && (i == 0 || !hi[i - 1])) out.write('==');
      if (sub[i] && (i == 0 || !sub[i - 1])) out.write('~');
      if (sup[i] && (i == 0 || !sup[i - 1])) out.write('^');
    }
    out.write(plain[i]);
    final isLast = i == plain.length - 1;
    if (!code[i]) {
      if (sup[i] && (isLast || !sup[i + 1])) out.write('^');
      if (sub[i] && (isLast || !sub[i + 1])) out.write('~');
      if (hi[i] && (isLast || !hi[i + 1])) out.write('==');
      if (under[i] && (isLast || !under[i + 1])) out.write('</u>');
      if (strike[i] && (isLast || !strike[i + 1])) out.write('~~');
      if (italic[i] && (isLast || !italic[i + 1])) out.write('*');
      if (bold[i] && (isLast || !bold[i + 1])) out.write('**');
    }
    if (code[i] && (isLast || !code[i + 1])) out.write('`');
  }
  return out.toString();
}

class _InlineSpan {
  const _InlineSpan(this.attr, this.start, this.end);
  final Attribution attr;
  final int start;
  final int end;
}

/// Custom block-type attribution for math blocks (`$$ … $$`). super_editor
/// doesn't ship a math node, so we tag a `ParagraphNode` with this
/// attribution and the renderer (`markdown_renderer.dart`'s existing
/// `flutter_math_fork` path at M32) interprets it on read.
const mathBlockAttribution = NamedAttribution('mathBlock');

/// Custom block-type attribution for GFM pipe tables. The ParagraphNode's
/// `text` carries the entire raw table markdown (header + separator +
/// body rows), preserving column alignment markers byte-identical so the
/// renderer can parse it without ambiguity. Cell-level editing would need
/// a dedicated TableNode — left as v2 work.
const tableAttribution = NamedAttribution('table');

/// `|---|---|` separator (optionally with alignment colons `|:---|---:|`).
/// Used by the markdown parser to detect a GFM pipe table.
bool _isTableSeparator(String line) {
  if (!line.startsWith('|')) return false;
  final cells = line.split('|').where((s) => s.trim().isNotEmpty);
  if (cells.isEmpty) return false;
  return cells.every((c) => RegExp(r'^:?-+:?\s*$').hasMatch(c.trim()));
}

/// Custom block-type attribution for non-image `![label](path.ext)`
/// references (PDFs, video, audio, archives, etc.). super_editor's
/// `ImageNode` would try to load the URL as a bitmap — wrong tool for
/// a `.pdf` or `.mp4` path. The ParagraphNode's text holds the raw
/// markdown for round-trip; metadata fields `label` and `path` are
/// available for cell-level editing later.
const fileAttachmentAttribution = NamedAttribution('fileAttachment');

/// Custom block-type attribution for standalone http(s) URL lines, which
/// the existing markdown_renderer.dart M42 path renders as bookmark
/// cards (host + URL preview). The body text holds the URL verbatim.
const bookmarkAttribution = NamedAttribution('bookmark');

/// Custom block-type attribution for a standalone `[[ULID]]` or
/// `[[ULID#anchor]]` wikilink — Quill renders these as sub-page cards
/// with the linked page's title resolved at display time.
const subPageAttribution = NamedAttribution('subPage');

/// Custom block-type attribution for a standalone `![[ULID]]`
/// transclusion — the linked page's body is rendered inline (cycle-safe
/// up to maxDepth = 3 per CLAUDE.md).
const transclusionAttribution = NamedAttribution('transclusion');

/// Custom block-type attribution for a multi-column layout fenced with
/// `:::cols` / `:::col` / `:::` per M66. The body holds the raw
/// multi-line markdown so the existing layout renderer keeps working;
/// cell-level WYSIWYG editing of the columns themselves would need a
/// nested-document super_editor model (v2).
const columnsAttribution = NamedAttribution('columns');

/// Custom block-type attribution for a standalone `[breadcrumb]` or
/// `[[breadcrumb]]` line — M162 renders the page's vault-relative path
/// inline as mono crumbs.
const breadcrumbAttribution = NamedAttribution('breadcrumb');

/// Custom block-type attribution for a standalone `[toc]` line — M68
/// renders an outline of headings with clickable jump targets.
const tocAttribution = NamedAttribution('toc');

/// Custom block-type attribution for `:::button` fences (M70). Body
/// holds the raw multi-line button definition (url / copy / reveal /
/// page action keys); the existing button renderer parses on read.
const buttonAttribution = NamedAttribution('button');

/// Custom inline attribution for highlight runs (M80 `<mark>` /
/// M243 `==X==`). super_editor doesn't ship a highlight attribution by
/// default; we define one and the future styling pass maps it to a
/// soft-yellow background to match the existing rendered look.
const highlightAttribution = NamedAttribution('highlight');

// Sub / sup use super_editor's built-in `subscriptAttribution` and
// `superscriptAttribution` (ScriptAttribution variants). No locally
// declared duplicates — earlier slice's local consts were dropped at
// M1280 when the test surface caught the ambiguous-import collision.

/// Custom inline attribution for `[[ULID]]` / `[[ULID#anchor]]` wikilink
/// chips that appear mid-paragraph (the standalone form upgrades to a
/// sub-page block via `subPageAttribution`). The raw `[[…]]` text stays
/// in the body — the attribution is a styling hint so super_editor can
/// render a chip without touching the source.
const inlineWikilinkAttribution = NamedAttribution('inlineWikilink');

/// Custom inline attribution for `@YYYY-MM-DD` date pills per M83. The
/// literal `@2026-05-17` stays in the body text; the styling pass
/// renders the run as a pill.
const inlineDateAttribution = NamedAttribution('inlineDate');

/// Returns true when [url] has an extension this serializer treats as an
/// image — jpg / jpeg / png / gif / webp / bmp / svg / heic — OR has no
/// extension at all (case insensitive). Non-image extensions route to
/// `fileAttachmentAttribution`.
bool _isImageUrl(String url) {
  final m = RegExp(r'\.([a-zA-Z0-9]+)\s*$').firstMatch(url);
  if (m == null) return true; // no extension — treat as image
  final ext = m.group(1)!.toLowerCase();
  return const {
    'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'svg', 'heic',
  }.contains(ext);
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
