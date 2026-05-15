import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/theme/quill_tokens.dart';
import '../../../../shared/theme/tokens.dart';
import '../../../../shared/widgets/quill_icon.dart';
import '../../../../shared/widgets/status_dot.dart';
import '../../domain/entities/database_schema.dart';
import '../../domain/repositories/database_repository.dart';
import '../../domain/row_display.dart';

/// Compact one-line-per-row view of a database. Mirrors `altviews.jsx`'s
/// list pattern: icon + title (left), trailing comma-joined secondary
/// columns in monospace dim text, optional status dot for any `health`-
/// shaped column.
class DatabaseListView extends StatelessWidget {
  const DatabaseListView({
    super.key,
    required this.schema,
    required this.rows,
    this.subGroupBy,
  });

  final DatabaseSchema schema;
  final List<DatabasePageRow> rows;

  /// When non-null, a divider band is inserted between rows whose value
  /// for this column differs. Empty values bucket under `—`. Mirrors
  /// the BoardView / TableView / GalleryView sub-group behaviour.
  final String? subGroupBy;

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
    final entries = _buildEntries();
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: entries.length,
      itemBuilder: (context, i) {
        final e = entries[i];
        return e.row != null
            ? _Row(row: e.row!, schema: schema)
            : _SectionHeader(label: e.label!, count: e.count, tokens: tokens);
      },
    );
  }

  List<_ListEntry> _buildEntries() {
    if (subGroupBy == null) {
      return [for (final r in rows) _ListEntry.row(r)];
    }
    final out = <_ListEntry>[];
    String? lastKey;
    int sectionCount = 0;
    int sectionHeaderIdx = -1;
    for (final r in rows) {
      final raw = '${r.cells[subGroupBy] ?? ''}'.trim();
      final key = raw.isEmpty ? '—' : raw;
      if (key != lastKey) {
        if (sectionHeaderIdx >= 0) {
          out[sectionHeaderIdx] = out[sectionHeaderIdx].withCount(sectionCount);
        }
        sectionHeaderIdx = out.length;
        out.add(_ListEntry.header(key, 0));
        sectionCount = 0;
        lastKey = key;
      }
      out.add(_ListEntry.row(r));
      sectionCount += 1;
    }
    if (sectionHeaderIdx >= 0) {
      out[sectionHeaderIdx] = out[sectionHeaderIdx].withCount(sectionCount);
    }
    return out;
  }
}

class _ListEntry {
  const _ListEntry._({this.row, this.label, this.count = 0});
  factory _ListEntry.row(DatabasePageRow row) => _ListEntry._(row: row);
  factory _ListEntry.header(String label, int count) =>
      _ListEntry._(label: label, count: count);
  final DatabasePageRow? row;
  final String? label;
  final int count;
  _ListEntry withCount(int c) =>
      _ListEntry._(row: row, label: label, count: c);
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.label,
    required this.count,
    required this.tokens,
  });
  final String label;
  final int count;
  final QuillTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 6),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: tokens.divider2, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: mono(
              fontSize: 11,
              color: tokens.text2,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 8),
          Text('$count', style: mono(fontSize: 11, color: tokens.text3)),
        ],
      ),
    );
  }
}

class _Row extends StatefulWidget {
  const _Row({required this.row, required this.schema});

  final DatabasePageRow row;
  final DatabaseSchema schema;

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  bool _hover = false;

  DatabasePageRow get row => widget.row;
  DatabaseSchema get schema => widget.schema;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    final secondary = _secondary();
    final health = '${row.cells['health'] ?? ''}'.toLowerCase();
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => context.go('/editor/${row.ulid}'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 7),
          decoration: BoxDecoration(
            color: _hover ? tokens.hover : null,
            border: Border(
              bottom: BorderSide(color: tokens.divider, width: 0.5),
            ),
          ),
          child: Row(
            children: [
              _rowIcon(row, tokens),
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

  Widget _rowIcon(DatabasePageRow row, QuillTokens tokens) {
    final emoji = rowIconString(row);
    if (emoji != null) {
      return SizedBox(
        width: 14,
        child: Text(emoji,
            style: TextStyle(fontSize: 13, color: tokens.text),
            textAlign: TextAlign.center),
      );
    }
    return QuillIcon('file-md',
        size: 13, strokeWidth: 1.7, color: tokens.text3);
  }

  static StatusDotColor _dotColor(String h) => switch (h) {
        'green' => StatusDotColor.green,
        'yellow' => StatusDotColor.yellow,
        'red' => StatusDotColor.red,
        _ => StatusDotColor.gray,
      };
}
