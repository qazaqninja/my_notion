import 'package:flutter/material.dart';

import '../theme/quill_tokens.dart';
import 'quill_icon.dart';
import 'quill_modal.dart';

const List<String> _weekdayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

/// Calendar picker styled to `DatePicker` from `menus.jsx:228-300`.
class QuillDatePicker extends StatefulWidget {
  const QuillDatePicker({
    super.key,
    this.initial,
    this.firstDate,
    this.lastDate,
    required this.onPicked,
    this.onCancel,
  });

  final DateTime? initial;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final ValueChanged<DateTime?> onPicked;
  final VoidCallback? onCancel;

  @override
  State<QuillDatePicker> createState() => _QuillDatePickerState();
}

class _QuillDatePickerState extends State<QuillDatePicker> {
  late DateTime _cursor;
  late DateTime? _selected;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selected = widget.initial;
    final seed = widget.initial ?? now;
    _cursor = DateTime(seed.year, seed.month);
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isToday(DateTime d) => _sameDay(d, DateTime.now());

  bool _isSelected(DateTime d) =>
      _selected != null && _sameDay(_selected!, d);

  void _shift(int months) {
    setState(() {
      _cursor = DateTime(_cursor.year, _cursor.month + months);
    });
  }

  void _pick(DateTime d) {
    setState(() => _selected = d);
    widget.onPicked(d);
  }

  void _today() {
    final now = DateTime.now();
    setState(() {
      _cursor = DateTime(now.year, now.month);
      _selected = now;
    });
    widget.onPicked(now);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    final monthLabel = _monthName(_cursor.month);
    final firstWeekday = DateTime(_cursor.year, _cursor.month, 1).weekday;
    final startEmpty = firstWeekday - 1; // Monday-first
    final daysInMonth = DateUtils.getDaysInMonth(_cursor.year, _cursor.month);
    final cells = <DateTime?>[];
    for (var i = 0; i < startEmpty; i++) {
      cells.add(null);
    }
    for (var d = 1; d <= daysInMonth; d++) {
      cells.add(DateTime(_cursor.year, _cursor.month, d));
    }
    while (cells.length < 42) {
      cells.add(null);
    }

    return QuillModal(
      width: 304,
      header: QuillModalHeader(
        title: 'Pick date',
        sub: '$monthLabel ${_cursor.year}',
        icon: 'calendar',
        onClose: widget.onCancel ?? () => Navigator.of(context).pop(),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: tokens.inputBg,
                      border:
                          Border.all(color: tokens.divider2, width: 0.5),
                      borderRadius:
                          const BorderRadius.all(Radius.circular(5)),
                    ),
                    child: Text(
                      _selected != null
                          ? _isoDate(_selected!)
                          : 'Select a date',
                      style: TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 12.5,
                        color:
                            _selected != null ? tokens.text : tokens.text3,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                _NavButton(
                  label: 'Today',
                  onTap: _today,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  '$monthLabel ${_cursor.year}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: tokens.text,
                  ),
                ),
                const Spacer(),
                _IconButton(
                  icon: 'caret',
                  rotate: 0.5, // 180°, faces left
                  tooltip: 'Previous month',
                  onTap: () => _shift(-1),
                ),
                _IconButton(
                  icon: 'caret',
                  tooltip: 'Next month',
                  onTap: () => _shift(1),
                ),
              ],
            ),
            const SizedBox(height: 4),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
              children: [
                for (final w in _weekdayLabels)
                  Center(
                    child: Text(
                      w,
                      style: TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 10.5,
                        color: tokens.text3,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
              children: [
                for (final d in cells)
                  if (d == null)
                    const SizedBox.shrink()
                  else
                    _DayCell(
                      day: d.day,
                      isToday: _isToday(d),
                      isSelected: _isSelected(d),
                      isDisabled: _isDisabled(d),
                      onTap: _isDisabled(d) ? null : () => _pick(d),
                    ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  bool _isDisabled(DateTime d) {
    if (widget.firstDate != null && d.isBefore(widget.firstDate!)) return true;
    if (widget.lastDate != null && d.isAfter(widget.lastDate!)) return true;
    return false;
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.isToday,
    required this.isSelected,
    required this.isDisabled,
    required this.onTap,
  });

  final int day;
  final bool isToday;
  final bool isSelected;
  final bool isDisabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    final highlight = isSelected || isToday;
    final bg = isSelected
        ? tokens.accent
        : (isToday ? tokens.accentTint : Colors.transparent);
    final fg = isSelected
        ? Colors.white
        : (isDisabled ? tokens.text3 : tokens.text);
    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.all(Radius.circular(4)),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.all(Radius.circular(4)),
        ),
        alignment: Alignment.center,
        child: Text(
          '$day',
          style: TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 12.5,
            color: fg,
            fontWeight: highlight ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    return Tooltip(
      message: label == 'Today'
          ? 'Jump to ${DateTime.now().toIso8601String().substring(0, 10)}'
          : label,
      waitDuration: const Duration(milliseconds: 500),
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(5)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            border: Border.all(color: tokens.divider2, width: 0.5),
            borderRadius: const BorderRadius.all(Radius.circular(5)),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: tokens.text,
            ),
          ),
        ),
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.icon,
    required this.onTap,
    this.rotate = 0,
    this.tooltip,
  });
  final String icon;
  final VoidCallback onTap;
  final double rotate;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    Widget button = InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.all(Radius.circular(4)),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: RotatedBox(
          quarterTurns: (rotate * 2).round(),
          child: QuillIcon(icon,
              size: 13, strokeWidth: 1.8, color: tokens.text2),
        ),
      ),
    );
    if (tooltip != null) {
      button = Tooltip(
        message: tooltip!,
        waitDuration: const Duration(milliseconds: 500),
        child: button,
      );
    }
    return button;
  }
}

String _monthName(int m) {
  const names = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December'
  ];
  return names[(m - 1).clamp(0, 11)];
}

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Show a [QuillDatePicker] as a modal and return the picked date or null.
Future<DateTime?> showQuillDatePicker(
  BuildContext context, {
  DateTime? initial,
  DateTime? firstDate,
  DateTime? lastDate,
}) {
  return showQuillModal<DateTime>(
    context,
    builder: (ctx) {
      return QuillDatePicker(
        initial: initial,
        firstDate: firstDate,
        lastDate: lastDate,
        onPicked: (d) => Navigator.of(ctx).pop(d),
        onCancel: () => Navigator.of(ctx).pop(),
      );
    },
  );
}

