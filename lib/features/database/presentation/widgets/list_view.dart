import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/theme/quill_tokens.dart';
import '../../../../shared/theme/tokens.dart';
import '../../../../shared/widgets/quill_icon.dart';
import '../../../../shared/widgets/status_dot.dart';
import '../../domain/entities/database_schema.dart';
import '../../domain/repositories/database_repository.dart';

/// Compact one-line-per-row view of a database. Mirrors `altviews.jsx`'s
/// list pattern: icon + title (left), trailing comma-joined secondary
/// columns in monospace dim text, optional status dot for any `health`-
/// shaped column.
class DatabaseListView extends StatelessWidget {
  const DatabaseListView({
    super.key,
    required this.schema,
    required this.rows,
  });

  final DatabaseSchema schema;
  final List<DatabasePageRow> rows;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    if (rows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('No rows',
              style: TextStyle(fontSize: 13, color: tokens.text3)),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: rows.length,
      itemBuilder: (context, i) => _Row(row: rows[i], schema: schema),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.row, required this.schema});

  final DatabasePageRow row;
  final DatabaseSchema schema;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    final secondary = _secondary();
    final health = '${row.cells['health'] ?? ''}'.toLowerCase();
    return GestureDetector(
      onTap: () => context.go('/editor/${row.ulid}'),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 7),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: tokens.divider, width: 0.5),
            ),
          ),
          child: Row(
            children: [
              QuillIcon('file-md',
                  size: 13, strokeWidth: 1.7, color: tokens.text3),
              const SizedBox(width: 10),
              Expanded(
                flex: 4,
                child: Text(
                  row.title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: tokens.text,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              if (secondary.isNotEmpty)
                Expanded(
                  flex: 5,
                  child: Text(
                    secondary,
                    textAlign: TextAlign.right,
                    style: mono(fontSize: 11.5, color: tokens.text3),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              if (health.isNotEmpty) ...[
                const SizedBox(width: 10),
                StatusDot(color: _dotColor(health)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Join up to 3 secondary columns into a single trailing string.
  /// Skips the title column, empty values, and the health column
  /// (rendered as a dot instead).
  String _secondary() {
    final parts = <String>[];
    for (final col in schema.columns) {
      if (col.key == 'title' || col.key == 'health') continue;
      final v = row.cells[col.key];
      if (v == null) continue;
      final s = v is List ? v.join(', ') : '$v';
      if (s.isEmpty) continue;
      parts.add(s);
      if (parts.length >= 3) break;
    }
    return parts.join('  ·  ');
  }

  static StatusDotColor _dotColor(String h) => switch (h) {
        'green' => StatusDotColor.green,
        'yellow' => StatusDotColor.yellow,
        'red' => StatusDotColor.red,
        _ => StatusDotColor.gray,
      };
}
