import 'package:flutter/material.dart';

import '../../../../shared/theme/quill_tokens.dart';
import '../../../../shared/theme/tokens.dart';
import '../../../../shared/widgets/quill_icon.dart';
import '../../domain/entities/database_schema.dart';
import '../../domain/formula/formula.dart';
import '../../domain/repositories/database_repository.dart';
import 'cell_renderers.dart';

/// Width per column type. Centralised so the title-column on the left and
/// the scrollable columns on the right agree on heights/widths.
double _widthForType(ColumnType t) => switch (t) {
      ColumnType.text => 130,
      ColumnType.number => 110,
      ColumnType.date => 110,
      ColumnType.select => 130,
      ColumnType.multi => 200,
      ColumnType.relation => 160,
      ColumnType.checkbox => 60,
      ColumnType.formula => 130,
      ColumnType.file => 130,
      ColumnType.createdTime => 130,
      ColumnType.lastEditedTime => 130,
    };

String _iconForType(ColumnType t) => switch (t) {
      ColumnType.text => 'note',
      ColumnType.number => 'hash',
      ColumnType.date => 'calendar',
      ColumnType.select => 'select',
      ColumnType.multi => 'tag',
      ColumnType.relation => 'link',
      ColumnType.checkbox => 'checksquare',
      ColumnType.formula => 'code',
      ColumnType.file => 'file',
      ColumnType.createdTime => 'calendar',
      ColumnType.lastEditedTime => 'calendar',
    };

const double _rowHeight = 36;
const double _headerHeight = 30;
const double _titleColWidth = 220;
const double _footerHeight = 26;

enum _Agg { none, count, sum, avg, min, max }

extension _AggExt on _Agg {
  String label(num? v) {
    final n = v == null ? '—' : _fmt(v);
    return switch (this) {
      _Agg.none => '',
      _Agg.count => 'count $n',
      _Agg.sum => 'sum $n',
      _Agg.avg => 'avg $n',
      _Agg.min => 'min $n',
      _Agg.max => 'max $n',
    };
  }

  _Agg cycleNumeric() => switch (this) {
        _Agg.none => _Agg.count,
        _Agg.count => _Agg.sum,
        _Agg.sum => _Agg.avg,
        _Agg.avg => _Agg.min,
        _Agg.min => _Agg.max,
        _Agg.max => _Agg.none,
      };

  _Agg cycleText() => switch (this) {
        _Agg.none => _Agg.count,
        _Agg.count => _Agg.none,
        _ => _Agg.count,
      };
}

String _fmt(num n) {
  if (n is int) return _withSep(n);
  if (n == n.truncate()) return _withSep(n.toInt());
  return n.toStringAsFixed(2);
}

String _withSep(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0 && s[i - 1] != '-') buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

class FrozenColumnTable extends StatefulWidget {
  const FrozenColumnTable({
    super.key,
    required this.schema,
    required this.rows,
    required this.onOpenPage,
    this.onEditCell,
    this.onCreateRow,
    this.wrap = false,
  });

  final DatabaseSchema schema;
  final List<DatabasePageRow> rows;
  final void Function(DatabasePageRow row) onOpenPage;

  /// When set, cells in editable types become click-to-edit.
  final Future<void> Function(DatabasePageRow row, ColumnDef column, Object? newValue)? onEditCell;

  /// When true, cells render with `maxLines: null` and rows scale to fit.
  /// The frozen-column layout is preserved but rows in left and right lists
  /// may visually misalign for super-long content — explicit tradeoff for
  /// keeping the impl simple.
  final bool wrap;

  /// When set, the trailing "+ New" row becomes interactive.
  final VoidCallback? onCreateRow;

  @override
  State<FrozenColumnTable> createState() => _FrozenColumnTableState();
}

class _FrozenColumnTableState extends State<FrozenColumnTable> {
  final ScrollController _vertLeft = ScrollController();
  final ScrollController _vertRight = ScrollController();
  bool _syncing = false;
  final Map<String, _Agg> _aggs = {};

  /// Per-column width overrides. Survives view switches within the same
  /// table-page session but isn't persisted to .database.yaml yet.
  final Map<String, double> _widthOverrides = {};

  double _widthFor(ColumnDef c) => _widthOverrides[c.key] ?? _widthForType(c.type);

