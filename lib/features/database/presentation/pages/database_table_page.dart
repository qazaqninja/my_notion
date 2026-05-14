import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/db/quill_database.dart' hide Page;
import '../../../../shared/theme/quill_tokens.dart';
import '../../../../shared/theme/tokens.dart';
import '../../../../shared/widgets/quill_icon.dart';
import '../../../../shared/widgets/responsive_layout.dart';
import '../../../../shared/widgets/segment.dart';
import '../../../vault/data/indexer.dart';
import '../../../vault/domain/repositories/vault_repository.dart';
import '../../../vault/presentation/bloc/vault_bloc.dart';
import '../../../vault/presentation/bloc/vault_event.dart';
import '../../../vault/presentation/bloc/vault_state.dart';
import '../../../vault/presentation/widgets/page_header.dart';
import '../../data/datasources/csv_exporter.dart';
import '../../data/repositories/database_repository_impl.dart';
import '../../domain/entities/database_query.dart';
import '../../domain/entities/database_schema.dart';
import '../../domain/repositories/database_repository.dart';
import '../../domain/usecases/apply_query.dart';
import '../widgets/board_view.dart';
import '../widgets/calendar_view.dart';
import '../widgets/chart_view.dart';
import '../widgets/frozen_column_table.dart';
import '../widgets/gallery_view.dart';
import '../widgets/list_view.dart';
import '../widgets/query_popovers.dart';
import '../widgets/timeline_view.dart';

class DatabaseTablePage extends StatefulWidget {
  const DatabaseTablePage({super.key, required this.dbId, this.viewId});

  final String dbId;
  final String? viewId;

  @override
  State<DatabaseTablePage> createState() => _DatabaseTablePageState();
}

class _DatabaseTablePageState extends State<DatabaseTablePage> {
  late final DatabaseRepository _repo;
  ViewType _currentView = ViewType.table;
  DatabaseSchema? _schema;
  List<DatabasePageRow>? _rows;
  String? _error;
  DatabaseQuery _query = const DatabaseQuery();
  bool _wrap = false;
  Set<String>? _visibleOverride;

  String get _wrapPrefKey => 'db.${widget.dbId}.wrap';
  String get _visiblePrefKey => 'db.${widget.dbId}.visible';

  @override
  void initState() {
    super.initState();
    _repo = DatabaseRepositoryImpl(
      context.read<QuillDatabase>(),
      vault: context.read<VaultRepository>(),
      indexer: context.read<Indexer>(),
    );
    _restorePrefs();
    _load();
  }

