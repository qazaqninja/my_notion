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
  const ChartView({super.key, required this.schema, required this.rows});

  final DatabaseSchema schema;
  final List<DatabasePageRow> rows;

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
    for (final row in rows) {
      final raw = '${row.cells[groupCol.key] ?? ''}'.trim();
      final key = raw.isEmpty ? '—' : raw;
      counts[key] = (counts[key] ?? 0) + 1;
      if (numCol != null) {
        final n = num.tryParse('${row.cells[numCol.key] ?? ''}');
        if (n != null) sums[key] = (sums[key] ?? 0) + n;
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
                        BarChartRodData(
                          toY: (counts[order[i]] ?? 0).toDouble(),
                          color: tokens.accent,
                          width: 28,
                          borderRadius:
                              const BorderRadius.vertical(top: Radius.circular(2)),
                        ),
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
        ],
      ),
    );
  }
}
