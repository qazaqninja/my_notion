import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/db/quill_database.dart' hide Page;
import '../../../../core/platform/reveal.dart';
import '../../../../shared/theme/quill_tokens.dart';
import '../../../../shared/theme/tokens.dart';
import '../../../../shared/widgets/relation_chip.dart';
import '../../../vault/presentation/bloc/vault_bloc.dart';
import '../../../vault/presentation/bloc/vault_state.dart';

/// Hand-rolled block-level markdown renderer. Matches the design's
/// `editor.jsx` Block component shape-for-shape: h1/h2/h3, paragraph
/// (with inline `[[ULID]]` chips), unordered list, fenced code block.
///
/// More elaborate markdown (tables, blockquotes, inline emphasis) is
/// deferred; the design didn't surface them and we can extend later
/// without breaking the contract.
class MarkdownRenderer extends StatelessWidget {
  const MarkdownRenderer({
    super.key,
    required this.body,
    this.showUlid = false,
    this.onBodyChange,
  });

  final String body;
  final bool showUlid;

  /// When supplied, paragraph + heading blocks become tap-to-edit:
  /// clicking swaps the rendered widget for an inline TextField; on
  /// commit, this callback receives the body with the block's source
  /// slice replaced.
  final ValueChanged<String>? onBodyChange;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    final blocks = _splitBlocks(body);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final b in blocks) _wrapBlock(context, tokens, b),
      ],
    );
  }

  Widget _wrapBlock(BuildContext context, QuillTokens tokens, _Block b) {
    var inner = _renderBlock(context, tokens, b);
    if (onBodyChange == null) return inner;

    // Tap-to-edit for simple text blocks.
    final editable = b.kind == _BlockKind.paragraph ||
        b.kind == _BlockKind.h1 ||
        b.kind == _BlockKind.h2 ||
        b.kind == _BlockKind.h3 ||
        b.kind == _BlockKind.quote;
    if (editable) {
      inner = _EditableBlock(
        key: ValueKey('blk-${b.sourceStart}-${b.sourceEnd}'),
        block: b,
        body: body,
        onBodyChange: onBodyChange!,
        child: inner,
      );
    }

    // Drag-to-reorder for ALL block kinds. The drag handle is rendered
    // by _BlockDragWrap on the left margin; the block content itself is
    // unchanged. DragTarget logic decides where the dragged block lands.
    if (b.kind == _BlockKind.hr) return inner; // hr is decorative-only.
    return _BlockDragWrap(
      block: b,
      body: body,
      onBodyChange: onBodyChange!,
      child: inner,
    );
  }

  Widget _renderBlock(BuildContext context, QuillTokens tokens, _Block b) {
    switch (b.kind) {
      case _BlockKind.h1:
        return Padding(
          padding: const EdgeInsets.fromLTRB(0, 32, 0, 12),
          child: Text(
            b.text,
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: tokens.text,
              letterSpacing: -0.5,
              height: 1.2,
            ),
          ),
        );
      case _BlockKind.h2:
        return Padding(
          padding: const EdgeInsets.fromLTRB(0, 28, 0, 8),
          child: Text(
            b.text,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w600,
              color: tokens.text,
              letterSpacing: -0.2,
              height: 1.3,
            ),
          ),
        );
      case _BlockKind.h3:
        return Padding(
          padding: const EdgeInsets.fromLTRB(0, 22, 0, 6),
          child: Text(
            b.text,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: tokens.text,
              height: 1.3,
            ),
          ),
        );
      case _BlockKind.paragraph:
        // Standalone image: ![alt](path) on its own line/paragraph.
        final image = _matchStandaloneImage(b.text);
        if (image != null) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: _MarkdownImage(alt: image.$1, src: image.$2),
          );
        }
        // Standalone transclusion: ![[ULID]] inlines the target body.
        final transcludeUlid = _matchStandaloneTransclusion(b.text);
        if (transcludeUlid != null) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: _TranscludedBlock(ulid: transcludeUlid),
          );
        }
        // Standalone wikilink: render as a sub-page card.
        final ulid = _matchStandaloneWikilink(b.text);
        if (ulid != null) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: _SubpageCard(ulid: ulid),
          );
        }
        // Standalone URL: render as a bookmark card.
        final url = _matchStandaloneUrl(b.text);
        if (url != null) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: _BookmarkCard(url: url),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _ParagraphWithChips(text: b.text, showUlid: showUlid, tokens: tokens),
        );
      case _BlockKind.ul:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final item in b.items!)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: _ListItem(
                    raw: item,
                    showUlid: showUlid,
                    tokens: tokens,
                  ),
                ),
            ],
          ),
        );
      case _BlockKind.ol:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int idx = 0; idx < b.items!.length; idx++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 22,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 1, left: 4),
                          child: Text(
                            '${idx + 1}.',
                            style: mono(fontSize: 14, color: tokens.text3),
                          ),
                        ),
                      ),
                      Expanded(
                        child: _ParagraphWithChips(
                          text: b.items![idx],
                          showUlid: showUlid,
                          tokens: tokens,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      case _BlockKind.quote:
        return _renderQuoteOrCallout(b.text, tokens, showUlid);
      case _BlockKind.hr:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Container(height: 0.5, color: tokens.divider2),
        );
      case _BlockKind.code:
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: tokens.isDark ? const Color(0xFF101010) : const Color(0xFFF0EDE6),
            border: Border.all(color: tokens.divider2, width: 0.5),
            borderRadius: const BorderRadius.all(Radius.circular(4)),
          ),
          child: SelectableText(
            b.text,
            style: mono(fontSize: 12.5, color: tokens.text2),
          ),
        );
      case _BlockKind.math:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: Math.tex(
              b.text,
              mathStyle: MathStyle.display,
              textStyle: TextStyle(fontSize: 16, color: tokens.text),
              onErrorFallback: (err) => Text(
                b.text,
                style: mono(fontSize: 12.5, color: tokens.text3),
              ),
            ),
          ),
        );
      case _BlockKind.columns:
        final raw = b.columns ?? const <String>[];
        if (raw.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int j = 0; j < raw.length; j++) ...[
                Expanded(
                  child: MarkdownRenderer(
                    body: raw[j],
                    showUlid: showUlid,
                    // Nested columns are read-only — editing them via
                    // tap-to-edit would need source-offset bookkeeping
                    // across the nested string boundary. Source-mode
                    // toggle is the escape hatch.
                  ),
                ),
                if (j != raw.length - 1) const SizedBox(width: 18),
              ],
            ],
          ),
        );
      case _BlockKind.button:
        return _ButtonBlock(
          props: b.props ?? const {},
          tokens: tokens,
        );
      case _BlockKind.toc:
        return _renderToc(context, tokens);
      case _BlockKind.toggle:
        return _ToggleBlock(
          rawText: b.text,
          showUlid: showUlid,
          tokens: tokens,
        );
      case _BlockKind.table:
        final rows = b.tableRows ?? const <List<String>>[];
        if (rows.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: tokens.divider2, width: 0.5),
                borderRadius: const BorderRadius.all(Radius.circular(4)),
              ),
              child: Table(
                defaultColumnWidth: const IntrinsicColumnWidth(),
                border: TableBorder.symmetric(
                  inside: BorderSide(color: tokens.divider, width: 0.5),
                ),
                children: [
                  for (int r = 0; r < rows.length; r++)
                    TableRow(
                      decoration: r == 0
                          ? BoxDecoration(color: tokens.surface2)
                          : null,
                      children: [
                        for (final cell in rows[r])
                          Padding(
                            padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                            child: _ParagraphWithChips(
                              text: cell,
                              showUlid: showUlid,
                              tokens: tokens,
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
    }
  }

  Widget _renderToc(BuildContext context, QuillTokens tokens) {
    final lines = body.split('\n');
    final totalLines = lines.length;
    final headings = <(int, String, int)>[]; // (level, text, lineIdx)
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.startsWith('### ')) {
        headings.add((3, line.substring(4), i));
      } else if (line.startsWith('## ')) {
        headings.add((2, line.substring(3), i));
      } else if (line.startsWith('# ')) {
        headings.add((1, line.substring(2), i));
      }
    }
    if (headings.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'Table of contents · (no headings yet — start a line with #)',
          style: TextStyle(fontSize: 12, color: tokens.text3),
        ),
      );
    }
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border.all(color: tokens.divider2, width: 0.5),
        borderRadius: const BorderRadius.all(Radius.circular(6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TABLE OF CONTENTS',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0,
                color: tokens.text3,
              )),
          const SizedBox(height: 6),
          for (final (lvl, t, idx) in headings)
            _TocLink(
              level: lvl,
              text: t,
              lineFraction: totalLines == 0 ? 0 : idx / totalLines,
            ),
        ],
      ),
    );
  }

  /// GFM-admonition style callouts: `> [!NOTE]\n> body` etc. The first
  /// line of [text] (already with `> ` stripped by the tokenizer) carries
  /// the marker `[!KIND]`. If present, render a coloured callout box;
  /// otherwise render a plain accent-bordered quote.
  Widget _renderQuoteOrCallout(String text, QuillTokens tokens, bool showUlid) {
    final lines = text.split('\n');
    final m = lines.isNotEmpty
        ? RegExp(r'^\[!(\w+)\]\s*(.*)$').firstMatch(lines.first)
        : null;
    if (m != null) {
      final kind = m.group(1)!.toLowerCase();
      final firstLine = m.group(2) ?? '';
      final rest = lines.skip(1).join('\n');
      final body = firstLine.isEmpty ? rest : '$firstLine\n$rest';
      final (icon, color) = _calloutStyle(kind, tokens);
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: tokens.isDark ? 0.12 : 0.08),
          border: Border(left: BorderSide(color: color, width: 3)),
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(4),
            bottomRight: Radius.circular(4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 6),
                Text(
                  kind.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _ParagraphWithChips(
              text: body.trim(),
              showUlid: showUlid,
              tokens: tokens,
            ),
          ],
        ),
      );
    }
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: tokens.accent, width: 3),
        ),
      ),
      child: _ParagraphWithChips(
        text: text,
        showUlid: showUlid,
        tokens: tokens,
      ),
    );
  }

  (IconData, Color) _calloutStyle(String kind, QuillTokens t) {
    switch (kind) {
      case 'note':
        return (Icons.info_outline, const Color(0xFF4A90D9));
      case 'tip':
        return (Icons.lightbulb_outline, const Color(0xFF55A06A));
      case 'important':
        return (Icons.priority_high_rounded, const Color(0xFF8E5CD0));
      case 'warning':
      case 'warn':
        return (Icons.warning_amber_outlined, const Color(0xFFD08F3D));
      case 'caution':
      case 'danger':
        return (Icons.error_outline, const Color(0xFFCB5A4F));
      default:
        return (Icons.bookmark_outline, t.accent);
    }
  }

  // ── Tokeniser ──────────────────────────────────────────────────────────

  static List<_Block> _splitBlocks(String body) {
    final lines = body.split('\n');
    // Compute the byte offset where each line starts. The last entry is
    // one-past-the-end so we can derive `end` for the last block.
    final lineOffsets = <int>[0];
    for (var k = 0; k < lines.length; k++) {
      lineOffsets.add(lineOffsets[k] + lines[k].length + 1); // +1 for `\n`
    }
    int offsetFor(int line) =>
        line < lineOffsets.length ? lineOffsets[line] : body.length;
    int endOf(int upToLine) {
      // upToLine is exclusive; range ends just before its starting offset.
      final v = offsetFor(upToLine);
      // Drop the trailing newline so the slice is the block's own text.
      return v > 0 && v <= body.length && upToLine > 0 ? v - 1 : v;
    }

    final out = <_Block>[];
    int i = 0;

    while (i < lines.length) {
      final start = offsetFor(i);
      final line = lines[i];

      // Multi-column container: `:::cols` opens; `:::col` (or `:::`)
      // separates columns; `:::` on its own line closes.
      if (line.trim() == ':::cols') {
        final cols = <StringBuffer>[StringBuffer()];
        i++;
        while (i < lines.length) {
          final t = lines[i].trim();
          if (t == ':::') {
            i++;
            break;
          }
          if (t == ':::col') {
            cols.add(StringBuffer());
            i++;
            continue;
          }
          if (cols.last.isNotEmpty) cols.last.write('\n');
          cols.last.write(lines[i]);
          i++;
        }
        out.add(_Block(
          kind: _BlockKind.columns,
          columns: cols.map((c) => c.toString()).toList(),
          sourceStart: start,
          sourceEnd: endOf(i),
        ));
        continue;
      }

      // Button block: `:::button` opens, `:::` closes. Body is YAML-ish
      // `key: value` lines — `label`, `action` (url|copy|reveal|page),
      // `value`. Anything else is ignored.
      if (line.trim() == ':::button') {
        final props = <String, String>{};
        i++;
        while (i < lines.length && lines[i].trim() != ':::') {
          final ln = lines[i];
          final idx = ln.indexOf(':');
          if (idx > 0) {
            final key = ln.substring(0, idx).trim();
            var val = ln.substring(idx + 1).trim();
            // Strip surrounding quotes for ergonomic typing.
            if (val.length >= 2 &&
                ((val.startsWith('"') && val.endsWith('"')) ||
                    (val.startsWith("'") && val.endsWith("'")))) {
              val = val.substring(1, val.length - 1);
            }
            if (key.isNotEmpty) props[key] = val;
          }
          i++;
        }
        if (i < lines.length) i++; // skip closing :::
        out.add(_Block(
          kind: _BlockKind.button,
          props: props,
          sourceStart: start,
          sourceEnd: endOf(i),
        ));
        continue;
      }

      // Table of contents: a line consisting only of `[toc]` or `[[toc]]`.
      if (line.trim().toLowerCase() == '[toc]' ||
          line.trim().toLowerCase() == '[[toc]]') {
        i++;
        out.add(_Block(
          kind: _BlockKind.toc,
          sourceStart: start,
          sourceEnd: endOf(i),
        ));
        continue;
      }

      // Toggle (collapsible) block — HTML <details>…</details>.
      if (line.trim().startsWith('<details>')) {
        var summary = '';
        // Look for inline summary on the same line.
        final inlineSummary = RegExp(r'<summary>(.*?)</summary>').firstMatch(line);
        if (inlineSummary != null) summary = inlineSummary.group(1) ?? '';
        final buf = StringBuffer();
        i++;
        while (i < lines.length && !lines[i].trim().contains('</details>')) {
          if (summary.isEmpty) {
            final m =
                RegExp(r'<summary>(.*?)</summary>').firstMatch(lines[i]);
            if (m != null) {
              summary = m.group(1) ?? '';
              i++;
              continue;
            }
          }
          if (buf.isNotEmpty) buf.write('\n');
          buf.write(lines[i]);
          i++;
        }
        if (i < lines.length) i++; // skip </details>
        out.add(_Block(
          kind: _BlockKind.toggle,
          text: '$summary\n${buf.toString()}',
          sourceStart: start,
          sourceEnd: endOf(i),
        ));
        continue;
      }

      // Code fence
      if (line.startsWith('```')) {
        final buf = StringBuffer();
        i++;
        while (i < lines.length && !lines[i].startsWith('```')) {
          if (buf.isNotEmpty) buf.write('\n');
          buf.write(lines[i]);
          i++;
        }
        if (i < lines.length) i++; // skip closing ```
        out.add(_Block(
          kind: _BlockKind.code,
          text: buf.toString(),
          sourceStart: start,
          sourceEnd: endOf(i),
        ));
        continue;
      }

      // GFM pipe table: a line with `|`, followed by a separator row
      // `| --- | --- |`. Greedy: collect all subsequent `|` lines.
      if (line.contains('|') &&
          i + 1 < lines.length &&
          RegExp(r'^\s*\|?[\s\-:|]+\|[\s\-:|]+\s*$').hasMatch(lines[i + 1])) {
        final rows = <List<String>>[_splitTableRow(line)];
        i += 2; // skip header + separator
        while (i < lines.length && lines[i].trim().contains('|')) {
          if (lines[i].trim().isEmpty) break;
          rows.add(_splitTableRow(lines[i]));
          i++;
        }
        out.add(_Block(
          kind: _BlockKind.table,
          tableRows: rows,
          sourceStart: start,
          sourceEnd: endOf(i),
        ));
        continue;
      }

      // Math fence  $$ ... $$
      if (line.startsWith(r'$$')) {
        // Inline same-line form: `$$ x = 1 $$`
        final stripped = line.substring(2);
        final closeIdx = stripped.lastIndexOf(r'$$');
        if (closeIdx >= 0) {
          i++;
          out.add(_Block(
            kind: _BlockKind.math,
            text: stripped.substring(0, closeIdx).trim(),
            sourceStart: start,
            sourceEnd: endOf(i),
          ));
          continue;
        }
        // Block form: collect until next `$$` line.
        final buf = StringBuffer();
        if (stripped.isNotEmpty) buf.write(stripped);
        i++;
        while (i < lines.length && !lines[i].trim().startsWith(r'$$')) {
          if (buf.isNotEmpty) buf.write('\n');
          buf.write(lines[i]);
          i++;
        }
        if (i < lines.length) i++;
        out.add(_Block(
          kind: _BlockKind.math,
          text: buf.toString().trim(),
          sourceStart: start,
          sourceEnd: endOf(i),
        ));
        continue;
      }

      // Heading
      if (line.startsWith('### ')) {
        i++;
        out.add(_Block(
          kind: _BlockKind.h3,
          text: line.substring(4),
          sourceStart: start,
          sourceEnd: endOf(i),
        ));
        continue;
      }
      if (line.startsWith('## ')) {
        i++;
        out.add(_Block(
          kind: _BlockKind.h2,
          text: line.substring(3),
          sourceStart: start,
          sourceEnd: endOf(i),
        ));
        continue;
      }
      if (line.startsWith('# ')) {
        i++;
        out.add(_Block(
          kind: _BlockKind.h1,
          text: line.substring(2),
          sourceStart: start,
          sourceEnd: endOf(i),
        ));
        continue;
      }

      // Blockquote (one or more contiguous `> ` lines)
      if (line.startsWith('> ') || line == '>') {
        final buf = StringBuffer();
        while (i < lines.length &&
            (lines[i].startsWith('> ') || lines[i] == '>')) {
          if (buf.isNotEmpty) buf.write('\n');
          buf.write(lines[i] == '>' ? '' : lines[i].substring(2));
          i++;
        }
        out.add(_Block(
          kind: _BlockKind.quote,
          text: buf.toString(),
          sourceStart: start,
          sourceEnd: endOf(i),
        ));
        continue;
      }

      // Horizontal rule
      if (line.trim() == '---' || line.trim() == '***' || line.trim() == '___') {
        i++;
        out.add(_Block(
          kind: _BlockKind.hr,
          sourceStart: start,
          sourceEnd: endOf(i),
        ));
        continue;
      }

      // Unordered list (with optional checkbox)
      if (line.startsWith('- ') || line.startsWith('* ')) {
        final items = <String>[];
        while (i < lines.length && (lines[i].startsWith('- ') || lines[i].startsWith('* '))) {
          items.add(lines[i].substring(2));
          i++;
        }
        out.add(_Block(
          kind: _BlockKind.ul,
          items: items,
          sourceStart: start,
          sourceEnd: endOf(i),
        ));
        continue;
      }

      // Ordered list (digits followed by `. `)
      if (RegExp(r'^\d+\.\s').hasMatch(line)) {
        final items = <String>[];
        while (i < lines.length && RegExp(r'^\d+\.\s').hasMatch(lines[i])) {
          items.add(lines[i].replaceFirst(RegExp(r'^\d+\.\s'), ''));
          i++;
        }
        out.add(_Block(
          kind: _BlockKind.ol,
          items: items,
          sourceStart: start,
          sourceEnd: endOf(i),
        ));
        continue;
      }

      // Blank line — skip, ends current paragraph block
      if (line.trim().isEmpty) {
        i++;
        continue;
      }

      // Otherwise paragraph (collect until blank line or block boundary)
      final buf = StringBuffer(line);
      i++;
      while (i < lines.length) {
        final n = lines[i];
        if (n.trim().isEmpty || _isBlockStart(n)) break;
        buf.write('\n');
        buf.write(n);
        i++;
      }
      out.add(_Block(
        kind: _BlockKind.paragraph,
        text: buf.toString(),
        sourceStart: start,
        sourceEnd: endOf(i),
      ));
    }

    return out;
  }

  static bool _isBlockStart(String line) =>
      line.startsWith('```') ||
      line.startsWith(r'$$') ||
      line.startsWith('# ') ||
      line.startsWith('## ') ||
      line.startsWith('### ') ||
      line.startsWith('- ') ||
      line.startsWith('* ') ||
      line.startsWith('> ') ||
      line == '>' ||
      line.trim() == '---' ||
      line.trim() == '***' ||
      line.trim() == '___' ||
      RegExp(r'^\d+\.\s').hasMatch(line) ||
      (line.contains('|') && line.trim().startsWith('|')) ||
      line.trim().toLowerCase() == '[toc]' ||
      line.trim().toLowerCase() == '[[toc]]' ||
      line.trim().startsWith('<details>') ||
      line.trim() == ':::cols' ||
      line.trim() == ':::button';
}

