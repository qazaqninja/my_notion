import 'package:flutter/material.dart';

import '../../../../shared/theme/quill_tokens.dart';

class OutlineEntry {
  const OutlineEntry({
    required this.level,
    required this.text,
    required this.lineIdx,
  });
  final int level;
  final String text;
  final int lineIdx;
}

/// Right-rail "On this page" outline derived from `#`, `##`, `###` lines.
/// When [scroll] is supplied the rail tracks the editor's current
/// scroll position and highlights the closest preceding heading;
/// clicking any entry animates the editor to that heading via the
/// same line-fraction heuristic used by TOC links and anchor jumps.
class OutlineRail extends StatefulWidget {
  const OutlineRail({super.key, required this.body, this.scroll});

  final String body;
  final ScrollController? scroll;

  static List<OutlineEntry> extract(String body) {
    final entries = <OutlineEntry>[];
    final lines = body.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.startsWith('# ')) {
        entries.add(OutlineEntry(level: 1, text: line.substring(2), lineIdx: i));
      } else if (line.startsWith('## ')) {
        entries.add(OutlineEntry(level: 2, text: line.substring(3), lineIdx: i));
      } else if (line.startsWith('### ')) {
        entries.add(OutlineEntry(level: 3, text: line.substring(4), lineIdx: i));
      }
    }
    return entries;
  }

  @override
  State<OutlineRail> createState() => _OutlineRailState();
}

class _OutlineRailState extends State<OutlineRail> {
  int _activeIndex = 0;

  @override
  void initState() {
    super.initState();
    widget.scroll?.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(OutlineRail old) {
    super.didUpdateWidget(old);
    if (old.scroll != widget.scroll) {
      old.scroll?.removeListener(_onScroll);
      widget.scroll?.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    widget.scroll?.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    final s = widget.scroll;
    if (s == null || !s.hasClients) return;
    final pos = s.position;
    final frac = pos.maxScrollExtent <= 0
        ? 0.0
        : (pos.pixels / pos.maxScrollExtent).clamp(0.0, 1.0);
    final totalLines = widget.body.split('\n').length;
    final cursorLine = (totalLines * frac).floor();
    final entries = OutlineRail.extract(widget.body);
    int active = 0;
    for (var i = 0; i < entries.length; i++) {
      if (entries[i].lineIdx <= cursorLine) {
        active = i;
      } else {
        break;
      }
    }
    if (active != _activeIndex) {
      setState(() => _activeIndex = active);
    }
  }

  void _jumpTo(OutlineEntry entry) {
    final s = widget.scroll;
    if (s == null || !s.hasClients) return;
    final totalLines = widget.body.split('\n').length;
    final frac = totalLines == 0 ? 0.0 : entry.lineIdx / totalLines;
    final pos = s.position;
    final target = (pos.maxScrollExtent * frac)
        .clamp(pos.minScrollExtent, pos.maxScrollExtent);
    pos.animateTo(target,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    final entries = OutlineRail.extract(widget.body);
    if (entries.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'ON THIS PAGE',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
              color: tokens.text3,
            ),
          ),
        ),
        for (int i = 0; i < entries.length; i++)
          _OutlineItem(
            entry: entries[i],
            active: i == _activeIndex,
            tokens: tokens,
            onTap: widget.scroll == null ? null : () => _jumpTo(entries[i]),
          ),
      ],
    );
  }
}

class _OutlineItem extends StatefulWidget {
  const _OutlineItem({
    required this.entry,
    required this.active,
    required this.tokens,
    required this.onTap,
  });

  final OutlineEntry entry;
  final bool active;
  final QuillTokens tokens;
  final VoidCallback? onTap;

  @override
  State<_OutlineItem> createState() => _OutlineItemState();
}

class _OutlineItemState extends State<_OutlineItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    final entry = widget.entry;
    final tappable = widget.onTap != null;
    return MouseRegion(
      cursor: tappable ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: tappable ? (_) => setState(() => _hover = true) : null,
      onExit: tappable ? (_) => setState(() => _hover = false) : null,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: EdgeInsets.fromLTRB(
              8 + (entry.level - 1) * 12.0, 4, 0, 4),
          decoration: BoxDecoration(
            color: _hover && !widget.active ? tokens.hover : null,
            border: Border(
              left: BorderSide(
                color: widget.active ? tokens.accent : Colors.transparent,
                width: 1.5,
              ),
            ),
          ),
          child: Tooltip(
            message: entry.text,
            waitDuration: const Duration(milliseconds: 600),
            child: Text(
              entry.text,
              style: TextStyle(
                fontSize: 12.5,
                color: widget.active
                    ? tokens.text
                    : (_hover ? tokens.text : tokens.text2),
                fontWeight:
                    widget.active ? FontWeight.w500 : FontWeight.w400,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ),
      ),
    );
  }
}
