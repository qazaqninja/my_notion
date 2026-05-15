import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/db/quill_database.dart' hide Page;
import '../../../../shared/theme/quill_tokens.dart';
import '../../../../shared/theme/tokens.dart';
import '../../../../shared/widgets/emoji_picker.dart';
import '../../../../shared/widgets/quill_icon.dart';
import '../../../../shared/widgets/quill_overlays.dart';
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
import '../../domain/usecases/rollup_compute.dart';
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

  /// Right-click on a column header opens a context menu with quick
  /// actions: sort asc / desc / clear, group / ungroup, hide column.
  Future<void> _showColumnContextMenu(
      String columnKey, Offset globalPosition) async {
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;
    final isGrouped = _query.groupBy == columnKey;
    final isHidden =
        _visibleOverride != null && !_visibleOverride!.contains(columnKey);
    final action = await showQuillMenu<String>(
      context: context,
      position: quillMenuPosition(context, globalPosition),
      width: 232,
      items: [
        const QuillMenuItem(icon: 'sort', label: 'Sort ascending', value: 'sort-asc'),
        const QuillMenuItem(icon: 'sort', label: 'Sort descending', value: 'sort-desc'),
        const QuillMenuItem(icon: 'sort', label: 'Clear sort', value: 'sort-clear'),
        QuillMenuItem.separator<String>(),
        QuillMenuItem(
          icon: 'group',
          label: isGrouped ? 'Ungroup' : 'Group by this column',
          value: 'group',
        ),
        const QuillMenuItem(icon: 'filter', label: 'Filter by this column…', value: 'filter'),
        QuillMenuItem.separator<String>(),
        if (!isHidden && columnKey != 'title')
          const QuillMenuItem(icon: 'eye', label: 'Hide column', value: 'hide'),
      ],
    );
    if (action == null) return;
    switch (action) {
      case 'sort-asc':
        setState(() => _query = _query.copyWith(
              sorts: [SortRule(columnKey: columnKey, ascending: true)],
            ));
      case 'sort-desc':
        setState(() => _query = _query.copyWith(
              sorts: [SortRule(columnKey: columnKey, ascending: false)],
            ));
      case 'sort-clear':
        setState(() => _query = _query.copyWith(sorts: const []));
      case 'group':
        setState(() => _query =
            _query.copyWith(groupBy: isGrouped ? null : columnKey));
      case 'filter':
        if (!mounted || _schema == null) return;
        if (!context.mounted) return;
        await _openFilterPopover(context, _schema!);
      case 'hide':
        final current = _visibleOverride ??
            {for (final c in (_schema?.columns ?? const [])) c.key};
        final next = {...current}..remove(columnKey);
        await _setVisibleOverride(next);
        if (!mounted) return;
        context.toastSuccess('Hid column "$columnKey"',
            sub: 'Open the Properties popover to show it again');
    }
  }

  /// Click cycles `<col>` through asc → desc → off and replaces any prior
  /// sort on a different column. Only one sort is held at a time — multi-
  /// column sort is shift-click or the popover (not wired yet).
  void _cycleSort(String columnKey) {
    setState(() {
      final current = _query.sorts.isEmpty ? null : _query.sorts.first;
      final List<SortRule> next;
      if (current == null || current.columnKey != columnKey) {
        next = [SortRule(columnKey: columnKey, ascending: true)];
      } else if (current.ascending) {
        next = [SortRule(columnKey: columnKey, ascending: false)];
      } else {
        next = const [];
      }
      _query = _query.copyWith(sorts: next);
    });
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
    } on PageLockedException {
      if (!mounted) return;
      context.toastInfo('Row is locked',
          sub: row.title.isEmpty
              ? 'Unlock the page (⌘⇧L) to edit cells'
              : '"${row.title}" — unlock the page (⌘⇧L) to edit cells');
    } catch (e) {
      if (!mounted) return;
      context.toastError('Cell update failed', sub: '$e');
    }
  }

  Future<void> _trashRow(DatabasePageRow row) async {
    final now = DateTime.now();
    final bucket =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final confirmed = await showQuillConfirm(
      context,
      title: 'Move row to trash?',
      sub:
          'The .md file moves to .trash/$bucket/. You can restore it from the Trash dialog later.',
      icon: 'trash',
      confirmLabel: 'Move to trash',
      danger: true,
    );
    if (!confirmed || !mounted) return;
    if (!context.mounted) return;
    context.read<VaultBloc>().add(MoveToTrash(row.ulid));
    context.toastSuccess('Moved to trash',
        sub: row.title.isEmpty ? '(Untitled row)' : row.title);
    setState(() => _rows = _rows?.where((r) => r.ulid != row.ulid).toList());
  }

  void _duplicateRow(DatabasePageRow row) {
    final schema = _schema;
    if (schema == null) return;
    final router = GoRouter.of(context);
    final scope = context;
    final sourceTitle = row.title;
    context.read<VaultBloc>().add(DuplicatePage(
          row.ulid,
          targetFolder: schema.folderPath,
          onCreated: (newUlid) {
            if (scope.mounted) {
              scope.toastSuccess(
                  sourceTitle.isEmpty
                      ? 'Row duplicated'
                      : 'Duplicated "$sourceTitle"',
                  sub: 'New ULID: $newUlid',
                  subMono: true);
            }
            router.go('/editor/$newUlid');
          },
        ));
  }

  Future<void> _createRow() async {
    final root = _vaultRoot();
    final schema = _schema;
    if (root == null || schema == null) return;
    final title = await _promptForTitle();
    if (title == null || title.isEmpty) return;
    try {
      final row = await _repo.createRow(
        schema: schema,
        title: title,
        vaultRoot: root,
      );
      if (!mounted) return;
      setState(() => _rows = [...?_rows, row]);
      context.toastSuccess('Created "${row.title}"',
          sub: 'ULID: ${row.ulid}', subMono: true);
    } catch (e) {
      if (!mounted) return;
      context.toastError('Create failed', sub: '$e');
    }
  }

  Future<String?> _promptForTitle() async {
    return showQuillPrompt(
      context,
      title: 'New page',
      icon: 'file-md',
      label: 'Title',
      confirmLabel: 'Create',
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_outlined,
                  size: 28, color: const Color(0xFFCB5A4F)),
              const SizedBox(height: 10),
              Text('Could not load database',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: tokens.text2)),
              const SizedBox(height: 6),
              Text(_error!,
                  style: TextStyle(
                      color: tokens.text3, fontSize: 13, height: 1.5)),
              const SizedBox(height: 14),
              Row(children: [
                TextButton(
                  onPressed: () => context.go('/databases'),
                  child: const Text('Browse databases'),
                ),
                const SizedBox(width: 4),
                TextButton(
                  onPressed: () =>
                      context.read<VaultBloc>().add(const ReindexVault()),
                  child: const Text('Reindex vault'),
                ),
              ]),
            ],
          ),
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
                        color: looksLikeEmoji(schema.icon)
                            ? Colors.transparent
                            : _parseColor(schema.color),
                        borderRadius: const BorderRadius.all(Radius.circular(4)),
                      ),
                      child: Text(
                        schema.icon,
                        style: TextStyle(
                          color: looksLikeEmoji(schema.icon)
                              ? null
                              : Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize:
                              looksLikeEmoji(schema.icon) ? 18 : 13,
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
                    if (schema.locked) ...[
                      const SizedBox(width: 10),
                      Tooltip(
                        message:
                            'Database is locked — set locked: false in '
                            '${schema.folderPath}/.database.yaml to edit.',
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: tokens.surface2,
                            borderRadius:
                                const BorderRadius.all(Radius.circular(4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.lock_outline,
                                  size: 11, color: tokens.text2),
                              const SizedBox(width: 4),
                              Text('locked',
                                  style: TextStyle(
                                      fontSize: 11, color: tokens.text2)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 2),
                  Padding(
                    padding: const EdgeInsets.only(left: 32),
                    child: Tooltip(
                      message:
                          'Schema: ${schema.folderPath}/.database.yaml',
                      waitDuration: const Duration(milliseconds: 600),
                      child: Text(
                        '${rows.length} ${rows.length == 1 ? 'page' : 'pages'} · ${schema.folderPath}/',
                        style: mono(fontSize: 12, color: tokens.text3),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
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
                final withRollups = RollupCompute.apply(rows, schema);
                final filtered =
                    ApplyQuery.apply(withRollups, _query, schema);
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
                  // On mobile the frozen-column + horizontal-scroll
                  // table is awkward — drop down to the compact list
                  // rendering automatically. Other views are already
                  // mobile-friendly.
                  ViewType.table when mobile => DatabaseListView(
                      schema: viewSchema,
                      rows: filtered,
                      subGroupBy: _query.subGroupBy,
                    ),
                  ViewType.table => FrozenColumnTable(
                      schema: viewSchema,
                      rows: filtered,
                      onOpenPage: (row) => context.go('/editor/${row.ulid}'),
                      onEditCell: schema.locked ? null : _editCell,
                      onCreateRow: schema.locked ? null : _createRow,
                      onDuplicateRow: schema.locked ? null : _duplicateRow,
                      onTrashRow: schema.locked ? null : _trashRow,
                      wrap: _wrap,
                      persistKey: widget.dbId,
                      subGroupBy: _query.subGroupBy,
                      sortColumn: _query.sorts.isEmpty
                          ? null
                          : _query.sorts.first.columnKey,
                      sortAscending: _query.sorts.isEmpty
                          ? true
                          : _query.sorts.first.ascending,
                      onColumnHeaderTap: _cycleSort,
                      onColumnHeaderSecondaryTap: _showColumnContextMenu,
                    ),
                  ViewType.gallery => GalleryView(
                      schema: viewSchema,
                      rows: filtered,
                      cardFields: activeView?.cardFields,
                      subGroupBy: _query.subGroupBy,
                    ),
                  ViewType.board => BoardView(
                      schema: viewSchema,
                      rows: filtered,
                      groupBy: _query.groupBy ?? activeView?.groupBy,
                      subGroupBy: _query.subGroupBy,
                    ),
                  ViewType.timeline =>
                    TimelineView(
                      schema: viewSchema,
                      rows: filtered,
                      subGroupBy: _query.subGroupBy,
                    ),
                  ViewType.calendar =>
                    CalendarView(
                      schema: viewSchema,
                      rows: filtered,
                      subGroupBy: _query.subGroupBy,
                    ),
                  ViewType.chart =>
                    ChartView(
                      schema: viewSchema,
                      rows: filtered,
                      subGroupBy: _query.subGroupBy,
                    ),
                  ViewType.list => DatabaseListView(
                      schema: viewSchema,
                      rows: filtered,
                      subGroupBy: _query.subGroupBy,
                    ),
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
                final filtered = visibleCount != rows.length;
                return Tooltip(
                  message: filtered
                      ? '$visibleCount of ${rows.length} ${rows.length == 1 ? "row" : "rows"} match the active filters'
                      : visibleCount == 1
                          ? '1 row in this database'
                          : '$visibleCount rows in this database',
                  waitDuration: const Duration(milliseconds: 500),
                  child: Row(
                    children: [
                      Text(
                        'count ',
                        style: mono(fontSize: 11.5, color: tokens.text3),
                      ),
                      Text('$visibleCount',
                          style: mono(fontSize: 11.5, color: tokens.text2)),
                      if (filtered) ...[
                        Text(' of ',
                            style: mono(fontSize: 11.5, color: tokens.text3)),
                        Text('${rows.length}',
                            style: mono(fontSize: 11.5, color: tokens.text3)),
                      ],
                    ],
                  ),
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
          SegmentOption(
              value: ViewType.table,
              label: 'Table',
              icon: 'table',
              tooltip: 'Rows × columns with sort, filter, footer aggregations'),
          SegmentOption(
              value: ViewType.list,
              label: 'List',
              icon: 'note',
              tooltip: 'Single-line rows; compact reading view'),
          SegmentOption(
              value: ViewType.gallery,
              label: 'Gallery',
              icon: 'gallery',
              tooltip: 'Cards with cover image, icon + title'),
          SegmentOption(
              value: ViewType.board,
              label: 'Board',
              icon: 'board',
              tooltip: 'Kanban columns grouped by a select column'),
          SegmentOption(
              value: ViewType.timeline,
              label: 'Timeline',
              icon: 'timeline',
              tooltip: 'Bars per row by date with dependency arrows'),
          SegmentOption(
              value: ViewType.calendar,
              label: 'Calendar',
              icon: 'calendar',
              tooltip: 'Month grid; click a day to see its rows'),
          SegmentOption(
              value: ViewType.chart,
              label: 'Chart',
              icon: 'chart',
              tooltip: 'Bar chart of row counts grouped by a select column'),
        ],
      ),
      if (!mobile) const Spacer(),
      _ToolButton(
        icon: 'filter',
        label: _query.filters.isEmpty ? 'Filter' : 'Filter (${_query.filters.length})',
        active: _query.filters.isNotEmpty,
        tooltip: _query.filters.isEmpty
            ? 'Filter rows'
            : _query.filters.length == 1
                ? '1 active filter'
                : '${_query.filters.length} active filters',
        onTap: () => _openFilterPopover(context, schema),
      ),
      if (!mobile) const SizedBox(width: 4),
      _ToolButton(
        icon: 'sort',
        label: _query.sorts.isEmpty ? 'Sort' : 'Sort (${_query.sorts.length})',
        active: _query.sorts.isNotEmpty,
        tooltip: _query.sorts.isEmpty
            ? 'Sort rows'
            : _query.sorts.length == 1
                ? '1 active sort'
                : '${_query.sorts.length} active sorts',
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
        tooltip: _query.groupBy == null
            ? 'Group rows by a column'
            : _query.subGroupBy == null
                ? 'Grouped by ${_query.groupBy}'
                : 'Grouped by ${_query.groupBy} › ${_query.subGroupBy}',
        onTap: () => _openGroupPopover(context, schema),
      ),
      if (!mobile) const SizedBox(width: 4),
      _ToolButton(
        icon: 'settings',
        label: _visibleOverride == null
            ? 'Properties'
            : 'Properties (${_visibleOverride!.length + 1})',
        active: _visibleOverride != null,
        tooltip: 'Choose which columns are visible',
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
      if (mounted) {
        context.toastSuccess(
          'Exported $n ${n == 1 ? 'row' : 'rows'}',
          sub: picked,
          subMono: true,
        );
      }
    } catch (e) {
      if (mounted) context.toastError('Export failed', sub: '$e');
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

class _ToolButton extends StatefulWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.tooltip,
  });
  final String icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  /// Optional hover hint. When null, no tooltip is shown — the label
  /// already names the action.
  final String? tooltip;

  @override
  State<_ToolButton> createState() => _ToolButtonState();
}

class _ToolButtonState extends State<_ToolButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    final active = widget.active;
    Widget btn = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: active
              ? BoxDecoration(
                  color: tokens.accentTint,
                  borderRadius: const BorderRadius.all(Radius.circular(4)),
                )
              : _hover
                  ? BoxDecoration(
                      color: tokens.hover,
                      borderRadius:
                          const BorderRadius.all(Radius.circular(4)),
                    )
                  : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              QuillIcon(
                widget.icon,
                size: 13,
                strokeWidth: 1.7,
                color: active
                    ? tokens.accent
                    : (_hover ? tokens.text2 : tokens.text3),
              ),
              const SizedBox(width: 5),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 12.5,
                  color: active
                      ? tokens.accent
                      : (_hover ? tokens.text : tokens.text2),
                  fontWeight: active ? FontWeight.w500 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (widget.tooltip != null) {
      btn = Tooltip(
        message: widget.tooltip!,
        waitDuration: const Duration(milliseconds: 500),
        child: btn,
      );
    }
    return btn;
  }
}


