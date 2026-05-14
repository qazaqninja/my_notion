import 'package:flutter/material.dart';

import '../../../../shared/theme/quill_tokens.dart';
import '../../../../shared/theme/tokens.dart';
import '../../../../shared/widgets/quill_icon.dart';
import '../../domain/entities/database_schema.dart';
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
    };

const double _rowHeight = 36;
const double _headerHeight = 30;
const double _titleColWidth = 220;

class FrozenColumnTable extends StatefulWidget {
  const FrozenColumnTable({
    super.key,
    required this.schema,
    required this.rows,
    required this.onOpenPage,
  });

  final DatabaseSchema schema;
  final List<DatabasePageRow> rows;
  final void Function(DatabasePageRow row) onOpenPage;

  @override
  State<FrozenColumnTable> createState() => _FrozenColumnTableState();
}

class _FrozenColumnTableState extends State<FrozenColumnTable> {
  final ScrollController _vertLeft = ScrollController();
  final ScrollController _vertRight = ScrollController();
  bool _syncing = false;

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
    final scrollWidth = cols.fold<double>(0, (a, c) => a + _widthForType(c.type));

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
                      return Container(
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
                      );
                    }
                    final row = widget.rows[i];
                    return _titleRow(row, tokens);
                  },
                ),
              ),
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
                            return Container(height: _rowHeight);
                          }
                          final row = widget.rows[i];
                          return Container(
                            height: _rowHeight,
                            decoration: BoxDecoration(
                              border: Border(bottom: BorderSide(color: tokens.divider, width: 0.5)),
                            ),
                            child: Row(
                              children: [
                                for (final c in cols)
                                  _scrollCell(row, c, tokens),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
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
          height: _rowHeight,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: tokens.divider, width: 0.5)),
          ),
          child: Row(
            children: [
              QuillIcon('file-md', size: 13, strokeWidth: 1.7, color: tokens.text3),
              const SizedBox(width: 6),
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
      ),
    );
  }

  Widget _colHeader(ColumnDef c, QuillTokens tokens, bool isLast) {
    return Container(
      width: _widthForType(c.type),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: c.type == ColumnType.number ? Alignment.centerRight : Alignment.centerLeft,
      decoration: BoxDecoration(
        border: isLast ? null : Border(right: BorderSide(color: tokens.divider, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: c.type == ColumnType.number
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          QuillIcon(_iconForType(c.type), size: 11, strokeWidth: 1.7, color: tokens.text3),
          const SizedBox(width: 5),
          Flexible(
            child: Text(c.key, style: mono(fontSize: 11.5, color: tokens.text3), overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Widget _scrollCell(DatabasePageRow row, ColumnDef c, QuillTokens tokens) {
    final value = row.cells[c.key];
    final isLast = widget.schema.columns.last == c;
    return Container(
      width: _widthForType(c.type),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: c.type == ColumnType.number ? Alignment.centerRight : Alignment.centerLeft,
      decoration: BoxDecoration(
        border: isLast ? null : Border(right: BorderSide(color: tokens.divider, width: 0.5)),
      ),
      child: c.key == 'health'
          ? HealthCell(value: '$value')
          : CellRenderer(
              column: c,
              value: value,
              align: c.type == ColumnType.number ? Alignment.centerRight : Alignment.centerLeft,
            ),
    );
  }
}
