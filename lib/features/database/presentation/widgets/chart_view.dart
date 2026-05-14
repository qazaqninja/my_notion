import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../shared/theme/quill_tokens.dart';
import '../../../../shared/theme/tokens.dart';
import '../../domain/entities/database_schema.dart';
import '../../domain/repositories/database_repository.dart';

/// Bar chart of row counts grouped by a select-style column.
///
/// The grouping column is auto-detected: first ColumnDef with type
/// [ColumnType.select], else first [ColumnType.multi], else first
/// column whose key isn't `id`/`title`. Each bar is the row count.
/// A second numeric column, when present, drives an optional sum-line.
class ChartView extends StatelessWidget {
  const ChartView({
    super.key,
    required this.schema,
    required this.rows,
    this.subGroupBy,
  });

  final DatabaseSchema schema;
  final List<DatabasePageRow> rows;

  /// When non-null, each primary-group bar splits into stacked segments
  /// by this column's value. Each segment is tinted by a stable hash
  /// of the sub-group value. Empty values land in a neutral grey
  /// segment. A small legend renders below the chart so the user can
  /// read the colour assignments.
  final String? subGroupBy;

  static const _palette = <Color>[
    Color(0xFF5A8F6E),
    Color(0xFF5A82B4),
    Color(0xFFB46F4F),
    Color(0xFF8B5FA8),
    Color(0xFFB39342),
    Color(0xFF4F8FA4),
    Color(0xFF9C5A6A),
    Color(0xFF6B8E7F),
  ];

  static Color _subColor(String value) {
    if (value.isEmpty || value == '—') return const Color(0xFF8C8C8C);
    var h = 0;
    for (final code in value.codeUnits) {
      h = (h * 31 + code) & 0x7fffffff;
    }
    return _palette[h % _palette.length];
  }

  /// Build a single stacked bar rod for [primaryKey], colouring each
  /// segment by sub-group hash. The bar's `toY` is the total height;
  /// `rodStackItems` define the boundaries between coloured segments.
  static BarChartRodData _stackedRod(
    String primaryKey,
    Map<String, Map<String, int>> stacks,
    List<String> subOrder,
    QuillTokens tokens,
  ) {
    final segs = stacks[primaryKey] ?? const <String, int>{};
    double total = 0;
    final items = <BarChartRodStackItem>[];
    for (final sub in subOrder) {
      final n = (segs[sub] ?? 0).toDouble();
      if (n <= 0) continue;
      final from = total;
      total += n;
      items.add(BarChartRodStackItem(from, total, _subColor(sub)));
    }
    return BarChartRodData(
      toY: total,
      width: 28,
      borderRadius:
          const BorderRadius.vertical(top: Radius.circular(2)),
      color: items.isEmpty ? tokens.accent : null,
      rodStackItems: items,
    );
  }

  ColumnDef? get _groupCol {
    for (final c in schema.columns) {
      if (c.type == ColumnType.select) return c;
    }
    for (final c in schema.columns) {
      if (c.type == ColumnType.multi) return c;
    }
    for (final c in schema.columns) {
      if (c.key != 'id' && c.key != 'title') return c;
    }
    return null;
  }

  ColumnDef? get _numCol {
    for (final c in schema.columns) {
      if (c.type == ColumnType.number) return c;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    final groupCol = _groupCol;
    if (groupCol == null || rows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            rows.isEmpty
                ? 'No rows to chart.'
                : 'No column to group by.\n\nAdd a select-typed column to group rows.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: tokens.text3),
          ),
        ),
      );
    }

    final counts = <String, int>{};
    final sums = <String, num>{};
    final numCol = _numCol;
    // stacks[primaryKey][subKey] = count, populated only when sub-grouping
    final stacks = <String, Map<String, int>>{};
    final subOrder = <String>[]; // first-occurrence order across all rows
    for (final row in rows) {
      final raw = '${row.cells[groupCol.key] ?? ''}'.trim();
      final key = raw.isEmpty ? '—' : raw;
      counts[key] = (counts[key] ?? 0) + 1;
      if (numCol != null) {
        final n = num.tryParse('${row.cells[numCol.key] ?? ''}');
        if (n != null) sums[key] = (sums[key] ?? 0) + n;
      }
      if (subGroupBy != null) {
        final subRaw = '${row.cells[subGroupBy] ?? ''}'.trim();
        final subKey = subRaw.isEmpty ? '—' : subRaw;
        (stacks[key] ??= <String, int>{})[subKey] =
            (stacks[key]?[subKey] ?? 0) + 1;
        if (!subOrder.contains(subKey)) subOrder.add(subKey);
      }
    }

    // Preserve declared option order on select columns.
    final order = <String>[];
    if (groupCol.options.isNotEmpty) {
      for (final o in groupCol.options) {
        if (counts.containsKey(o)) order.add(o);
      }
      for (final k in counts.keys) {
        if (!order.contains(k)) order.add(k);
      }
    } else {
      order.addAll(counts.keys);
    }

    final maxCount = counts.values.fold<int>(0, (a, b) => b > a ? b : a);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'COUNT BY ${groupCol.key.toUpperCase()}'
            '${numCol != null ? ' · sum of ${numCol.key}' : ''}',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
              color: tokens.text3,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceBetween,
                maxY: (maxCount + 1).toDouble(),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: tokens.divider,
                    strokeWidth: 0.5,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: maxCount > 4 ? (maxCount / 4).ceilToDouble() : 1,
                      getTitlesWidget: (v, _) => Text(
                        v.toInt().toString(),
                        style: mono(fontSize: 10.5, color: tokens.text3),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (v, meta) {
                        final idx = v.toInt();
                        if (idx < 0 || idx >= order.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            order[idx],
                            style: TextStyle(fontSize: 11, color: tokens.text2),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (int i = 0; i < order.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        if (subGroupBy == null)
                          BarChartRodData(
                            toY: (counts[order[i]] ?? 0).toDouble(),
                            color: tokens.accent,
                            width: 28,
                            borderRadius:
                                const BorderRadius.vertical(top: Radius.circular(2)),
                          )
                        else
                          _stackedRod(order[i], stacks, subOrder, tokens),
                      ],
                    ),
                ],
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => tokens.surface,
                    getTooltipItem: (group, groupIdx, rod, rodIdx) {
                      final label = order[group.x];
                      final c = counts[label] ?? 0;
                      final s = numCol != null
                          ? '\n${numCol.key}: ${sums[label] ?? 0}'
                          : '';
                      return BarTooltipItem(
                        '$label\n$c rows$s',
                        TextStyle(
                          fontSize: 11.5,
                          color: tokens.text,
                          fontWeight: FontWeight.w500,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          if (subGroupBy != null && subOrder.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                for (final sub in subOrder)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _subColor(sub),
                          borderRadius:
                              const BorderRadius.all(Radius.circular(2)),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(sub,
                          style:
                              TextStyle(fontSize: 11, color: tokens.text2)),
                    ],
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
