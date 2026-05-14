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
  const MarkdownRenderer({super.key, required this.body, this.showUlid = false});

  final String body;
  final bool showUlid;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    final blocks = _splitBlocks(body);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final b in blocks) _renderBlock(context, tokens, b),
      ],
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
    final out = <_Block>[];
    int i = 0;

    while (i < lines.length) {
      final line = lines[i];

      // Code fence
      if (line.startsWith('```')) {
        final buf = StringBuffer();
        i++;
        while (i < lines.length && !lines[i].startsWith('```')) {
          if (buf.isNotEmpty) buf.write('\n');
          buf.write(lines[i]);
          i++;
        }
        out.add(_Block(kind: _BlockKind.code, text: buf.toString()));
        if (i < lines.length) i++; // skip closing ```
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
        out.add(_Block(kind: _BlockKind.table, tableRows: rows));
        continue;
      }

      // Math fence  $$ ... $$
      if (line.startsWith(r'$$')) {
        // Inline same-line form: `$$ x = 1 $$`
        final stripped = line.substring(2);
        final closeIdx = stripped.lastIndexOf(r'$$');
        if (closeIdx >= 0) {
          out.add(_Block(
            kind: _BlockKind.math,
            text: stripped.substring(0, closeIdx).trim(),
          ));
          i++;
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
        out.add(_Block(kind: _BlockKind.math, text: buf.toString().trim()));
        if (i < lines.length) i++;
        continue;
      }

      // Heading
      if (line.startsWith('### ')) {
        out.add(_Block(kind: _BlockKind.h3, text: line.substring(4)));
        i++;
        continue;
      }
      if (line.startsWith('## ')) {
        out.add(_Block(kind: _BlockKind.h2, text: line.substring(3)));
        i++;
        continue;
      }
      if (line.startsWith('# ')) {
        out.add(_Block(kind: _BlockKind.h1, text: line.substring(2)));
        i++;
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
        out.add(_Block(kind: _BlockKind.quote, text: buf.toString()));
        continue;
      }

      // Horizontal rule
      if (line.trim() == '---' || line.trim() == '***' || line.trim() == '___') {
        out.add(_Block(kind: _BlockKind.hr));
        i++;
        continue;
      }

      // Unordered list (with optional checkbox)
      if (line.startsWith('- ') || line.startsWith('* ')) {
        final items = <String>[];
        while (i < lines.length && (lines[i].startsWith('- ') || lines[i].startsWith('* '))) {
          items.add(lines[i].substring(2));
          i++;
        }
        out.add(_Block(kind: _BlockKind.ul, items: items));
        continue;
      }

      // Ordered list (digits followed by `. `)
      if (RegExp(r'^\d+\.\s').hasMatch(line)) {
        final items = <String>[];
        while (i < lines.length && RegExp(r'^\d+\.\s').hasMatch(lines[i])) {
          items.add(lines[i].replaceFirst(RegExp(r'^\d+\.\s'), ''));
          i++;
        }
        out.add(_Block(kind: _BlockKind.ol, items: items));
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
      out.add(_Block(kind: _BlockKind.paragraph, text: buf.toString()));
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
      (line.contains('|') && line.trim().startsWith('|'));
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
  const _Block({required this.kind, this.text = '', this.items, this.tableRows});
  final _BlockKind kind;
  final String text;
  final List<String>? items;
  final List<List<String>>? tableRows;
}

enum _BlockKind { h1, h2, h3, paragraph, ul, ol, code, math, quote, hr, table }

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
