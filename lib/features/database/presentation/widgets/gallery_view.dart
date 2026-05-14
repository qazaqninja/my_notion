import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/theme/quill_tokens.dart';
import '../../../../shared/theme/tag_colors.dart';
import '../../../../shared/theme/tokens.dart';
import '../../../../shared/widgets/image_placeholder.dart';
import '../../../../shared/widgets/quill_icon.dart';
import '../../../../shared/widgets/status_dot.dart';
import '../../../../shared/widgets/tag_chip.dart';
import '../../domain/entities/database_schema.dart';
import '../../domain/repositories/database_repository.dart';

/// Card-grid view of a database. Matches `altviews.jsx:46-95`.
class GalleryView extends StatelessWidget {
  const GalleryView({
    super.key,
    required this.schema,
    required this.rows,
  });

  final DatabaseSchema schema;
  final List<DatabasePageRow> rows;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 260,
        mainAxisExtent: 220,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
      ),
      itemCount: rows.length,
      itemBuilder: (context, i) => _Card(row: rows[i], schema: schema),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.row, required this.schema});
  final DatabasePageRow row;
  final DatabaseSchema schema;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    final stage = '${row.cells['stage'] ?? ''}';
    final health = '${row.cells['health'] ?? ''}';
    final arr = '${row.cells['arr'] ?? ''}';
    final owner = '${row.cells['owner'] ?? ''}';
    final last = '${row.cells['updated'] ?? ''}';

    return GestureDetector(
      onTap: () => context.go('/editor/${row.ulid}'),
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
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                child: ImagePlaceholder(label: 'cover · ${row.title.toLowerCase()}', height: 92),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      QuillIcon('file-md', size: 12, strokeWidth: 1.7, color: tokens.text3),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          row.title,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: tokens.text,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      if (health.isNotEmpty) StatusDot(color: _dotColor(health)),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      if (stage.isNotEmpty) TagChip(label: stage, color: _stageColor(stage)),
                      const SizedBox(width: 6),
                      if (arr.isNotEmpty && arr != '0')
                        Text(_kFmt(arr), style: mono(fontSize: 11.5, color: tokens.text3)),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      Text(
                        owner,
                        style: TextStyle(fontSize: 11.5, color: tokens.text3),
                      ),
                      const Spacer(),
                      Text(last, style: mono(fontSize: 11, color: tokens.text3)),
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static StatusDotColor _dotColor(String h) => switch (h.toLowerCase()) {
        'green' => StatusDotColor.green,
        'yellow' => StatusDotColor.yellow,
        'red' => StatusDotColor.red,
        _ => StatusDotColor.gray,
      };

  static TagColor _stageColor(String s) {
    final v = s.toLowerCase();
    if (v.contains('won') || v.contains('expand')) return TagColor.green;
    if (v.contains('churn')) return TagColor.red;
    if (v.contains('pilot')) return TagColor.blue;
    if (v.contains('eval')) return TagColor.yellow;
    return TagColor.gray;
  }

  static String _kFmt(String raw) {
    final n = num.tryParse(raw.replaceAll(',', ''));
    if (n == null) return raw;
    if (n >= 1000) return '\$${(n / 1000).toStringAsFixed(0)}k';
    return raw;
  }
}
