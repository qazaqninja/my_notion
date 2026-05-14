import 'package:flutter/material.dart';

import '../../../../shared/theme/quill_tokens.dart';

class OutlineEntry {
  const OutlineEntry({required this.level, required this.text});
  final int level;
  final String text;
}

/// Right-rail "On this page" outline derived from `#`, `##`, `###` lines.
class OutlineRail extends StatelessWidget {
  const OutlineRail({super.key, required this.body, this.activeIndex = 0});

  final String body;
  final int activeIndex;

  static List<OutlineEntry> extract(String body) {
    final entries = <OutlineEntry>[];
    for (final line in body.split('\n')) {
      if (line.startsWith('# ')) {
        entries.add(OutlineEntry(level: 1, text: line.substring(2)));
      } else if (line.startsWith('## ')) {
        entries.add(OutlineEntry(level: 2, text: line.substring(3)));
      } else if (line.startsWith('### ')) {
        entries.add(OutlineEntry(level: 3, text: line.substring(4)));
      }
    }
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    final entries = extract(body);
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
          Container(
            padding: EdgeInsets.fromLTRB(8 + (entries[i].level - 1) * 12.0, 4, 0, 4),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: i == activeIndex ? tokens.accent : Colors.transparent,
                  width: 1.5,
                ),
              ),
            ),
            child: Text(
              entries[i].text,
              style: TextStyle(
                fontSize: 12.5,
                color: i == activeIndex ? tokens.text : tokens.text2,
                fontWeight: i == activeIndex ? FontWeight.w500 : FontWeight.w400,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
      ],
    );
  }
}
