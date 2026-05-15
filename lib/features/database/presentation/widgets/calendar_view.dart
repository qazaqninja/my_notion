import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../../shared/theme/quill_tokens.dart';
import '../../../../shared/theme/tag_colors.dart';
import '../../../../shared/theme/tokens.dart';
import '../../../../shared/widgets/quill_icon.dart';
import '../../domain/entities/database_schema.dart';
import '../../domain/repositories/database_repository.dart';
import '../../domain/row_display.dart';

/// Calendar projection of database rows. Each row with a parseable date in
/// its first date column shows as an event on that day. Clicking a day's
/// pill opens the underlying page.
///
/// The date column is auto-detected: the first ColumnDef with type
/// [ColumnType.date] (and a fallback to common names like `updated`,
/// `date`, `due`, `scheduled` if no typed date column exists).
class CalendarView extends StatefulWidget {
  const CalendarView({
    super.key,
    required this.schema,
    required this.rows,
    this.subGroupBy,
  });

  final DatabaseSchema schema;
  final List<DatabasePageRow> rows;

  /// When non-null, the leading dot beside each row (and the day-cell
  /// markers) is coloured by a deterministic hash of the row's value
  /// for this column. Empty values get a neutral grey. Doesn't move
  /// rows around — just adds visual differentiation. Mirrors the
  /// other views' sub-group plumbing without re-shaping the grid.
  final String? subGroupBy;

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> {
  DateTime _focused = DateTime.now();
  DateTime? _selected;
  CalendarFormat _format = CalendarFormat.month;

  String? get _dateKey {
    for (final c in widget.schema.columns) {
      if (c.type == ColumnType.date) return c.key;
    }
    for (final fallback in const ['updated', 'date', 'due', 'scheduled']) {
      for (final c in widget.schema.columns) {
        if (c.key == fallback) return c.key;
      }
    }
    return null;
  }

  Map<DateTime, List<DatabasePageRow>> _bucketByDate() {
    final key = _dateKey;
    if (key == null) return const {};
    final out = <DateTime, List<DatabasePageRow>>{};
    for (final row in widget.rows) {
      final d = _parseDate('${row.cells[key] ?? ''}');
      if (d == null) continue;
      final keyDay = DateTime.utc(d.year, d.month, d.day);
      out.putIfAbsent(keyDay, () => []).add(row);
    }
    return out;
  }

  static DateTime? _parseDate(String s) {
    final trimmed = s.trim();
    if (trimmed.isEmpty) return null;
    return DateTime.tryParse(trimmed);
  }

  /// Stable colour from sub-group value. Empty/null → neutral grey;
  /// any other value gets one of eight muted hues (same palette
  /// PersonChip uses, so the colours feel consistent across the app).
  Color _subgroupColor(DatabasePageRow row, Color fallback) {
    final key = widget.subGroupBy;
    if (key == null) return fallback;
    return categoricalColor('${row.cells[key] ?? ''}'.trim());
  }

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    final dateKey = _dateKey;
    if (dateKey == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              QuillIcon('calendar',
                  size: 24, strokeWidth: 1.4, color: tokens.text3),
              const SizedBox(height: 10),
              Text(
                'No date column',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: tokens.text2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Add a `type: date` column in .database.yaml\nto enable the calendar view.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12, color: tokens.text3, height: 1.45),
              ),
            ],
          ),
        ),
      );
    }
    final buckets = _bucketByDate();
    final selectedRows = _selected == null
        ? const <DatabasePageRow>[]
        : buckets[DateTime.utc(_selected!.year, _selected!.month, _selected!.day)] ?? const [];

    return Column(
      children: [
        TableCalendar(
          firstDay: DateTime.utc(2000, 1, 1),
          lastDay: DateTime.utc(2100, 12, 31),
          focusedDay: _focused,
          selectedDayPredicate: (d) =>
              _selected != null && isSameDay(_selected, d),
          onDaySelected: (selected, focused) => setState(() {
            _selected = selected;
            _focused = focused;
          }),
          onPageChanged: (focused) => _focused = focused,
          calendarFormat: _format,
          onFormatChanged: (f) => setState(() => _format = f),
          eventLoader: (day) =>
              buckets[DateTime.utc(day.year, day.month, day.day)] ?? const [],
          startingDayOfWeek: StartingDayOfWeek.monday,
          headerStyle: HeaderStyle(
            formatButtonVisible: true,
            titleCentered: true,
            titleTextStyle: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: tokens.text,
            ),
            leftChevronIcon:
                Icon(Icons.chevron_left, color: tokens.text2, size: 18),
            rightChevronIcon:
                Icon(Icons.chevron_right, color: tokens.text2, size: 18),
            formatButtonDecoration: BoxDecoration(
              border: Border.all(color: tokens.divider2),
              borderRadius: const BorderRadius.all(Radius.circular(4)),
            ),
            formatButtonTextStyle: TextStyle(fontSize: 11, color: tokens.text2),
          ),
          calendarStyle: CalendarStyle(
            outsideDaysVisible: true,
            outsideTextStyle: TextStyle(color: tokens.text3.withValues(alpha: 0.5)),
            defaultTextStyle: TextStyle(color: tokens.text2, fontSize: 12.5),
            weekendTextStyle: TextStyle(color: tokens.text2, fontSize: 12.5),
            todayDecoration: BoxDecoration(
              color: tokens.accentTint,
              shape: BoxShape.circle,
            ),
            todayTextStyle: TextStyle(
              color: tokens.accent,
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
            ),
            selectedDecoration: BoxDecoration(
              color: tokens.accent,
              shape: BoxShape.circle,
            ),
            selectedTextStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
            ),
            markerDecoration: BoxDecoration(
              color: tokens.accent,
              shape: BoxShape.circle,
            ),
            markersAlignment: Alignment.bottomCenter,
            markerMargin: const EdgeInsets.only(top: 4),
            markersMaxCount: 4,
            markerSize: 4,
          ),
          daysOfWeekStyle: DaysOfWeekStyle(
            weekdayStyle: TextStyle(fontSize: 11, color: tokens.text3),
            weekendStyle: TextStyle(fontSize: 11, color: tokens.text3),
          ),
          calendarBuilders: widget.subGroupBy == null
              ? const CalendarBuilders<DatabasePageRow>()
              : CalendarBuilders<DatabasePageRow>(
                  markerBuilder: (context, day, events) {
                    if (events.isEmpty) return null;
                    final rows = events.cast<DatabasePageRow>();
                    final shown = rows.take(4).toList();
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (final r in shown)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 1),
                              child: Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: _subgroupColor(r, tokens.accent),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        Expanded(
          child: selectedRows.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        QuillIcon('calendar',
                            size: 24,
                            strokeWidth: 1.4,
                            color: tokens.text3),
                        const SizedBox(height: 10),
                        Text(
                          _selected == null
                              ? 'Pick a day'
                              : 'No pages on this day',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: tokens.text2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _selected == null
                              ? 'Click a date in the calendar to see its pages.'
                              : 'Nothing scheduled for ${_selected!.toIso8601String().split("T").first}.',
                          style: TextStyle(fontSize: 12, color: tokens.text3),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: selectedRows.length,
                  itemBuilder: (context, i) {
                    final r = selectedRows[i];
                    return _DayPageRow(
                      row: r,
                      tokens: tokens,
                      dotColor: _subgroupColor(r, tokens.accent),
                      dateText: '${r.cells[dateKey] ?? ''}',
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _DayPageRow extends StatefulWidget {
  const _DayPageRow({
    required this.row,
    required this.tokens,
    required this.dotColor,
    required this.dateText,
  });

  final DatabasePageRow row;
  final QuillTokens tokens;
  final Color dotColor;
  final String dateText;

  @override
  State<_DayPageRow> createState() => _DayPageRowState();
}

class _DayPageRowState extends State<_DayPageRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    final r = widget.row;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => context.go('/editor/${r.ulid}'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: _hover ? tokens.surface2 : tokens.surface,
            border: Border.all(
                color: _hover ? tokens.accent : tokens.divider2, width: 0.5),
            borderRadius: const BorderRadius.all(Radius.circular(5)),
          ),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: widget.dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Tooltip(
                  message: displayTitle(r),
                  waitDuration: const Duration(milliseconds: 600),
                  child: Text(
                    displayTitle(r),
                    style: TextStyle(fontSize: 13, color: tokens.text),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Tooltip(
                message: 'Due ${widget.dateText}',
                waitDuration: const Duration(milliseconds: 500),
                child: Text(
                  widget.dateText,
                  style: mono(fontSize: 11, color: tokens.text3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
