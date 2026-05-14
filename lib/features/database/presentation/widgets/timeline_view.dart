import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/theme/quill_tokens.dart';
import '../../../../shared/theme/tokens.dart';
import '../../domain/entities/database_schema.dart';
import '../../domain/repositories/database_repository.dart';

/// Gantt-lite. Matches `altviews.jsx:153-242`.
///
/// Since real `.md` pages don't necessarily have a [start, end] window, we
/// position each row's bar based on its `updated` date with a 7-day band.
/// When a database adds typed date-range columns later, this becomes the
/// place to plug them in.
class TimelineView extends StatelessWidget {
  const TimelineView({super.key, required this.schema, required this.rows});

  final DatabaseSchema schema;
  final List<DatabasePageRow> rows;

  static const int _weeks = 12;
  static const double _weekW = 80;
  static const double _frozenW = 220;
  static const double _rowH = 38;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    if (rows.isEmpty) {
      return Center(
        child: Text('No rows to plot', style: TextStyle(color: tokens.text2)),
      );
    }
    // Compute the time origin: earliest date in the dataset, snapped to a
    // Monday. Bars span from their date to date + 7 days.
    final dates = <DateTime>[];
    for (final row in rows) {
      final d = _parseDate('${row.cells['updated'] ?? ''}');
      if (d != null) dates.add(d);
    }
    if (dates.isEmpty) {
      return Center(
        child: Text('No dated rows to plot', style: TextStyle(color: tokens.text2)),
      );
    }
    dates.sort();
    final origin = _mondayOf(dates.first);

    final trackW = _weeks * _weekW;
    final today = DateTime.now();
    final todayWeek = today.difference(origin).inDays / 7.0;

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: _frozenW + trackW + 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _RulerHeader(origin: origin, tokens: tokens),
              for (final row in rows) _Row(row: row, origin: origin, tokens: tokens),
              if (todayWeek >= 0 && todayWeek <= _weeks)
                _TodayLine(weekOffset: todayWeek, count: rows.length, tokens: tokens),
            ],
          ),
        ),
      ),
    );
  }

  static DateTime? _parseDate(String s) {
    final trimmed = s.trim();
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(trimmed)) return null;
    return DateTime.tryParse(trimmed);
  }

  static DateTime _mondayOf(DateTime d) {
    final dow = d.weekday; // 1 = Mon ... 7 = Sun
    return DateTime(d.year, d.month, d.day - (dow - 1));
  }
}

class _RulerHeader extends StatelessWidget {
  const _RulerHeader({required this.origin, required this.tokens});
  final DateTime origin;
  final QuillTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: tokens.surface2,
        border: Border(bottom: BorderSide(color: tokens.divider2, width: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: TimelineView._frozenW,
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
            alignment: Alignment.bottomLeft,
            child: Text('milestone', style: mono(fontSize: 11, color: tokens.text3)),
          ),
          for (int w = 0; w < TimelineView._weeks; w++)
            Container(
              width: TimelineView._weekW,
              padding: const EdgeInsets.only(bottom: 6),
              alignment: Alignment.bottomCenter,
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: tokens.divider, width: 0.5)),
              ),
              child: Text(
                _label(origin, w),
                style: mono(fontSize: 10.5, color: tokens.text3),
              ),
            ),
        ],
      ),
    );
  }

  String _label(DateTime origin, int w) {
    final d = DateTime(origin.year, origin.month, origin.day + w * 7);
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$mm-$dd';
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.row, required this.origin, required this.tokens});
  final DatabasePageRow row;
  final DateTime origin;
  final QuillTokens tokens;

  @override
  Widget build(BuildContext context) {
    final date = TimelineView._parseDate('${row.cells['updated'] ?? ''}');
    final color = _barColor('${row.cells['stage'] ?? ''}', tokens);
    final ownerInitial = '${row.cells['owner'] ?? '?'}'.isNotEmpty
        ? '${row.cells['owner']}'.substring(0, 1).toUpperCase()
        : '?';

    final daysFromOrigin = date == null ? 0.0 : date.difference(origin).inDays.toDouble();
    final startWeek = daysFromOrigin / 7.0;

    return GestureDetector(
      onTap: () => context.go('/editor/${row.ulid}'),
      child: Container(
        height: TimelineView._rowH,
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: tokens.divider, width: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              width: TimelineView._frozenW,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.7),
                      borderRadius: const BorderRadius.all(Radius.circular(7)),
                    ),
                    child: Text(
                      ownerInitial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        height: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      row.title,
                      style: TextStyle(fontSize: 13, color: tokens.text),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: TimelineView._weeks * TimelineView._weekW,
              child: Stack(
                children: [
                  // Week gridlines
                  for (int w = 1; w < TimelineView._weeks; w++)
                    Positioned(
                      left: w * TimelineView._weekW,
                      top: 0,
                      bottom: 0,
                      child: Container(width: 0.5, color: tokens.divider),
                    ),
                  // Bar — 1 week wide centred at the row's date.
                  if (date != null && startWeek >= 0 && startWeek <= TimelineView._weeks)
                    Positioned(
                      left: startWeek * TimelineView._weekW + 6,
                      top: 8,
                      width: TimelineView._weekW - 12,
                      height: 22,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        alignment: Alignment.centerLeft,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: const BorderRadius.all(Radius.circular(3)),
                        ),
                        child: Text(
                          row.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _barColor(String stage, QuillTokens tokens) {
    final s = stage.toLowerCase();
    if (s.contains('won') || s.contains('expand')) return const Color(0xFF5A8F6E);
    if (s.contains('churn')) return const Color(0xFFA8584C);
    if (s.contains('pilot')) return const Color(0xFF5A82B4);
    if (s.contains('eval')) return const Color(0xFFB39342);
    if (s.contains('negot')) return const Color(0xFFB46F4F);
    return tokens.accent;
  }
}

class _TodayLine extends StatelessWidget {
  const _TodayLine({required this.weekOffset, required this.count, required this.tokens});
  final double weekOffset;
  final int count;
  final QuillTokens tokens;

  @override
  Widget build(BuildContext context) {
    final height = count * TimelineView._rowH;
    return SizedBox(
      height: 0,
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned(
          left: TimelineView._frozenW + weekOffset * TimelineView._weekW,
          top: -height - 0.5,
          height: height,
          child: Container(width: 1.5, color: tokens.accent),
        ),
      ]),
    );
  }
}
