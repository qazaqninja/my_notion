import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/markdown/wikilink_parser.dart';
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
  const TimelineView({
    super.key,
    required this.schema,
    required this.rows,
    this.subGroupBy,
  });

  final DatabaseSchema schema;
  final List<DatabasePageRow> rows;

  /// When non-null, the timeline emits a 22px header band between rows
  /// whose value differs (empty → `—`). The dependency-arrow overlay is
  /// suppressed in sub-group mode because the painter's y-coords are
  /// row-index based and dividers would shift them out of register.
  final String? subGroupBy;

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

    // Pre-compute dependency edges: for each row index, the indices
    // of rows it depends on. Both ends must have a parsable date to
    // be drawn — undated dependencies fall back to the badge only.
    final ulidIdx = <String, int>{
      for (var i = 0; i < rows.length; i++) rows[i].ulid: i,
    };
    final deps = <_DepEdge>[];
    final depCount = List<int>.filled(rows.length, 0);
    final depTitles = List<List<String>>.generate(rows.length, (_) => []);
    for (var i = 0; i < rows.length; i++) {
      final raw = rows[i].cells['depends_on'];
      if (raw == null) continue;
      final ulids = _parseDepUlids(raw);
      for (final u in ulids) {
        final j = ulidIdx[u];
        if (j == null) continue;
        depCount[i] += 1;
        depTitles[i].add(rows[j].title);
        final from = _parseDate('${rows[j].cells['updated'] ?? ''}');
        final to = _parseDate('${rows[i].cells['updated'] ?? ''}');
        if (from != null && to != null) {
          deps.add(_DepEdge(
            fromIdx: j,
            toIdx: i,
            fromStartWeek: from.difference(origin).inDays / 7.0,
            toStartWeek: to.difference(origin).inDays / 7.0,
          ));
        }
      }
    }

    // Build the entry list — with sub-group dividers interleaved when
    // widget.subGroupBy is set, otherwise pure rows.
    final children = <Widget>[];
    children.add(_RulerHeader(origin: origin, tokens: tokens));
    if (subGroupBy != null) {
      String? lastKey;
      for (var i = 0; i < rows.length; i++) {
        final raw = '${rows[i].cells[subGroupBy] ?? ''}'.trim();
        final key = raw.isEmpty ? '—' : raw;
        if (key != lastKey) {
          children.add(_SubgroupBand(label: key, tokens: tokens));
          lastKey = key;
        }
        children.add(_Row(
          row: rows[i],
          origin: origin,
          tokens: tokens,
          depCount: depCount[i],
          depTitles: depTitles[i],
        ));
      }
    } else {
      for (var i = 0; i < rows.length; i++) {
        children.add(_Row(
          row: rows[i],
          origin: origin,
          tokens: tokens,
          depCount: depCount[i],
          depTitles: depTitles[i],
        ));
      }
    }
    if (todayWeek >= 0 && todayWeek <= _weeks) {
      children.add(_TodayLine(
        weekOffset: todayWeek,
        count: rows.length,
        tokens: tokens,
      ));
    }
    // Dependency arrows: only drawn when not sub-grouped — see the
    // class doc for why.
    final showDeps = subGroupBy == null && deps.isNotEmpty;

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: _frozenW + trackW + 24,
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
              if (showDeps)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _DependencyPainter(
                        deps: deps,
                        rulerHeight: 32,
                        rowHeight: _rowH,
                        frozenWidth: _frozenW,
                        weekWidth: _weekW,
                        weeks: _weeks,
                        color: tokens.text3.withValues(alpha: 0.55),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static List<String> _parseDepUlids(dynamic raw) {
    final out = <String>{};
    if (raw is List) {
      for (final item in raw) {
        out.addAll(WikilinkParser.find('$item').map((w) => w.ulid));
      }
    } else {
      out.addAll(WikilinkParser.find('$raw').map((w) => w.ulid));
    }
    return out.toList();
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
  const _Row({
    required this.row,
    required this.origin,
    required this.tokens,
    this.depCount = 0,
    this.depTitles = const [],
  });
  final DatabasePageRow row;
  final DateTime origin;
  final QuillTokens tokens;
  final int depCount;
  final List<String> depTitles;

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
                  if (depCount > 0)
                    Tooltip(
                      message: 'Depends on:\n• ${depTitles.join("\n• ")}',
                      child: Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: tokens.surface2,
                          borderRadius:
                              const BorderRadius.all(Radius.circular(3)),
                        ),
                        child: Text(
                          '↳ $depCount',
                          style: mono(fontSize: 10, color: tokens.text3),
                        ),
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

/// Full-width band that splits the timeline rows into sub-group
/// sections. Sits between two `_Row`s; renders the group label in
/// mono uppercase letterSpacing in the frozen column gutter and
/// continues the band across the full timeline track for visual
/// continuity with the row dividers.
class _SubgroupBand extends StatelessWidget {
  const _SubgroupBand({required this.label, required this.tokens});
  final String label;
  final QuillTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      decoration: BoxDecoration(
        color: tokens.surface2,
        border: Border(
          bottom: BorderSide(color: tokens.divider2, width: 0.5),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: mono(
          fontSize: 11,
          color: tokens.text2,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
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

/// A drawn arrow from an upstream row's bar to a dependent row's bar.
class _DepEdge {
  const _DepEdge({
    required this.fromIdx,
    required this.toIdx,
    required this.fromStartWeek,
    required this.toStartWeek,
  });
  final int fromIdx;
  final int toIdx;
  final double fromStartWeek;
  final double toStartWeek;
}

class _DependencyPainter extends CustomPainter {
  _DependencyPainter({
    required this.deps,
    required this.rulerHeight,
    required this.rowHeight,
    required this.frozenWidth,
    required this.weekWidth,
    required this.weeks,
    required this.color,
  });

  final List<_DepEdge> deps;
  final double rulerHeight;
  final double rowHeight;
  final double frozenWidth;
  final double weekWidth;
  final int weeks;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;
    final fillPaint = Paint()..color = color;
    for (final e in deps) {
      // Upstream bar end (right edge), dependent bar start (left edge).
      // Bars are inset 6px and (weekW - 12) wide; offset to bar centre Y.
      final fromX = frozenWidth + (e.fromStartWeek + 1) * weekWidth - 6;
      final toX = frozenWidth + e.toStartWeek * weekWidth + 6;
      final fromY = rulerHeight + e.fromIdx * rowHeight + rowHeight / 2;
      final toY = rulerHeight + e.toIdx * rowHeight + rowHeight / 2;
      // Skip edges that land off-canvas to keep the picture clean.
      if (fromX < frozenWidth - 4 || fromX > frozenWidth + weeks * weekWidth) {
        continue;
      }
      if (toX < frozenWidth - 4 || toX > frozenWidth + weeks * weekWidth) {
        continue;
      }
      // L-shaped connector: horizontal out from upstream, vertical to
      // dependent's row, then horizontal into dependent's bar.
      final midX = (fromX + toX) / 2;
      final path = Path()
        ..moveTo(fromX, fromY)
        ..lineTo(midX, fromY)
        ..lineTo(midX, toY)
        ..lineTo(toX, toY);
      canvas.drawPath(path, paint);
      // Tiny arrowhead at the dependent end.
      final arrow = Path()
        ..moveTo(toX, toY)
        ..lineTo(toX - 5, toY - 3)
        ..lineTo(toX - 5, toY + 3)
        ..close();
      canvas.drawPath(arrow, fillPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DependencyPainter old) =>
      old.deps != deps ||
      old.rulerHeight != rulerHeight ||
      old.rowHeight != rowHeight ||
      old.frozenWidth != frozenWidth ||
      old.weekWidth != weekWidth ||
      old.color != color;
}
