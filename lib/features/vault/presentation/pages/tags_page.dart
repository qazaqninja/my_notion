import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/db/quill_database.dart' hide Page;
import '../../../../shared/theme/quill_tokens.dart';
import '../../../../shared/theme/tag_colors.dart';
import '../../../../shared/theme/tokens.dart';
import '../../../../shared/widgets/tag_chip.dart';
import '../widgets/page_header.dart';

/// Aggregates select / multi / tag frontmatter values across every page
/// in the vault. Sorted by frequency (most used first); each chip shows
/// the value + how many pages use it.
class TagsPage extends StatefulWidget {
  const TagsPage({super.key});

  @override
  State<TagsPage> createState() => _TagsPageState();
}

class _TagsPageState extends State<TagsPage> {
  late Future<Map<String, int>> _data;

  @override
  void initState() {
    super.initState();
    _data = _aggregate();
  }

  Future<Map<String, int>> _aggregate() async {
    final db = context.read<QuillDatabase>();
    final rows = await db.select(db.pages).get();
    final counts = <String, int>{};
    for (final row in rows) {
      final Map<String, dynamic> fm;
      try {
        fm = json.decode(row.frontmatterJson) as Map<String, dynamic>;
      } catch (_) {
        continue;
      }
      // Treat keys that smell like categorical fields as tag sources:
      // tags, status, stage, kind, type, category, labels, multi-* etc.
      // Also accept any list value regardless of key.
      for (final entry in fm.entries) {
        final v = entry.value;
        if (v is List) {
          for (final item in v) {
            final s = '$item'.trim();
            if (s.isEmpty) continue;
            counts[s] = (counts[s] ?? 0) + 1;
          }
        } else if (entry.key == 'tags' ||
            entry.key == 'status' ||
            entry.key == 'stage' ||
            entry.key == 'category' ||
            entry.key == 'kind' ||
            entry.key == 'type') {
          final s = '${v ?? ''}'.trim();
          if (s.isEmpty) continue;
          counts[s] = (counts[s] ?? 0) + 1;
        }
      }
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    final palette = [
      TagColor.blue,
      TagColor.green,
      TagColor.orange,
      TagColor.purple,
      TagColor.pink,
      TagColor.yellow,
      TagColor.gray,
    ];
    return Scaffold(
      backgroundColor: tokens.bg,
      body: Column(
        children: [
          const PageHeader(crumbs: ['Tags']),
          Expanded(
            child: FutureBuilder<Map<String, int>>(
              future: _data,
              builder: (context, snap) {
                if (!snap.hasData) {
                  return Center(
                    child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 1.5, color: tokens.text2),
                    ),
                  );
                }
                final entries = snap.data!.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value));
                if (entries.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No tags yet.\n\n'
                        'Add a `tags:` or `status:` field to any page\'s '
                        'frontmatter (or a multi-value column in a database) '
                        'and they\'ll show up here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 13.5, color: tokens.text3, height: 1.55),
                      ),
                    ),
                  );
                }
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 10,
                    children: [
                      for (var i = 0; i < entries.length; i++)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TagChip(
                              label: entries[i].key,
                              color: palette[i % palette.length],
                            ),
                            const SizedBox(width: 4),
                            Text('${entries[i].value}',
                                style: mono(
                                    fontSize: 11, color: tokens.text3)),
                          ],
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
