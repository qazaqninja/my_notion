import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/db/quill_database.dart' hide Page;
import '../../../../shared/theme/quill_tokens.dart';
import '../../../../shared/theme/tokens.dart';
import '../../../../shared/widgets/quill_icon.dart';
import '../../../../shared/widgets/segment.dart';
import '../../../vault/presentation/widgets/page_header.dart';
import '../../data/repositories/database_repository_impl.dart';
import '../../domain/entities/database_schema.dart';
import '../../domain/repositories/database_repository.dart';
import '../widgets/board_view.dart';
import '../widgets/frozen_column_table.dart';
import '../widgets/gallery_view.dart';
import '../widgets/timeline_view.dart';

class DatabaseTablePage extends StatefulWidget {
  const DatabaseTablePage({super.key, required this.dbId, this.viewId});

  final String dbId;
  final String? viewId;

  @override
  State<DatabaseTablePage> createState() => _DatabaseTablePageState();
}

class _DatabaseTablePageState extends State<DatabaseTablePage> {
  late final Future<_DbData> _future;
  late final DatabaseRepository _repo;
  ViewType _currentView = ViewType.table;

  @override
  void initState() {
    super.initState();
    _repo = DatabaseRepositoryImpl(context.read<QuillDatabase>());
    _future = _load();
  }

  Future<_DbData> _load() async {
    final schema = await _repo.getDatabase(widget.dbId);
    if (schema == null) return const _DbData(schema: null, rows: []);
    final rows = await _repo.getRows(widget.dbId);
    final v = schema.viewById(widget.viewId);
    if (v != null) _currentView = v.type;
    return _DbData(schema: schema, rows: rows);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    return FutureBuilder<_DbData>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData) {
          return Center(
            child: SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 1.5, color: tokens.text2),
            ),
          );
        }
        final data = snap.data!;
        final schema = data.schema;
        if (schema == null) {
          return Center(
            child: Text('Database not found', style: TextStyle(color: tokens.text2)),
          );
        }
        return Column(
          children: [
            PageHeader(crumbs: ['Databases', schema.name]),
            Container(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: tokens.divider, width: 0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _parseColor(schema.color),
                        borderRadius: const BorderRadius.all(Radius.circular(4)),
                      ),
                      child: Text(
                        schema.icon,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      schema.name,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: tokens.text,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 2),
                  Padding(
                    padding: const EdgeInsets.only(left: 32),
                    child: Text(
                      '${data.rows.length} pages · ${schema.folderPath}/',
                      style: mono(fontSize: 12, color: tokens.text3),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(children: [
                    Segment<ViewType>(
                      value: _currentView,
                      onChanged: (v) => setState(() => _currentView = v),
                      options: const [
                        SegmentOption(value: ViewType.table, label: 'Table', icon: 'table'),
                        SegmentOption(value: ViewType.gallery, label: 'Gallery', icon: 'gallery'),
                        SegmentOption(value: ViewType.board, label: 'Board', icon: 'board'),
                        SegmentOption(value: ViewType.timeline, label: 'Timeline', icon: 'timeline'),
                      ],
                    ),
                    const Spacer(),
                    _ToolText(icon: 'filter', label: 'Filter'),
                    const SizedBox(width: 4),
                    _ToolText(icon: 'sort', label: 'Sort'),
                    const SizedBox(width: 4),
                    _ToolText(icon: 'group', label: 'Group'),
                    const SizedBox(width: 4),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: QuillIcon('search', size: 13, color: tokens.text3),
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      onPressed: () {},
                    ),
                  ]),
                ],
              ),
            ),
            Expanded(
              child: switch (_currentView) {
                ViewType.table => FrozenColumnTable(
                    schema: schema,
                    rows: data.rows,
                    onOpenPage: (row) => context.go('/editor/${row.ulid}'),
                  ),
                ViewType.gallery => GalleryView(schema: schema, rows: data.rows),
                ViewType.board => BoardView(
                    schema: schema,
                    rows: data.rows,
                    groupBy: schema.viewById(widget.viewId)?.groupBy,
                  ),
                ViewType.timeline => TimelineView(schema: schema, rows: data.rows),
              },
            ),
            // Footer rollups
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: tokens.divider, width: 0.5)),
              ),
              child: Row(
                children: [
                  Text(
                    'count ',
                    style: mono(fontSize: 11.5, color: tokens.text3),
                  ),
                  Text('${data.rows.length}', style: mono(fontSize: 11.5, color: tokens.text2)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  static Color _parseColor(String s) {
    var hex = s.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    final v = int.tryParse(hex, radix: 16);
    return Color(v ?? 0xFF6B8E7F);
  }
}

class _DbData {
  const _DbData({required this.schema, required this.rows});
  final DatabaseSchema? schema;
  final List<DatabasePageRow> rows;
}

class _ToolText extends StatelessWidget {
  const _ToolText({required this.icon, required this.label});
  final String icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          QuillIcon(icon, size: 13, strokeWidth: 1.7, color: tokens.text3),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 12.5, color: tokens.text2)),
        ],
      ),
    );
  }
}