/// If [text] is JUST an image — `![alt](path)` with nothing else — return
/// (alt, path). Otherwise null. We render standalone images as Image widgets
/// rather than inline (which would need RichText with WidgetSpans).
(String, String)? _matchStandaloneImage(String text) {
  final trimmed = text.trim();
  final m = RegExp(r'^!\[([^\]]*)\]\(([^)]+)\)$').firstMatch(trimmed);
  if (m == null) return null;
  return (m.group(1) ?? '', m.group(2) ?? '');
}

/// If [text] is JUST a wikilink — `[[ULID]]` with nothing else — return
/// the ULID. Used to render sub-page cards.
String? _matchStandaloneWikilink(String text) {
  final trimmed = text.trim();
  final m = RegExp(r'^\[\[([0-9A-Z]{26})\]\]$').firstMatch(trimmed);
  return m?.group(1);
}

/// If [text] is JUST a transclusion — `![[ULID]]` with nothing else —
/// return the ULID. Renders the target page's body inline.
String? _matchStandaloneTransclusion(String text) {
  final trimmed = text.trim();
  final m = RegExp(r'^!\[\[([0-9A-Z]{26})\]\]$').firstMatch(trimmed);
  return m?.group(1);
}

/// Inline-rendered target page (frontmatter-stripped body) wrapped in
/// a labelled container. Cycle-safe: nests up to [maxDepth] before
/// degrading to a placeholder.
class _TranscludedBlock extends StatelessWidget {
  // The depth field exists so the recursive transclusion paths can
  // pass a higher value, but the call sites currently rely on the
  // body-rewriting strategy below rather than recursing the widget
  // itself. Keeping the parameter so future work can lift the rewrite
  // and recurse honestly.
  // ignore: unused_element_parameter
  const _TranscludedBlock({required this.ulid, this.depth = 0});
  final String ulid;
  final int depth;

