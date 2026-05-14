import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/theme/quill_tokens.dart';
import '../../../../shared/theme/tag_colors.dart';
import '../../../../shared/theme/tokens.dart';
import '../../../../shared/widgets/quill_icon.dart';
import '../../../../shared/widgets/tag_chip.dart';
import '../../domain/entities/database_schema.dart';
import '../../domain/repositories/database_repository.dart';
import '../../domain/row_display.dart';

/// Kanban view grouped by a select column. Matches `altviews.jsx:98-150`.
class BoardView extends StatelessWidget {
  const BoardView({
    super.key,
    required this.schema,
    required this.rows,
    required this.groupBy,
    this.subGroupBy,
  });

  final DatabaseSchema schema;
  final List<DatabasePageRow> rows;

  /// Column key to group by. If null, groups everything into a single
  /// "All" column.
  final String? groupBy;

  /// Optional secondary grouping rendered as section dividers within
  /// each column.
  final String? subGroupBy;

  @override
  Widget build(BuildContext context) {
    final groupKey = groupBy ?? _firstSelectColumn(schema)?.key;
    final groups = _groupRows(groupKey);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in groups.entries) ...[
            _Column(
              schema: schema,
              label: entry.key,
              rows: entry.value,
              groupKey: groupKey,
              subGroupBy: subGroupBy,
            ),
            const SizedBox(width: 14),
          ],
        ],
      ),
    );
  }

  ColumnDef? _firstSelectColumn(DatabaseSchema schema) {
    for (final c in schema.columns) {
      if (c.type == ColumnType.select) return c;
    }
    return schema.columns.isEmpty ? null : schema.columns.first;
  }

  Map<String, List<DatabasePageRow>> _groupRows(String? key) {
    if (key == null) return {'All': rows};

    // Build the list of groups from the schema's options (so empty groups
    // still appear), then put each row into the matching one.
    final col = schema.columns.firstWhere(
      (c) => c.key == key,
      orElse: () => const ColumnDef(key: '', type: ColumnType.select),
    );
    final order = col.options.isEmpty ? <String>{} : <String>{...col.options};

    final out = <String, List<DatabasePageRow>>{};
    for (final stage in order) {
      out[stage] = [];
    }
    for (final row in rows) {
      final v = '${row.cells[key] ?? ''}';
      out.putIfAbsent(v.isEmpty ? '—' : v, () => []).add(row);
    }
    return out;
  }
}

class _Column extends StatelessWidget {
  const _Column({
    required this.schema,
    required this.label,
    required this.rows,
    required this.groupKey,
    this.subGroupBy,
  });

  final DatabaseSchema schema;
  final String label;
  final List<DatabasePageRow> rows;
  final String? groupKey;
  final String? subGroupBy;

  /// Partition rows into sub-groups, preserving input order within each.
  Map<String, List<DatabasePageRow>> _subGroups() {
    if (subGroupBy == null) return {'': rows};
    final out = <String, List<DatabasePageRow>>{};
    for (final r in rows) {
      final raw = '${r.cells[subGroupBy] ?? ''}';
      final key = raw.trim().isEmpty ? '—' : raw;
      (out[key] ??= []).add(r);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    final subs = _subGroups();
    return SizedBox(
      width: 264,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: tokens.divider2, width: 0.5)),
            ),
            child: Row(
              children: [
                TagChip(label: label, color: _stageColor(label)),
                const SizedBox(width: 8),
                Text('${rows.length}', style: mono(fontSize: 11.5, color: tokens.text3)),
                const Spacer(),
                QuillIcon('plus', size: 13, strokeWidth: 1.7, color: tokens.text3),
              ],
            ),
          ),
          const SizedBox(height: 6),
          for (final sub in subs.entries) ...[
            if (subGroupBy != null) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 8, 2, 4),
                child: Row(
                  children: [
                    Container(width: 2, height: 10, color: tokens.divider2),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        sub.key,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                          color: tokens.text3,
                        ),
                      ),
                    ),
                    Text('${sub.value.length}',
                        style: mono(fontSize: 10.5, color: tokens.text3)),
                  ],
                ),
              ),
            ],
            for (final row in sub.value) ...[
              _Card(row: row, schema: schema),
              const SizedBox(height: 6),
            ],
          ],
          GestureDetector(
            onTap: () {},
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  QuillIcon('plus', size: 11, strokeWidth: 1.8, color: tokens.text3),
                  const SizedBox(width: 5),
                  Text('New', style: TextStyle(fontSize: 12, color: tokens.text3)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static TagColor _stageColor(String s) {
    final v = s.toLowerCase();
    if (v.contains('won')) return TagColor.green;
    if (v.contains('expand')) return TagColor.green;
    if (v.contains('churn')) return TagColor.red;
    if (v.contains('pilot')) return TagColor.blue;
    if (v.contains('eval')) return TagColor.yellow;
    if (v.contains('negot')) return TagColor.orange;
    return TagColor.gray;
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.row, required this.schema});
  final DatabasePageRow row;
  final DatabaseSchema schema;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    final arr = '${row.cells['arr'] ?? ''}';
    final owner = '${row.cells['owner'] ?? ''}';
    final date = '${row.cells['updated'] ?? ''}';
    return GestureDetector(
      onTap: () => context.go('/editor/${row.ulid}'),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
          decoration: BoxDecoration(
            color: tokens.surface,
            border: Border.all(color: tokens.divider2, width: 0.5),
            borderRadius: const BorderRadius.all(Radius.circular(5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayTitle(row),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: tokens.text, height: 1.35),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Row(children: [
                if (arr.isNotEmpty && arr != '0')
                  Text(_kFmt(arr), style: mono(fontSize: 11.5, color: tokens.text2)),
                const Spacer(),
                if (owner.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(owner, style: TextStyle(fontSize: 11, color: tokens.text3)),
                  ),
                if (date.isNotEmpty)
                  Text(date, style: mono(fontSize: 10.5, color: tokens.text3)),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  static String _kFmt(String raw) {
    final n = num.tryParse(raw.replaceAll(',', ''));
    if (n == null) return raw;
    if (n >= 1000) return '\$${(n / 1000).toStringAsFixed(0)}k';
    return raw;
  }
}