  @override
  void initState() {
    super.initState();
    _vertLeft.addListener(() => _sync(_vertLeft, _vertRight));
    _vertRight.addListener(() => _sync(_vertRight, _vertLeft));
  }

  void _sync(ScrollController src, ScrollController dst) {
    if (_syncing) return;
    if (!dst.hasClients) return;
    if (src.offset == dst.offset) return;
    _syncing = true;
    dst.jumpTo(src.offset);
    _syncing = false;
  }

  @override
  void dispose() {
    _vertLeft.dispose();
    _vertRight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    final cols = widget.schema.columns;
    final scrollWidth = cols.fold<double>(0, (a, c) => a + _widthFor(c));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Frozen title column
        Container(
          width: _titleColWidth,
          decoration: BoxDecoration(
            border: Border(right: BorderSide(color: tokens.divider2, width: 0.5)),
            color: tokens.bg,
          ),
          child: Column(
            children: [
              Container(
                height: _headerHeight,
                color: tokens.surface2,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    QuillIcon('file-md', size: 11, strokeWidth: 1.7, color: tokens.text3),
                    const SizedBox(width: 5),
                    Text('title', style: mono(fontSize: 11.5, color: tokens.text3)),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: _vertLeft,
                  itemCount: widget.rows.length + 1,
                  itemBuilder: (context, i) {
                    if (i == widget.rows.length) {
                      final enabled = widget.onCreateRow != null;
                      return GestureDetector(
                        onTap: enabled ? widget.onCreateRow : null,
                        child: MouseRegion(
                          cursor: enabled
                              ? SystemMouseCursors.click
                              : SystemMouseCursors.basic,
                          child: Container(
                            height: _rowHeight,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            alignment: Alignment.centerLeft,
                            child: Row(
                              children: [
                                QuillIcon('plus', size: 12, strokeWidth: 1.7, color: tokens.text3),
                                const SizedBox(width: 5),
                                Text('New', style: TextStyle(fontSize: 12.5, color: tokens.text3)),
                              ],
                            ),
                          ),
                        ),
                      );
                    }
                    final row = widget.rows[i];
                    return _titleRow(row, tokens);
                  },
                ),
              ),
              _titleFooter(tokens),
            ],
          ),
        ),
        // Scrollable columns
        Expanded(
          child: Scrollbar(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: scrollWidth.clamp(640, double.infinity),
                child: Column(
                  children: [
                    Container(
                      height: _headerHeight,
                      color: tokens.surface2,
                      child: Row(
                        children: [
                          for (final c in cols)
                            _colHeader(c, tokens, c == cols.last),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        controller: _vertRight,
                        itemCount: widget.rows.length + 1,
                        itemBuilder: (context, i) {
                          if (i == widget.rows.length) {
                            return SizedBox(
                                height: widget.wrap ? _rowHeight : _rowHeight);
                          }
                          final row = widget.rows[i];
                          return Container(
                            constraints:
                                BoxConstraints(minHeight: _rowHeight),
                            decoration: BoxDecoration(
                              border: Border(bottom: BorderSide(color: tokens.divider, width: 0.5)),
                            ),
                            child: IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  for (final c in cols)
                                    _scrollCell(row, c, tokens),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    _scrollFooter(cols, tokens),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _titleRow(DatabasePageRow row, QuillTokens tokens) {
    return GestureDetector(
      onTap: () => widget.onOpenPage(row),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          constraints: BoxConstraints(minHeight: _rowHeight),
          padding:
              EdgeInsets.fromLTRB(10, widget.wrap ? 8 : 0, 10, widget.wrap ? 8 : 0),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: tokens.divider, width: 0.5)),
          ),
          child: Row(
            crossAxisAlignment:
                widget.wrap ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            children: [
              Padding(
                padding: EdgeInsets.only(top: widget.wrap ? 2 : 0),
                child: QuillIcon('file-md',
                    size: 13, strokeWidth: 1.7, color: tokens.text3),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  row.title,
                  style: TextStyle(fontSize: 13, color: tokens.text, height: 1.4),
                  overflow:
                      widget.wrap ? TextOverflow.visible : TextOverflow.ellipsis,
                  maxLines: widget.wrap ? null : 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _colHeader(ColumnDef c, QuillTokens tokens, bool isLast) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: _widthFor(c),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment:
              c.type == ColumnType.number ? Alignment.centerRight : Alignment.centerLeft,
          decoration: BoxDecoration(
            border: isLast
                ? null
                : Border(right: BorderSide(color: tokens.divider, width: 0.5)),
          ),
          child: Row(
            mainAxisAlignment: c.type == ColumnType.number
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            children: [
              QuillIcon(_iconForType(c.type),
                  size: 11, strokeWidth: 1.7, color: tokens.text3),
              const SizedBox(width: 5),
              Flexible(
                child: Text(c.key,
                    style: mono(fontSize: 11.5, color: tokens.text3),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
        // Right-edge drag handle. 6px wide, transparent fill, resize cursor.
        Positioned(
          right: -3,
          top: 0,
          bottom: 0,
          width: 6,
          child: MouseRegion(
            cursor: SystemMouseCursors.resizeColumn,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragUpdate: (d) {
                setState(() {
                  final current = _widthFor(c);
                  _widthOverrides[c.key] =
                      (current + d.delta.dx).clamp(56.0, 720.0);
                });
              },
              onDoubleTap: () => setState(() {
                _widthOverrides.remove(c.key);
              }),
            ),
          ),
        ),
      ],
    );
  }

  Widget _scrollCell(DatabasePageRow row, ColumnDef c, QuillTokens tokens) {
    Object? value = row.cells[c.key];
    if (c.type == ColumnType.formula && c.formula != null) {
      value = evaluateFormula(c.formula!, row.cells);
      if (value is FormulaError) value = value.toString();
    }
    if (c.type == ColumnType.lastEditedTime) {
      value = row.mtimeMs > 0 ? row.mtimeMs : null;
    }
    if (c.type == ColumnType.createdTime) {
      value = row.createdAt ?? (row.mtimeMs > 0 ? row.mtimeMs : null);
    }
    final isLast = widget.schema.columns.last == c;
    final editable = widget.onEditCell != null && _isEditable(c.type) && c.key != 'health';
    final align = c.type == ColumnType.number ? Alignment.centerRight : Alignment.centerLeft;
    Widget rendered = c.key == 'health'
        ? HealthCell(value: '$value')
        : CellRenderer(column: c, value: value, align: align, wrap: widget.wrap);
    if (editable) {
      rendered = _EditableCell(
        key: ValueKey('${row.ulid}-${c.key}'),
        column: c,
        value: value,
        align: align,
        onCommit: (v) => widget.onEditCell!(row, c, v),
        child: rendered,
      );
    }
    return Container(
      width: _widthFor(c),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: align,
      decoration: BoxDecoration(
        border: isLast ? null : Border(right: BorderSide(color: tokens.divider, width: 0.5)),
      ),
      child: rendered,
    );
  }

  Widget _titleFooter(QuillTokens tokens) {
    return Container(
      height: _footerHeight,
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: tokens.divider, width: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.centerLeft,
      child: Text('count ${widget.rows.length}',
          style: mono(fontSize: 11, color: tokens.text3)),
    );
  }

  Widget _scrollFooter(List<ColumnDef> cols, QuillTokens tokens) {
    return Container(
      height: _footerHeight,
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: tokens.divider, width: 0.5)),
      ),
      child: Row(
        children: [
          for (final c in cols) _footerCell(c, tokens, c == cols.last),
        ],
      ),
    );
  }

  Widget _footerCell(ColumnDef c, QuillTokens tokens, bool isLast) {
    final agg = _aggs[c.key] ?? _Agg.none;
    final isNumeric = c.type == ColumnType.number;
    final value = isNumeric ? _aggNumeric(c.key, agg) : (agg == _Agg.count ? widget.rows.length : null);
    return GestureDetector(
      onTap: () => setState(() {
        _aggs[c.key] = isNumeric ? agg.cycleNumeric() : agg.cycleText();
      }),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          width: _widthFor(c),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: c.type == ColumnType.number
              ? Alignment.centerRight
              : Alignment.centerLeft,
          decoration: BoxDecoration(
            border: isLast
                ? null
                : Border(right: BorderSide(color: tokens.divider, width: 0.5)),
          ),
          child: Text(
            agg == _Agg.none ? 'calc' : agg.label(value),
            style: mono(
              fontSize: 11,
              color: agg == _Agg.none ? tokens.text3 : tokens.text2,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  num? _aggNumeric(String key, _Agg op) {
    if (op == _Agg.none) return null;
    if (op == _Agg.count) return widget.rows.length;
    final values = <num>[];
    for (final r in widget.rows) {
      final v = num.tryParse('${r.cells[key] ?? ''}');
      if (v != null) values.add(v);
    }
    if (values.isEmpty) return null;
    switch (op) {
      case _Agg.sum:
        return values.fold<num>(0, (a, b) => a + b);
      case _Agg.avg:
        return values.fold<num>(0, (a, b) => a + b) / values.length;
      case _Agg.min:
        return values.reduce((a, b) => a < b ? a : b);
      case _Agg.max:
        return values.reduce((a, b) => a > b ? a : b);
      default:
        return null;
    }
  }

  static bool _isEditable(ColumnType t) {
    switch (t) {
      case ColumnType.text:
      case ColumnType.number:
      case ColumnType.date:
      case ColumnType.select:
      case ColumnType.multi:
      case ColumnType.checkbox:
        return true;
      case ColumnType.relation:
      case ColumnType.formula:
      case ColumnType.file:
      case ColumnType.createdTime:
      case ColumnType.lastEditedTime:
        return false;
    }
  }
}

/// Wraps a cell renderer with click-to-edit. Text/number/date/select/multi
/// swap to a TextField on click; checkbox toggles in place on click.
class _EditableCell extends StatefulWidget {
  const _EditableCell({
    super.key,
    required this.column,
    required this.value,
    required this.align,
    required this.onCommit,
    required this.child,
  });

  final ColumnDef column;
  final Object? value;
  final Alignment align;
  final Future<void> Function(Object? newValue) onCommit;
  final Widget child;

  @override
  State<_EditableCell> createState() => _EditableCellState();
}

class _EditableCellState extends State<_EditableCell> {
  bool _editing = false;
  final FocusNode _focus = FocusNode();
  late TextEditingController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = TextEditingController(text: _initialText());
  }

  @override
  void didUpdateWidget(_EditableCell old) {
    super.didUpdateWidget(old);
    if (!_editing && _initialText() != _ctl.text) {
      _ctl.text = _initialText();
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    _ctl.dispose();
    super.dispose();
  }

  String _initialText() {
    final v = widget.value;
    if (v == null) return '';
    if (v is List) return v.join(', ');
    return '$v';
  }

  void _start() {
    if (widget.column.type == ColumnType.checkbox) {
      final on = '${widget.value}'.toLowerCase() == 'true';
      widget.onCommit(on ? 'false' : 'true');
      return;
    }
    if (widget.column.type == ColumnType.date) {
      _pickDate();
      return;
    }
    setState(() => _editing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focus.requestFocus();
      _ctl.selection =
          TextSelection(baseOffset: 0, extentOffset: _ctl.text.length);
    });
  }

  Future<void> _pickDate() async {
    final initial = DateTime.tryParse('${widget.value ?? ''}'.trim()) ??
        DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    final iso =
        '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    await widget.onCommit(iso);
  }

  Future<void> _commit() async {
    final next = _ctl.text;
    if (next == _initialText()) {
      setState(() => _editing = false);
      return;
    }
    setState(() => _editing = false);
    await widget.onCommit(next);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    if (!_editing) {
      return GestureDetector(
        onTap: _start,
        behavior: HitTestBehavior.opaque,
        child: MouseRegion(
          cursor: SystemMouseCursors.cell,
          child: SizedBox(
            width: double.infinity,
            height: _rowHeight - 2,
            child: Align(alignment: widget.align, child: widget.child),
          ),
        ),
      );
    }
    return Focus(
      onKeyEvent: (_, event) {
        if (event.logicalKey.keyLabel == 'Escape') {
          _ctl.text = _initialText();
          setState(() => _editing = false);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: TextField(
        controller: _ctl,
        focusNode: _focus,
        onSubmitted: (_) => _commit(),
        onTapOutside: (_) => _commit(),
        style: widget.column.type == ColumnType.number ||
                widget.column.type == ColumnType.date
            ? mono(fontSize: 13, color: tokens.text)
            : TextStyle(fontSize: 13, color: tokens.text),
        decoration: const InputDecoration(
          isCollapsed: true,
          contentPadding: EdgeInsets.symmetric(vertical: 4),
          border: InputBorder.none,
        ),
        textAlign: widget.column.type == ColumnType.number
            ? TextAlign.right
            : TextAlign.left,
      ),
    );
  }
}