  Future<void> _restorePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final wrap = prefs.getBool(_wrapPrefKey);
    final visible = prefs.getStringList(_visiblePrefKey);
    setState(() {
      if (wrap != null) _wrap = wrap;
      if (visible != null) _visibleOverride = visible.toSet();
    });
  }

  Future<void> _setWrap(bool next) async {
    setState(() => _wrap = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_wrapPrefKey, next);
  }

  Future<void> _setVisibleOverride(Set<String>? next) async {
    setState(() => _visibleOverride = next);
    final prefs = await SharedPreferences.getInstance();
    if (next == null) {
      await prefs.remove(_visiblePrefKey);
    } else {
      await prefs.setStringList(_visiblePrefKey, next.toList());
    }
  }

  Future<void> _load() async {
    try {
      final schema = await _repo.getDatabase(widget.dbId);
      if (schema == null) {
        if (mounted) setState(() => _error = 'Database not found');
        return;
      }
      final rows = await _repo.getRows(widget.dbId);
      final v = schema.viewById(widget.viewId);
      if (!mounted) return;
      setState(() {
        _schema = schema;
        _rows = rows;
        if (v != null) {
          _currentView = v.type;
          if (v.groupBy != null) {
            _query = _query.copyWith(groupBy: v.groupBy);
          }
        }
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Directory? _vaultRoot() {
    final s = context.read<VaultBloc>().state;
    return s is VaultLoaded ? Directory(s.rootPath) : null;
  }

  Future<void> _editCell(DatabasePageRow row, ColumnDef column, Object? value) async {
    final root = _vaultRoot();
    if (root == null) return;
    try {
      final updated = await _repo.updateCell(
        ulid: row.ulid,
        column: column,
        newValue: value,
        vaultRoot: root,
      );
      if (!mounted) return;
      setState(() {
        _rows = [
          for (final r in _rows ?? const <DatabasePageRow>[])
            if (r.ulid == row.ulid) updated else r,
        ];
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text('Cell update failed: $e')),
      );
    }
  }

  void _duplicateRow(DatabasePageRow row) {
    final schema = _schema;
    if (schema == null) return;
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    context.read<VaultBloc>().add(DuplicatePage(
          row.ulid,
          targetFolder: schema.folderPath,
          onCreated: (newUlid) {
            messenger?.showSnackBar(
              const SnackBar(
                content: Text('Row duplicated'),
                duration: Duration(seconds: 2),
              ),
            );
            router.go('/editor/$newUlid');
          },
        ));
  }

  Future<void> _createRow() async {
    final root = _vaultRoot();
    final schema = _schema;
    if (root == null || schema == null) return;
    final title = await _promptForTitle();
    if (title == null || title.trim().isEmpty) return;
    try {
      final row = await _repo.createRow(
        schema: schema,
        title: title.trim(),
        vaultRoot: root,
      );
      if (!mounted) return;
      setState(() => _rows = [...?_rows, row]);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text('Create failed: $e')),
      );
    }
  }

  Future<String?> _promptForTitle() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New page'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Title'),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, style: TextStyle(color: tokens.text2)),
        ),
      );
    }
    if (_schema == null || _rows == null) {
      return Center(
        child: SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 1.5, color: tokens.text2),
        ),
      );
    }
    final schema = _schema!;
    final rows = _rows!;
    return Builder(
      builder: (context) {
        final mobile = isMobileWidth(context);
        return Column(
          children: [
            PageHeader(crumbs: ['Databases', schema.name]),
            Container(
              padding: EdgeInsets.fromLTRB(mobile ? 12 : 24, 18, mobile ? 12 : 24, 12),
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
                      '${rows.length} pages · ${schema.folderPath}/',
                      style: mono(fontSize: 12, color: tokens.text3),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (mobile)
                    Wrap(
                      spacing: 6,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: _toolbarChildren(schema, tokens, mobile: true),
                    )
                  else
                    Row(children: _toolbarChildren(schema, tokens, mobile: false)),
                ],
              ),
            ),
            Expanded(
              child: Builder(builder: (context) {
                final filtered = ApplyQuery.apply(rows, _query, schema);
                // Honour `views[].visible:` — restrict columns shown by
                // table/gallery/etc. ApplyQuery already ran on the full
                // schema so filter/sort/group can reference hidden cols.
                final activeView = schema.viewById(widget.viewId);
                final visibleKeys = _visibleOverride ??
                    (activeView?.visible == null
                        ? null
                        : activeView!.visible!.toSet());
                final viewSchema = schema.filterColumns(visibleKeys);
                return switch (_currentView) {
                  ViewType.table => FrozenColumnTable(
                      schema: viewSchema,
                      rows: filtered,
                      onOpenPage: (row) => context.go('/editor/${row.ulid}'),
                      onEditCell: _editCell,
                      onCreateRow: _createRow,
                      onDuplicateRow: _duplicateRow,
                      wrap: _wrap,
                      persistKey: widget.dbId,
                    ),
                  ViewType.gallery =>
                    GalleryView(schema: viewSchema, rows: filtered),
                  ViewType.board => BoardView(
                      schema: viewSchema,
                      rows: filtered,
                      groupBy: _query.groupBy ?? activeView?.groupBy,
                      subGroupBy: _query.subGroupBy,
                    ),
                  ViewType.timeline =>
                    TimelineView(schema: viewSchema, rows: filtered),
                  ViewType.calendar =>
                    CalendarView(schema: viewSchema, rows: filtered),
                  ViewType.chart =>
                    ChartView(schema: viewSchema, rows: filtered),
                  ViewType.list =>
                    DatabaseListView(schema: viewSchema, rows: filtered),
                };
              }),
            ),
            // Footer rollups
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: tokens.divider, width: 0.5)),
              ),
              child: Builder(builder: (context) {
                final visibleCount =
                    ApplyQuery.apply(rows, _query, schema).length;
                return Row(
                  children: [
                    Text(
                      'count ',
                      style: mono(fontSize: 11.5, color: tokens.text3),
                    ),
                    Text('$visibleCount',
                        style: mono(fontSize: 11.5, color: tokens.text2)),
                    if (visibleCount != rows.length) ...[
                      Text(' of ',
                          style: mono(fontSize: 11.5, color: tokens.text3)),
                      Text('${rows.length}',
                          style: mono(fontSize: 11.5, color: tokens.text3)),
                    ],
                  ],
                );
              }),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _toolbarChildren(DatabaseSchema schema, QuillTokens tokens, {required bool mobile}) {
    return [
      Segment<ViewType>(
        value: _currentView,
        onChanged: (v) => setState(() => _currentView = v),
        options: const [
          SegmentOption(value: ViewType.table, label: 'Table', icon: 'table'),
          SegmentOption(value: ViewType.list, label: 'List', icon: 'note'),
          SegmentOption(value: ViewType.gallery, label: 'Gallery', icon: 'gallery'),
          SegmentOption(value: ViewType.board, label: 'Board', icon: 'board'),
          SegmentOption(value: ViewType.timeline, label: 'Timeline', icon: 'timeline'),
          SegmentOption(value: ViewType.calendar, label: 'Calendar', icon: 'calendar'),
          SegmentOption(value: ViewType.chart, label: 'Chart', icon: 'chart'),
        ],
      ),
      if (!mobile) const Spacer(),
      _ToolButton(
        icon: 'filter',
        label: _query.filters.isEmpty ? 'Filter' : 'Filter (${_query.filters.length})',
        active: _query.filters.isNotEmpty,
        onTap: () => _openFilterPopover(context, schema),
      ),
      if (!mobile) const SizedBox(width: 4),
      _ToolButton(
        icon: 'sort',
        label: _query.sorts.isEmpty ? 'Sort' : 'Sort (${_query.sorts.length})',
        active: _query.sorts.isNotEmpty,
        onTap: () => _openSortPopover(context, schema),
      ),
      if (!mobile) const SizedBox(width: 4),
      _ToolButton(
        icon: 'group',
        label: _query.groupBy == null
            ? 'Group'
            : _query.subGroupBy == null
                ? 'Group: ${_query.groupBy}'
                : 'Group: ${_query.groupBy} › ${_query.subGroupBy}',
        active: _query.groupBy != null,
        onTap: () => _openGroupPopover(context, schema),
      ),
      if (!mobile) const SizedBox(width: 4),
      _ToolButton(
        icon: 'settings',
        label: _visibleOverride == null
            ? 'Properties'
            : 'Properties (${_visibleOverride!.length + 1})',
        active: _visibleOverride != null,
        onTap: () => _openPropertiesPopover(context, schema),
      ),
      if (!mobile) const SizedBox(width: 4),
      IconButton(
        visualDensity: VisualDensity.compact,
        icon: Icon(
          _wrap ? Icons.wrap_text : Icons.short_text,
          size: 14,
          color: _wrap ? tokens.accent : tokens.text3,
        ),
        padding: const EdgeInsets.all(4),
        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        onPressed: () => _setWrap(!_wrap),
        tooltip: _wrap ? 'Truncate cells' : 'Wrap cells',
      ),
      if (!mobile) const SizedBox(width: 4),
      IconButton(
        visualDensity: VisualDensity.compact,
        icon: QuillIcon('export', size: 13, color: tokens.text3),
        padding: const EdgeInsets.all(4),
        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        onPressed: () => _exportCsv(schema),
        tooltip: 'Export CSV',
      ),
    ];
  }

  Future<void> _exportCsv(DatabaseSchema schema) async {
    final rows = _rows;
    if (rows == null) return;
    final filtered = ApplyQuery.apply(rows, _query, schema);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final picked = await FilePicker.platform.saveFile(
      dialogTitle: 'Save CSV…',
      fileName: '${schema.name}.csv',
      type: FileType.custom,
      allowedExtensions: const ['csv'],
    );
    if (picked == null) return;
    try {
      final n = await const CsvExporter().export(
        destination: File(picked),
        schema: schema,
        rows: filtered,
      );
      messenger?.showSnackBar(
        SnackBar(content: Text('Exported $n rows → $picked')),
      );
    } catch (e) {
      messenger?.showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  Future<void> _openFilterPopover(BuildContext ctx, DatabaseSchema schema) async {
    final next = await showQueryPopover<List<FilterRule>>(
      context: ctx,
      child: FilterPopover(
        schema: schema,
        initial: _query.filters,
      ),
    );
    if (next == null) return;
    setState(() => _query = _query.copyWith(filters: next));
  }

  Future<void> _openSortPopover(BuildContext ctx, DatabaseSchema schema) async {
    final next = await showQueryPopover<List<SortRule>>(
      context: ctx,
      child: SortPopover(
        schema: schema,
        initial: _query.sorts,
      ),
    );
    if (next == null) return;
    setState(() => _query = _query.copyWith(sorts: next));
  }

  Future<void> _openGroupPopover(BuildContext ctx, DatabaseSchema schema) async {
    final next = await showQueryPopover<GroupPopoverResult>(
      context: ctx,
      child: GroupPopover(
        schema: schema,
        initial: _query.groupBy,
        initialSub: _query.subGroupBy,
      ),
    );
    if (next == null) return;
    setState(() => _query = _query.copyWith(
          groupBy: next.value,
          subGroupBy: next.sub,
        ));
  }

  Future<void> _openPropertiesPopover(
      BuildContext ctx, DatabaseSchema schema) async {
    final activeView = schema.viewById(widget.viewId);
    final initial = _visibleOverride ??
        (activeView?.visible == null
            ? null
            : activeView!.visible!.toSet());
    final next = await showQueryPopover<PropertiesPopoverResult>(
      context: ctx,
      child: PropertiesPopover(schema: schema, initial: initial),
    );
    if (next == null) return;
    await _setVisibleOverride(next.visible);
  }

  static Color _parseColor(String s) {
    var hex = s.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    final v = int.tryParse(hex, radix: 16);
    return Color(v ?? 0xFF6B8E7F);
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });
  final String icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: active
              ? BoxDecoration(
                  color: tokens.accentTint,
                  borderRadius: const BorderRadius.all(Radius.circular(4)),
                )
              : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              QuillIcon(
                icon,
                size: 13,
                strokeWidth: 1.7,
                color: active ? tokens.accent : tokens.text3,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  color: active ? tokens.accent : tokens.text2,
                  fontWeight: active ? FontWeight.w500 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