  static const int maxDepth = 3;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    if (depth >= maxDepth) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: tokens.surface2,
          borderRadius: const BorderRadius.all(Radius.circular(4)),
        ),
        child: Text(
          'Transclusion depth limit reached (would loop).',
          style: TextStyle(fontSize: 11.5, color: tokens.text3),
        ),
      );
    }
    final db = context.read<QuillDatabase>();
    return FutureBuilder(
      future: (db.select(db.pages)..where((p) => p.ulid.equals(ulid)))
          .getSingleOrNull(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text('Loading transclusion…',
                style: TextStyle(fontSize: 11.5, color: tokens.text3)),
          );
        }
        final page = snap.data;
        if (page == null) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: tokens.surface2,
              borderRadius: const BorderRadius.all(Radius.circular(4)),
            ),
            child: Text('Page not found: $ulid',
                style: mono(fontSize: 11.5, color: tokens.text3)),
          );
        }
        return GestureDetector(
          onTap: () =>
              Navigator.of(context).pushReplacementNamed('/editor/$ulid'),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Container(
              decoration: BoxDecoration(
                color: tokens.surface,
                border: Border.all(color: tokens.divider2, width: 0.5),
                borderRadius: const BorderRadius.all(Radius.circular(6)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                    decoration: BoxDecoration(
                      color: tokens.surface2,
                      border: Border(
                          bottom: BorderSide(color: tokens.divider, width: 0.5)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.sync_alt, size: 12, color: tokens.text3),
                        const SizedBox(width: 6),
                        Text(
                          'Synced from ${page.title}',
                          style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: tokens.text2),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    child: MarkdownRenderer(
                      body: _bodyAtDepth(page.bodyText, depth + 1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Strip nested `![[ULID]]` from the body if we're already at max
  /// depth, so the FutureBuilder above doesn't keep recursing.
  static String _bodyAtDepth(String body, int nextDepth) {
    if (nextDepth < maxDepth) return body;
    return body.replaceAll(RegExp(r'!\[\[[0-9A-Z]{26}\]\]'),
        '⟪deeply nested transclusion⟫');
  }
}

/// If [text] is JUST a URL on its own line, return it. Used for
/// rendering bookmark cards.
String? _matchStandaloneUrl(String text) {
  final trimmed = text.trim();
  final m =
      RegExp(r'^(https?://[^\s\<\>\[\]\(\)]+)$').firstMatch(trimmed);
  return m?.group(1);
}

/// Bookmark card for a standalone URL.
class _BookmarkCard extends StatelessWidget {
  const _BookmarkCard({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    final host = Uri.tryParse(url)?.host ?? url;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border.all(color: tokens.divider2, width: 0.5),
        borderRadius: const BorderRadius.all(Radius.circular(6)),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tokens.surface2,
              borderRadius: const BorderRadius.all(Radius.circular(4)),
            ),
            child: Icon(Icons.link, size: 14, color: tokens.text3),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  host,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: tokens.text,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  url,
                  style: mono(fontSize: 11, color: tokens.text3),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(2),
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            onPressed: () => _openExternal(url),
            icon: Icon(Icons.open_in_new, size: 14, color: tokens.text3),
            tooltip: 'Open in browser',
          ),
        ],
      ),
    );
  }

  static Future<void> _openExternal(String url) async {
    // Use the cross-platform shell-out path (Reveal.show works for files;
    // for URLs we go via `open` / `xdg-open` / `start` directly).
    try {
      if (Platform.isMacOS) {
        await Process.run('open', [url]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [url]);
      } else if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', url]);
      }
    } catch (_) {}
  }
}

/// Sub-page card. Looks up the page's title and icon from drift and
/// renders a clickable Notion-style row with icon + title + path.
class _SubpageCard extends StatelessWidget {
  const _SubpageCard({required this.ulid});
  final String ulid;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    final db = context.read<QuillDatabase>();
    return FutureBuilder(
      future: (db.select(db.pages)..where((p) => p.ulid.equals(ulid)))
          .getSingleOrNull(),
      builder: (context, snap) {
        final page = snap.data;
        final title = page?.title ?? 'Untitled (${ulid.substring(20)})';
        final path = page?.relativePath ?? '';
        return GestureDetector(
          onTap: () => Navigator.of(context).pushReplacementNamed('/editor/$ulid'),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: tokens.surface,
                border: Border.all(color: tokens.divider2, width: 0.5),
                borderRadius: const BorderRadius.all(Radius.circular(6)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: tokens.surface2,
                      borderRadius: const BorderRadius.all(Radius.circular(4)),
                    ),
                    child: Icon(Icons.description_outlined,
                        size: 14, color: tokens.text3),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: tokens.text,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (path.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: Text(
                              path,
                              style: mono(fontSize: 11, color: tokens.text3),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 16, color: tokens.text3),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MarkdownImage extends StatelessWidget {
  const _MarkdownImage({required this.alt, required this.src});
  final String alt;
  final String src;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    final vault = context.read<VaultBloc>().state;
    final vaultRoot = vault is VaultLoaded ? vault.rootPath : null;
    final image = _buildImage(src, vaultRoot);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(4)),
          child: image,
        ),
        if (alt.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              alt,
              style: TextStyle(fontSize: 11.5, color: tokens.text3),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }

  Widget _buildImage(String src, String? vaultRoot) {
    if (src.startsWith('http://') || src.startsWith('https://')) {
      return Image.network(src,
          errorBuilder: (_, __, ___) => const _BrokenImageBox());
    }
    if (src.startsWith('/')) {
      return Image.file(File(src),
          errorBuilder: (_, __, ___) => const _BrokenImageBox());
    }
    if (vaultRoot == null) return const _BrokenImageBox();
    return Image.file(File('$vaultRoot/$src'),
        errorBuilder: (_, __, ___) => const _BrokenImageBox());
  }
}

class _BrokenImageBox extends StatelessWidget {
  const _BrokenImageBox();
  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    return Container(
      width: 240,
      height: 120,
      decoration: BoxDecoration(
        color: tokens.surface2,
        border: Border.all(color: tokens.divider2, width: 0.5),
      ),
      child: Center(
        child: Text('image not found',
            style: TextStyle(fontSize: 11.5, color: tokens.text3)),
      ),
    );
  }
}

class _Block {
  const _Block({
    required this.kind,
    this.text = '',
    this.items,
    this.tableRows,
    this.columns,
    this.props,
    this.sourceStart = 0,
    this.sourceEnd = 0,
  });
  final _BlockKind kind;
  final String text;
  final List<String>? items;
  final List<List<String>>? tableRows;

  /// For [_BlockKind.columns]: one raw markdown string per column.
  /// Rendered by nested MarkdownRenderers.
  final List<String>? columns;

  /// For [_BlockKind.button]: `key: value` pairs from inside the
  /// `:::button` fence. Known keys: label, action, value.
  final Map<String, String>? props;

  /// `[sourceStart, sourceEnd)` is the half-open range in the full body
  /// that produced this block. Used for tap-to-edit splicing.
  final int sourceStart;
  final int sourceEnd;

  _Block withRange(int start, int end) => _Block(
        kind: kind,
        text: text,
        items: items,
        tableRows: tableRows,
        sourceStart: start,
        sourceEnd: end,
      );
}

enum _BlockKind {
  h1,
  h2,
  h3,
  paragraph,
  ul,
  ol,
  code,
  math,
  quote,
  hr,
  table,
  toc,
  toggle,
  columns,
  button,
}

List<String> _splitTableRow(String line) {
  var s = line.trim();
  if (s.startsWith('|')) s = s.substring(1);
  if (s.endsWith('|')) s = s.substring(0, s.length - 1);
  return s.split('|').map((c) => c.trim()).toList();
}

/// Render a paragraph with inline emphasis (bold/italic/strike/code),
/// `[[ULID]]` chips, and inline image references. Uses `RichText` with
/// `WidgetSpan`s for the non-text bits.
class _ParagraphWithChips extends StatelessWidget {
  const _ParagraphWithChips({required this.text, required this.showUlid, required this.tokens});

  final String text;
  final bool showUlid;
  final QuillTokens tokens;

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(fontSize: 16, color: tokens.text, height: 1.6);
    final spans = _buildSpans(text, base, tokens, showUlid);
    return SelectableText.rich(
      TextSpan(style: base, children: spans),
    );
  }
}

class _ListItem extends StatelessWidget {
  const _ListItem({
    required this.raw,
    required this.showUlid,
    required this.tokens,
  });
  final String raw;
  final bool showUlid;
  final QuillTokens tokens;

  @override
  Widget build(BuildContext context) {
    // Tappable checkbox if `[ ]` / `[x]` prefix.
    final m = RegExp(r'^\[([ xX])\]\s+').firstMatch(raw);
    if (m != null) {
      final checked = m.group(1)!.toLowerCase() == 'x';
      final rest = raw.substring(m.end);
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5, right: 10, left: 4),
            child: Icon(
              checked
                  ? Icons.check_box_outlined
                  : Icons.check_box_outline_blank,
              size: 16,
              color: checked ? tokens.accent : tokens.text3,
            ),
          ),
          Expanded(
            child: DefaultTextStyle.merge(
              style: TextStyle(
                decoration:
                    checked ? TextDecoration.lineThrough : TextDecoration.none,
                color: checked ? tokens.text3 : tokens.text,
              ),
              child: _ParagraphWithChips(
                text: rest,
                showUlid: showUlid,
                tokens: tokens,
              ),
            ),
          ),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 9, right: 10, left: 4),
          child: Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: tokens.text2,
              shape: BoxShape.circle,
            ),
          ),
        ),
        Expanded(
          child:
              _ParagraphWithChips(text: raw, showUlid: showUlid, tokens: tokens),
        ),
      ],
    );
  }
}

