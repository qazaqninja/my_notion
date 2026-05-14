import 'dart:io';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;

import '../../../../core/db/quill_database.dart' hide Page;
import '../../../../shared/theme/quill_tokens.dart';
import '../../../../shared/widgets/emoji_picker.dart';
import '../../../../shared/widgets/quill_icon.dart';
import '../../../../shared/widgets/side_head.dart';
import '../../../../shared/widgets/side_item.dart';
import '../../../database/data/repositories/database_repository_impl.dart';
import '../../../database/domain/entities/database_schema.dart';
import '../bloc/vault_bloc.dart';
import '../bloc/vault_event.dart';
import '../bloc/vault_state.dart';
import 'sidebar_search.dart';
import 'tree_node_widget.dart';
import 'workspace_head.dart';

/// Full sidebar. Matches `Sidebar` from `shell.jsx:72-126`.
class SidebarWidget extends StatefulWidget {
  const SidebarWidget({super.key, this.activeUlid, this.width = 260});

  final String? activeUlid;
  final double width;

  @override
  State<SidebarWidget> createState() => _SidebarWidgetState();
}

class _SidebarWidgetState extends State<SidebarWidget> {
  final TextEditingController _treeFilter = TextEditingController();

  @override
  void initState() {
    super.initState();
    _treeFilter.addListener(_rebuildOnFilter);
  }

  @override
  void dispose() {
    _treeFilter.removeListener(_rebuildOnFilter);
    _treeFilter.dispose();
    super.dispose();
  }

  void _rebuildOnFilter() {
    if (!mounted) return;
    setState(() {});
  }

  String? get _activeUlid => widget.activeUlid;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    final state = context.watch<VaultBloc>().state;

    final workspaceName = state is VaultLoaded
        ? (state.workspace.name?.isNotEmpty == true
            ? state.workspace.name!
            : p.basename(state.rootPath).isNotEmpty
                ? p
                    .basename(state.rootPath)
                    .replaceAll(RegExp(r'_+'), ' ')
                    .replaceFirstMapped(
                      RegExp(r'^[a-z]'),
                      (m) => m.group(0)!.toUpperCase(),
                    )
                : 'Vault')
        : 'Vault';
    final vaultPath = state is VaultLoaded
        ? _abbreviateHome(state.rootPath)
        : 'No vault opened';
    final pageCount = state is VaultLoaded ? state.pageCount : 0;

