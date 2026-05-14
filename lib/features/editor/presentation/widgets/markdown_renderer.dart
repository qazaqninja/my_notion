import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../../../../core/db/quill_database.dart' hide Page;
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
    final inner = _renderBlock(context, tokens, b);
    if (onBodyChange == null) return inner;
    // Only paragraph + headings are tap-to-edit in this MVP; lists,
    // tables, code, math, etc. still require source-mode toggle.
    final editable = b.kind == _BlockKind.paragraph ||
        b.kind == _BlockKind.h1 ||
        b.kind == _BlockKind.h2 ||
        b.kind == _BlockKind.h3 ||
        b.kind == _BlockKind.quote;
    if (!editable) return inner;
    return _EditableBlock(
      key: ValueKey('blk-${b.sourceStart}-${b.sourceEnd}'),
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
        // Standalone wikilink: render as a sub-page card.
        final ulid = _matchStandaloneWikilink(b.text);
        if (ulid != null) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: _SubpageCard(ulid: ulid),
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
    final headings = <(int, String)>[];
    for (final line in body.split('\n')) {
      if (line.startsWith('### ')) {
        headings.add((3, line.substring(4)));
      } else if (line.startsWith('## ')) {
        headings.add((2, line.substring(3)));
      } else if (line.startsWith('# ')) {
        headings.add((1, line.substring(2)));
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
          for (final (lvl, t) in headings)
            Padding(
              padding: EdgeInsets.only(left: (lvl - 1) * 14.0, top: 3),
              child: Text(
                t,
                style: TextStyle(
                  fontSize: lvl == 1 ? 14 : (lvl == 2 ? 13 : 12.5),
                  fontWeight: lvl == 1 ? FontWeight.w600 : FontWeight.w500,
                  color: tokens.text2,
                ),
              ),
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
      line.trim().startsWith('<details>');
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
  final m = RegExp(r'^\[\[([0-9A-HJKMNP-TV-Z]{26})\]\]$').firstMatch(trimmed);
  return m?.group(1);
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
    this.sourceStart = 0,
    this.sourceEnd = 0,
  });
  final _BlockKind kind;
  final String text;
  final List<String>? items;
  final List<List<String>>? tableRows;

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