/// Tappable TOC row. Scrolls the enclosing Scrollable to a fractional
/// position derived from the heading's line index. The result is
/// approximate (rows have variable heights — code blocks are taller
/// than paragraphs) but lands the user near the heading; the renderer
/// is too dynamic for pixel-precise anchors without GlobalKey
/// plumbing across nested renderers.
class _TocLink extends StatelessWidget {
  const _TocLink({
    required this.level,
    required this.text,
    required this.lineFraction,
  });
  final int level;
  final String text;
  final double lineFraction;

  void _jump(BuildContext context) {
    final scrollable = Scrollable.maybeOf(context);
    if (scrollable == null) return;
    final pos = scrollable.position;
    final target = (pos.maxScrollExtent * lineFraction).clamp(
      pos.minScrollExtent,
      pos.maxScrollExtent,
    );
    pos.animateTo(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    return GestureDetector(
      onTap: () => _jump(context),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Padding(
          padding: EdgeInsets.only(left: (level - 1) * 14.0, top: 3, bottom: 1),
          child: Text(
            text,
            style: TextStyle(
              fontSize: level == 1 ? 14 : (level == 2 ? 13 : 12.5),
              fontWeight: level == 1 ? FontWeight.w600 : FontWeight.w500,
              color: tokens.text2,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }
}

/// Button block — `:::button` fence. Renders a clickable pill that
/// performs one of: url / copy / reveal / page-link. Authored as
///
/// :::button
/// label: Visit homepage
/// action: url
/// value: https://example.com
/// :::
///
/// Stays a plain markdown container fence, so Obsidian / GitHub
/// render the YAML lines verbatim (gracefully) and we keep the
/// byte-identical round-trip.
class _ButtonBlock extends StatefulWidget {
  const _ButtonBlock({required this.props, required this.tokens});

  final Map<String, String> props;
  final QuillTokens tokens;

  @override
  State<_ButtonBlock> createState() => _ButtonBlockState();
}

class _ButtonBlockState extends State<_ButtonBlock> {
  String? _flash;

  Future<void> _run(BuildContext context) async {
    final action = (widget.props['action'] ?? 'url').toLowerCase();
    final value = widget.props['value'] ?? '';
    switch (action) {
      case 'url':
        await Reveal.openUrl(value);
        _toast('Opened $value');
        break;
      case 'copy':
        await Clipboard.setData(ClipboardData(text: value));
        _toast('Copied');
        break;
      case 'reveal':
        final vault = context.read<VaultBloc>().state;
        final root = vault is VaultLoaded ? vault.rootPath : null;
        final path = value.startsWith('/') || root == null
            ? value
            : '$root/$value';
        await Reveal.show(path);
        _toast('Revealed');
        break;
      case 'page':
        if (value.isNotEmpty) {
          if (!context.mounted) return;
          context.go('/editor/$value');
        }
        break;
      default:
        _toast('Unknown action: $action');
    }
  }

  void _toast(String msg) {
    setState(() => _flash = msg);
    Future.delayed(const Duration(milliseconds: 1100), () {
      if (mounted) setState(() => _flash = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    final label = widget.props['label']?.trim().isNotEmpty == true
        ? widget.props['label']!
        : 'Button';
    final action = (widget.props['action'] ?? 'url').toLowerCase();
    final icon = switch (action) {
      'copy' => Icons.copy,
      'reveal' => Icons.folder_open,
      'page' => Icons.link,
      _ => Icons.open_in_new,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => _run(context),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _flash != null ? tokens.surface2 : tokens.accent,
                borderRadius: const BorderRadius.all(Radius.circular(6)),
                border: Border.all(
                  color: _flash != null ? tokens.divider2 : tokens.accent,
                  width: 0.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon,
                      size: 14,
                      color:
                          _flash != null ? tokens.text2 : Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    _flash ?? label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: _flash != null ? tokens.text2 : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Wraps a rendered block with a hover-revealed drag handle (left
/// margin) and a DragTarget that, on accept, splices the dragged
/// block's source slice in front of this one. Reordering uses the
/// existing `(sourceStart, sourceEnd)` ranges from M40; the produced
/// new body is dispatched via [onBodyChange].
class _BlockDragWrap extends StatefulWidget {
  const _BlockDragWrap({
    required this.block,
    required this.body,
    required this.onBodyChange,
    required this.child,
  });

  final _Block block;
  final String body;
  final ValueChanged<String> onBodyChange;
  final Widget child;

  @override
  State<_BlockDragWrap> createState() => _BlockDragWrapState();
}

class _BlockDragWrapState extends State<_BlockDragWrap> {
  bool _hover = false;

  /// Move the source slice `[dragStart..dragEnd)` (plus its trailing
  /// newline, if any) so it lands immediately before `targetStart`.
  /// Returns the new body string. No-op when dragging onto itself.
  static String _move(
      String body, int dragStart, int dragEnd, int targetStart) {
    if (dragStart == targetStart) return body;
    // Include the trailing newline of the dragged block so consecutive
    // blocks stay separated by exactly one \n.
    final dragEndIncl =
        (dragEnd < body.length && body[dragEnd] == '\n') ? dragEnd + 1 : dragEnd;
    final piece = body.substring(dragStart, dragEndIncl);
    final withoutPiece =
        body.substring(0, dragStart) + body.substring(dragEndIncl);
    final adjusted = targetStart > dragStart
        ? targetStart - piece.length
        : targetStart;
    return withoutPiece.substring(0, adjusted) +
        piece +
        withoutPiece.substring(adjusted);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    return DragTarget<List<int>>(
      onWillAcceptWithDetails: (d) =>
          d.data[0] != widget.block.sourceStart, // not self
      onAcceptWithDetails: (d) {
        final next = _move(
          widget.body,
          d.data[0], // dragStart
          d.data[1], // dragEnd
          widget.block.sourceStart,
        );
        widget.onBodyChange(next);
      },
      builder: (context, candidate, _) {
        final hovering = candidate.isNotEmpty;
        return MouseRegion(
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (hovering)
                Container(
                  height: 2,
                  color: tokens.accent,
                  margin: const EdgeInsets.symmetric(vertical: 1),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 18,
                    child: _hover
                        ? LongPressDraggable<List<int>>(
                            data: [
                              widget.block.sourceStart,
                              widget.block.sourceEnd,
                            ],
                            delay: const Duration(milliseconds: 150),
                            feedback: Material(
                              color: Colors.transparent,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: tokens.surface,
                                  border: Border.all(
                                      color: tokens.divider2, width: 0.5),
                                  borderRadius: const BorderRadius.all(
                                      Radius.circular(4)),
                                ),
                                child: Text(
                                  _blockKindLabel(widget.block.kind),
                                  style: TextStyle(
                                      fontSize: 12, color: tokens.text2),
                                ),
                              ),
                            ),
                            child: MouseRegion(
                              cursor: SystemMouseCursors.grab,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Icon(Icons.drag_indicator,
                                    size: 14, color: tokens.text3),
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  Expanded(child: widget.child),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

String _blockKindLabel(_BlockKind k) => switch (k) {
      _BlockKind.h1 => 'Heading 1',
      _BlockKind.h2 => 'Heading 2',
      _BlockKind.h3 => 'Heading 3',
      _BlockKind.paragraph => 'Paragraph',
      _BlockKind.ul => 'List',
      _BlockKind.ol => 'Numbered list',
      _BlockKind.code => 'Code',
      _BlockKind.math => 'Math',
      _BlockKind.quote => 'Quote',
      _BlockKind.table => 'Table',
      _BlockKind.toc => 'Contents',
      _BlockKind.toggle => 'Toggle',
      _BlockKind.columns => 'Columns',
      _BlockKind.button => 'Button',
      _BlockKind.hr => 'Divider',
    };

/// Toggle / collapsible block. First line of [rawText] is the summary,
/// the rest is the body (rendered via nested MarkdownRenderer-light —
/// uses _ParagraphWithChips for inline emphasis & wikilinks).
class _ToggleBlock extends StatefulWidget {
  const _ToggleBlock({
    required this.rawText,
    required this.showUlid,
    required this.tokens,
  });
  final String rawText;
  final bool showUlid;
  final QuillTokens tokens;

  @override
  State<_ToggleBlock> createState() => _ToggleBlockState();
}

class _ToggleBlockState extends State<_ToggleBlock> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final parts = widget.rawText.split('\n');
    final summary = parts.isNotEmpty ? parts.first : '';
    final body = parts.length > 1 ? parts.sublist(1).join('\n').trim() : '';
    final tokens = widget.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _open = !_open),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 6, top: 2),
                    child: Transform.rotate(
                      angle: _open ? 1.5708 : 0,
                      child: Icon(Icons.chevron_right,
                          size: 16, color: tokens.text3),
                    ),
                  ),
                  Expanded(
                    child: _ParagraphWithChips(
                      text: summary.isEmpty ? 'Toggle' : summary,
                      showUlid: widget.showUlid,
                      tokens: tokens,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_open && body.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 4, 0, 4),
              child: _ParagraphWithChips(
                text: body,
                showUlid: widget.showUlid,
                tokens: tokens,
              ),
            ),
        ],
      ),
    );
  }
}

/// Wraps a rendered block widget. Tapping it swaps the display for an
/// inline TextField pre-filled with the block's source slice. On commit
/// (Enter, blur, or tap-outside), the new source is spliced into the
/// full body and the parent's onBodyChange callback fires.
///
/// Limited to single-line block kinds in this MVP (paragraph + h1/h2/h3 +
/// quote). Lists, tables, code, math, and HR are not editable in place.
class _EditableBlock extends StatefulWidget {
  const _EditableBlock({
    super.key,
    required this.block,
    required this.body,
    required this.onBodyChange,
    required this.child,
  });

  final _Block block;
  final String body;
  final ValueChanged<String> onBodyChange;
  final Widget child;

  @override
  State<_EditableBlock> createState() => _EditableBlockState();
}

class _EditableBlockState extends State<_EditableBlock> {
  bool _editing = false;
  late TextEditingController _ctl;
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _ctl = TextEditingController(text: _slice);
  }

  @override
  void didUpdateWidget(_EditableBlock old) {
    super.didUpdateWidget(old);
    if (!_editing && _slice != _ctl.text) {
      _ctl.text = _slice;
    }
  }

  @override
  void dispose() {
    _ctl.dispose();
    _focus.dispose();
    super.dispose();
  }

  String get _slice =>
      widget.body.substring(widget.block.sourceStart, widget.block.sourceEnd);

  void _start() {
    if (_editing) return;
    setState(() => _editing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focus.requestFocus();
      _ctl.selection =
          TextSelection(baseOffset: 0, extentOffset: _ctl.text.length);
    });
  }

  void _commit() {
    final next = _ctl.text;
    setState(() => _editing = false);
    if (next == _slice) return;
    final body = widget.body;
    final patched = body.replaceRange(
      widget.block.sourceStart,
      widget.block.sourceEnd,
      next,
    );
    widget.onBodyChange(patched);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    if (!_editing) {
      return GestureDetector(
        onTap: _start,
        behavior: HitTestBehavior.opaque,
        child: MouseRegion(
          cursor: SystemMouseCursors.text,
          child: widget.child,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: _ctl,
        focusNode: _focus,
        maxLines: null,
        onSubmitted: (_) => _commit(),
        onTapOutside: (_) {
          if (_editing) _commit();
        },
        style: mono(fontSize: 13.5, color: tokens.text).copyWith(height: 1.55),
        decoration: InputDecoration(
          isCollapsed: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 6),
          border: InputBorder.none,
          hintText: 'edit · enter / click out to commit',
          hintStyle: TextStyle(color: tokens.text3, fontSize: 12.5),
        ),
      ),
    );
  }
}

/// Parse a CSS-ish style string into a Flutter TextStyle. Supports
/// `color:` and `background-color:` with named colors + hex.
TextStyle _parseInlineStyle(String css) {
  Color? fg;
  Color? bg;
  for (final part in css.split(';')) {
    final colon = part.indexOf(':');
    if (colon < 0) continue;
    final key = part.substring(0, colon).trim().toLowerCase();
    final value = part.substring(colon + 1).trim();
    final color = _parseCssColor(value);
    if (key == 'color') {
      fg = color;
    } else if (key == 'background-color' || key == 'background') {
      bg = color;
    }
  }
  return TextStyle(color: fg, backgroundColor: bg);
}

Color? _parseCssColor(String value) {
  final v = value.toLowerCase();
  // Hex like #RGB / #RRGGBB / #AARRGGBB.
  if (v.startsWith('#')) {
    var hex = v.substring(1);
    if (hex.length == 3) {
      hex = hex.split('').map((c) => '$c$c').join();
    }
    if (hex.length == 6) hex = 'FF$hex';
    if (hex.length == 8) {
      final n = int.tryParse(hex, radix: 16);
      if (n != null) return Color(n);
    }
    return null;
  }
  // Named colors — a small set Notion / GitHub actually emit.
  const named = <String, int>{
    'red': 0xFFCB5A4F,
    'orange': 0xFFD08F3D,
    'yellow': 0xFFD4B85F,
    'green': 0xFF55A06A,
    'blue': 0xFF4A90D9,
    'purple': 0xFF8E5CD0,
    'pink': 0xFFD06D9C,
    'gray': 0xFF7A7468,
    'grey': 0xFF7A7468,
    'brown': 0xFF6F5B41,
    'black': 0xFF000000,
    'white': 0xFFFFFFFF,
  };
  final c = named[v];
  return c == null ? null : Color(c);
}

/// Inline tokenizer: produces TextSpan/WidgetSpan list for a paragraph.
/// Handles `**bold**`, `*italic*` / `_italic_`, `~~strike~~`, `` `code` ``,
/// and `[[ULID]]` wikilink chips. Unmatched delimiters are emitted as plain
/// text so we don't accidentally swallow `2 * 3`.
List<InlineSpan> _buildSpans(
  String text,
  TextStyle base,
  QuillTokens tokens,
  bool showUlid,
) {
  final out = <InlineSpan>[];
  var committed = 0; // last position written to `out`
  var i = 0;
  final n = text.length;

  void flushPlain(int upto) {
    if (upto > committed) {
      out.add(TextSpan(text: text.substring(committed, upto)));
    }
    committed = upto;
  }

  while (i < n) {
    // Wikilink chip — [[ULID]]
    if (text[i] == '[' && i + 1 < n && text[i + 1] == '[') {
      final m = RegExp(r'\[\[([0-9A-HJKMNP-TV-Z]{26})\]\]')
          .matchAsPrefix(text, i);
      if (m != null) {
        flushPlain(i);
        out.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: _ResolvedChip(ulid: m.group(1)!, showUlid: showUlid),
        ));
        i = m.end;
        committed = i;
        continue;
      }
    }
    final c = text[i];
    // Inline code: `text`
    // Inline <span style="color:X;background-color:Y">...</span>
    if (c == '<' && text.startsWith('<span', i)) {
      final m = RegExp(
              r'<span\s+style="([^"]*)">([^<]*)<\/span>')
          .matchAsPrefix(text, i);
      if (m != null) {
        flushPlain(i);
        final style = _parseInlineStyle(m.group(1) ?? '');
        out.add(TextSpan(
          text: m.group(2),
          style: style,
        ));
        i = m.end;
        committed = i;
        continue;
      }
    }

    // Inline @YYYY-MM-DD date mention.
    if (c == '@') {
      final prev = i == 0 ? '' : text[i - 1];
      final boundary = prev.isEmpty ||
          prev == ' ' ||
          prev == '\n' ||
          prev == '\t' ||
          prev == '(' ||
          prev == '[';
      if (boundary) {
        final m = RegExp(r'^@(\d{4}-\d{2}-\d{2})(?![0-9\-])')
            .matchAsPrefix(text, i);
        if (m != null) {
          flushPlain(i);
          final dateStr = m.group(1)!;
          out.add(WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: tokens.surface2,
                borderRadius: const BorderRadius.all(Radius.circular(3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today_outlined,
                      size: 11, color: tokens.text3),
                  const SizedBox(width: 4),
                  Text(dateStr,
                      style: mono(fontSize: 11.5, color: tokens.text2)),
                ],
              ),
            ),
          ));
          i = m.end;
          committed = i;
          continue;
        }
      }
    }

    // Inline URL: http(s)://… up to a whitespace or closing bracket.
    if (c == 'h' &&
        (text.startsWith('http://', i) || text.startsWith('https://', i))) {
      final m = RegExp(r'https?://[^\s\<\>\[\]\(\)]+').matchAsPrefix(text, i);
      if (m != null) {
        flushPlain(i);
        final url = m.group(0)!;
        out.add(TextSpan(
          text: url,
          style: TextStyle(
            color: tokens.accent,
            decoration: TextDecoration.underline,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () => _BookmarkCard._openExternal(url),
        ));
        i = m.end;
        committed = i;
        continue;
      }
    }
    if (c == '`') {
      final end = text.indexOf('`', i + 1);
      if (end != -1 && end > i + 1 && !text.substring(i + 1, end).contains('\n')) {
        flushPlain(i);
        out.add(TextSpan(
          text: text.substring(i + 1, end),
          style: mono(fontSize: 13.5, color: tokens.text).copyWith(
            backgroundColor: tokens.surface2,
          ),
        ));
        i = end + 1;
        committed = i;
        continue;
      }
    }
    // Bold: **text**
    if (c == '*' && i + 1 < n && text[i + 1] == '*') {
      final end = text.indexOf('**', i + 2);
      if (end != -1 && end > i + 2) {
        final inner = text.substring(i + 2, end);
        if (!inner.contains('\n')) {
          flushPlain(i);
          out.add(TextSpan(
            text: inner,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ));
          i = end + 2;
          committed = i;
          continue;
        }
      }
    }
    // Italic: *text* or _text_ (single delim)
    if (c == '*' || c == '_') {
      final end = text.indexOf(c, i + 1);
      if (end != -1 && end > i + 1) {
        final inner = text.substring(i + 1, end);
        // Require non-space inner edges to avoid swallowing `2 * 3`.
        if (!inner.contains('\n') &&
            inner.isNotEmpty &&
            inner[0] != ' ' &&
            inner[inner.length - 1] != ' ') {
          flushPlain(i);
          out.add(TextSpan(
            text: inner,
            style: const TextStyle(fontStyle: FontStyle.italic),
          ));
          i = end + 1;
          committed = i;
          continue;
        }
      }
    }
    // Strikethrough: ~~text~~
    if (c == '~' && i + 1 < n && text[i + 1] == '~') {
      final end = text.indexOf('~~', i + 2);
      if (end != -1 && end > i + 2) {
        final inner = text.substring(i + 2, end);
        if (!inner.contains('\n')) {
          flushPlain(i);
          out.add(TextSpan(
            text: inner,
            style: const TextStyle(decoration: TextDecoration.lineThrough),
          ));
          i = end + 2;
          committed = i;
          continue;
        }
      }
    }
    i++;
  }
  flushPlain(n);
  return out;
}

class _ResolvedChip extends StatelessWidget {
  const _ResolvedChip({required this.ulid, required this.showUlid});
  final String ulid;
  final bool showUlid;

  @override
  Widget build(BuildContext context) {
    final db = context.read<QuillDatabase>();
    return FutureBuilder(
      future: (db.select(db.pages)..where((p) => p.ulid.equals(ulid)))
          .getSingleOrNull(),
      builder: (context, snap) {
        final title = snap.data?.title ?? '…${ulid.substring(ulid.length - 6)}';
        return RelationChip(
          label: title,
          ulid: ulid,
          showUlid: showUlid,
          icon: 'file-md',
          onTap: () => Navigator.of(context).pushReplacementNamed('/editor/$ulid'),
        );
      },
    );
  }
}