    return Container(
      width: widget.width,
      decoration: BoxDecoration(
        color: tokens.sidebar,
        border: Border(right: BorderSide(color: tokens.divider, width: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WorkspaceHead(
            name: workspaceName,
            vaultPath: vaultPath,
            icon: state is VaultLoaded ? state.workspace.icon : null,
            onIconTap: state is VaultLoaded
                ? () => _pickWorkspaceIcon(context, state)
                : null,
          ),
          const SidebarSearch(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (state is VaultLoaded &&
                      state.workspace.favorites.isNotEmpty) ...[
                    const SideHead(label: 'Favorites'),
                    _FavoritesList(
                      ulids: state.workspace.favorites,
                      activeUlid: _activeUlid,
                      rebuildKey: '${state.rootPath}-${state.workspace.favorites.length}',
                    ),
                  ],
                  if (state is VaultLoaded) ...[
                    const SideHead(label: 'Recent'),
                    _RecentList(
                      rebuildKey: '${state.rootPath}-${state.pageCount}',
                      activeUlid: _activeUlid,
                    ),
                  ],
                  SideHead(
                    label: 'Workspace',
                    actionIcon: 'plus',
                    onAction: state is VaultLoaded
                        ? () => _promptNewPage(context)
                        : null,
                  ),
                  if (state is VaultLoaded)
                    _TreeFilterField(controller: _treeFilter),
                  TreeRoot(
                    activeUlid: _activeUlid,
                    filter: _treeFilter.text.trim(),
                  ),
                  const SideHead(label: 'Databases', actionIcon: 'plus'),
                  if (state is VaultLoaded)
                    _DatabasesList(rebuildKey: state.rootPath)
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Text(
                        'No vault opened',
                        style: TextStyle(fontSize: 11.5, color: tokens.text3),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Footer: sync status + gear
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: tokens.divider, width: 0.5)),
            ),
            child: Row(
              children: [
                QuillIcon('sync', size: 12, strokeWidth: 1.7, color: tokens.text3),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    state is VaultLoaded ? '$pageCount pages indexed' : 'No vault',
                    style: TextStyle(fontSize: 11.5, color: tokens.text3),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: () => context.go('/settings'),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: QuillIcon('gear', size: 13, strokeWidth: 1.7, color: tokens.text3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickWorkspaceIcon(
      BuildContext context, VaultLoaded state) async {
    final picked = await pickEmoji(context);
    if (picked == null) return;
    final next = state.workspace.copyWith(icon: picked.isEmpty ? '' : picked);
    await next.save(Directory(state.rootPath));
    if (!context.mounted) return;
    context.read<VaultBloc>().add(const RefreshFromDisk());
  }

  Future<void> _promptNewPage(BuildContext context) async {
    final controller = TextEditingController();
    final router = GoRouter.of(context);
    final bloc = context.read<VaultBloc>();
    final title = await showDialog<String>(
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
    if (title == null || title.trim().isEmpty) return;
    bloc.add(CreatePage(
      title: title.trim(),
      onCreated: (ulid) => router.go('/editor/$ulid'),
    ));
  }

  String _abbreviateHome(String path) {
    final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '';
    if (home.isNotEmpty && path.startsWith(home)) {
      return '~${path.substring(home.length)}';
    }
    return path;
  }
}

/// Inline search input that filters the vault tree by name. Setting
/// text rebuilds the tree with the new query; clearing returns to the
/// full tree. Owned by SidebarWidget so the query persists while the
/// user switches between pages.
class _TreeFilterField extends StatelessWidget {
  const _TreeFilterField({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: tokens.inputBg,
          border: Border.all(color: tokens.divider2, width: 0.5),
          borderRadius: const BorderRadius.all(Radius.circular(4)),
        ),
        child: Row(
          children: [
            QuillIcon('filter',
                size: 11, strokeWidth: 1.7, color: tokens.text3),
            const SizedBox(width: 6),
            Expanded(
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (_, val, __) => TextField(
                  controller: controller,
                  style: TextStyle(fontSize: 11.5, color: tokens.text),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                    hintText: 'Filter tree',
                    hintStyle: TextStyle(fontSize: 11.5, color: tokens.text3),
                  ),
                ),
              ),
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (_, val, __) => val.text.isEmpty
                  ? const SizedBox.shrink()
                  : GestureDetector(
                      onTap: () => controller.clear(),
                      child: Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Icon(Icons.close,
                            size: 11, color: tokens.text3),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DatabasesList extends StatelessWidget {
  const _DatabasesList({required this.rebuildKey});
  final String rebuildKey;

  Future<({List<DatabaseSchema> dbs, Map<String, int> counts})>
      _load(QuillDatabase db) async {
    final repo = DatabaseRepositoryImpl(db);
    final dbs = await repo.listDatabases();
    final counts = <String, int>{};
    for (final s in dbs) {
      final rows = await (db.select(db.pages)
            ..where((p) => p.databaseId.equals(s.id)))
          .get();
      counts[s.id] = rows.length;
    }
    return (dbs: dbs, counts: counts);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    final qdb = context.read<QuillDatabase>();
    return FutureBuilder<({List<DatabaseSchema> dbs, Map<String, int> counts})>(
      key: ValueKey('dbs-$rebuildKey'),
      future: _load(qdb),
      builder: (context, snap) {
        final dbs = snap.data?.dbs ?? const [];
        if (dbs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              'No databases yet',
              style: TextStyle(fontSize: 11.5, color: tokens.text3),
            ),
          );
        }
        final counts = snap.data?.counts ?? const <String, int>{};
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final db in dbs)
              SideItem(
                glyph: SideItemGlyph(
                  color: _parseColor(db.color),
                  letter: db.icon.isNotEmpty ? db.icon.substring(0, 1) : 'D',
                ),
                label: db.name,
                count: counts[db.id],
                onTap: () => context.go('/db/${db.id}'),
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

/// Pinned pages, ordered as declared in `.quill.yaml`'s `favorites:`.
class _FavoritesList extends StatelessWidget {
  const _FavoritesList({
    required this.ulids,
    required this.rebuildKey,
    this.activeUlid,
  });
  final List<String> ulids;
  final String rebuildKey;
  final String? activeUlid;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    final db = context.read<QuillDatabase>();
    return FutureBuilder(
      key: ValueKey('favorites-$rebuildKey'),
      future: (db.select(db.pages)..where((p) => p.ulid.isIn(ulids))).get(),
      builder: (context, snap) {
        final rows = snap.data ?? const [];
        if (rows.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              'No favorites',
              style: TextStyle(fontSize: 11.5, color: tokens.text3),
            ),
          );
        }
        // Preserve declared order from `ulids` (the IN query loses it).
        final byUlid = {for (final r in rows) r.ulid: r};
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final ulid in ulids)
              if (byUlid.containsKey(ulid))
                SideItem(
                  icon: 'star',
                  label: byUlid[ulid]!.title,
                  active: ulid == activeUlid,
                  onTap: () => context.go('/editor/$ulid'),
                  trailingOnHover: GestureDetector(
                    onTap: () => context
                        .read<VaultBloc>()
                        .add(ToggleFavorite(ulid)),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(Icons.close,
                            size: 12, color: tokens.text3),
                      ),
                    ),
                  ),
                ),
          ],
        );
      },
    );
  }
}

/// Top-N most-recently-edited pages, sourced from drift's pages.mtime_ms.
/// No persistence needed — drift is the source of truth (and reflects
/// external edits via the M16 file watcher).
class _RecentList extends StatelessWidget {
  const _RecentList({required this.rebuildKey, this.activeUlid});
  final String rebuildKey;
  final String? activeUlid;

  static const int _limit = 5;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    final db = context.read<QuillDatabase>();
    return FutureBuilder(
      key: ValueKey('recent-$rebuildKey'),
      future: (db.select(db.pages)
            ..orderBy([(p) => OrderingTerm.desc(p.mtimeMs)])
            ..limit(_limit))
          .get(),
      builder: (context, snap) {
        final rows = snap.data ?? const [];
        if (rows.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              'No recent pages',
              style: TextStyle(fontSize: 11.5, color: tokens.text3),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final r in rows)
              SideItem(
                icon: 'file-md',
                label: r.title,
                active: r.ulid == activeUlid,
                onTap: () => context.go('/editor/${r.ulid}'),
              ),
          ],
        );
      },
    );
  }
}
