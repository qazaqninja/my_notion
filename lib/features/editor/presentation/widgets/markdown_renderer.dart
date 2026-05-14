import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/db/quill_database.dart' hide Page;
import '../../../../core/markdown/wikilink_parser.dart';
import '../../../../shared/theme/quill_tokens.dart';
import '../../../../shared/theme/tokens.dart';
import '../../../../shared/widgets/relation_chip.dart';

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
                  child: Row(
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
                        child: _ParagraphWithChips(text: item, showUlid: showUlid, tokens: tokens),
                      ),
                    ],
                  ),
                ),
            ],
          ),
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

      // Unordered list
      if (line.startsWith('- ') || line.startsWith('* ')) {
        final items = <String>[];
        while (i < lines.length && (lines[i].startsWith('- ') || lines[i].startsWith('* '))) {
          items.add(lines[i].substring(2));
          i++;
        }
        out.add(_Block(kind: _BlockKind.ul, items: items));
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
      line.startsWith('# ') ||
      line.startsWith('## ') ||
      line.startsWith('### ') ||
      line.startsWith('- ') ||
      line.startsWith('* ');
}

class _Block {
  const _Block({required this.kind, this.text = '', this.items});
  final _BlockKind kind;
  final String text;
  final List<String>? items;
}

enum _BlockKind { h1, h2, h3, paragraph, ul, code }

/// Render a paragraph with `[[ULID]]` segments turned into [RelationChip]s.
/// Titles are resolved from drift's `pages` table at build time.
class _ParagraphWithChips extends StatelessWidget {
  const _ParagraphWithChips({required this.text, required this.showUlid, required this.tokens});

  final String text;
  final bool showUlid;
  final QuillTokens tokens;

  @override
  Widget build(BuildContext context) {
    final links = WikilinkParser.find(text);
    if (links.isEmpty) {
      return SelectableText(
        text,
        style: TextStyle(fontSize: 16, color: tokens.text, height: 1.6),
      );
    }
    // Build a row of plain Text and RelationChip widgets interleaved.
    final spans = <Widget>[];
    int cursor = 0;
    for (final link in links) {
      if (link.start > cursor) {
        spans.add(_segText(text.substring(cursor, link.start), tokens));
      }
      spans.add(
        _ResolvedChip(ulid: link.ulid, showUlid: showUlid),
      );
      cursor = link.end;
    }
    if (cursor < text.length) {
      spans.add(_segText(text.substring(cursor), tokens));
    }
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 2,
      runSpacing: 4,
      children: spans,
    );
  }

  Widget _segText(String s, QuillTokens t) {
    return Text(
      s,
      style: TextStyle(fontSize: 16, color: t.text, height: 1.6),
    );
  }
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
