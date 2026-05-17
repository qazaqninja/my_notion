import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/db/quill_database.dart' hide Page;
import '../../../../core/platform/reveal.dart';
import '../../../../shared/theme/quill_tokens.dart';
import '../../../../shared/theme/tag_colors.dart';
import '../../../../shared/theme/tokens.dart';
import '../../../../shared/widgets/quill_overlays.dart';
import '../../../../shared/widgets/segment.dart';
import '../../../../shared/widgets/person_chip.dart';
import '../../../../shared/widgets/tag_chip.dart';
import '../../../../shared/theme/accent.dart';
import '../../../../shared/theme/app_theme_mode.dart';
import '../../../../shared/theme/theme_cubit.dart';
import '../cubit/editor_preferences_cubit.dart';
import '../widgets/forms_pane.dart';
import '../widgets/settings_atoms.dart';
import '../widgets/settings_nav.dart';
import '../widgets/sync_pane.dart';
import '../widgets/workspace_controls.dart';
import '../../../vault/data/exporter.dart';
import '../../../vault/data/html_exporter.dart';
import '../../../vault/data/pdf_exporter.dart';
import '../../../vault/data/workspace_config.dart';
import '../../../vault/presentation/bloc/vault_bloc.dart';
import '../../../vault/presentation/bloc/vault_event.dart';
import '../../../vault/presentation/bloc/vault_state.dart';
import '../../../vault/presentation/widgets/page_header.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, this.section = 'sync'});
  final String section;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late String _active;

  @override
  void initState() {
    super.initState();
    _active = widget.section;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    return Column(
      children: [
        PageHeader(crumbs: ['Settings', _activeLabel()]),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SettingsNav(active: _active, onSelect: (id) => setState(() => _active = id)),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(36, 24, 36, 40),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: _content(tokens),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _activeLabel() => switch (_active) {
        'vault' => 'Vault',
        'theme' => 'Appearance',
        'sidebar' => 'Sidebar',
        'sync' => 'Sync target',
        'git' => 'Git',
        's3' => 'S3 / WebDAV',
        'users' => 'Users',
        'perms' => 'Permissions',
        'forms' => 'Forms',
        'export' => 'Export & Backup',
        'advanced' => 'Advanced',
        _ => 'Settings',
      };

  Widget _content(QuillTokens tokens) {
    if (_active == 'theme') return _appearancePane(tokens);
    if (_active == 'export') return _exportPane(tokens);
    if (_active == 'advanced') return _advancedPane(tokens);
    if (_active == 'users') return _usersPane(tokens);
    if (_active == 'sidebar') return _sidebarPane(tokens);
    if (_active == 'sync') return SyncPane(tokens: tokens);
    if (_active == 'forms') return FormsPane(tokens: tokens);

    final state = context.watch<VaultBloc>().state;
    final vaultPath = state is VaultLoaded ? state.rootPath : '(no vault opened)';
    final pageCount = state is VaultLoaded ? state.pageCount : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _activeLabel(),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: tokens.text,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 600,
          child: Text(
            'Where your .md files live, and how they replicate. Files on disk are always the source of truth — sync targets are mirrors, not lockboxes.',
            style: TextStyle(fontSize: 13.5, color: tokens.text3, height: 1.55),
          ),
        ),
        const SizedBox(height: 28),
        _sectionLabel(tokens, 'Vault location'),
        SettingRow(
          label: 'Vault path',
          hint: 'Folder of .md files. Each page is one file.',
          child: Row(
            children: [
              SettingField(value: vaultPath, monospace: true, width: 300),
              const SizedBox(width: 8),
              SettingButton(label: 'Change…', onTap: () {
                context.read<VaultBloc>().add(const PickVault());
              }),
              const SizedBox(width: 8),
              SettingButton(
                label: 'Reveal',
                icon: 'reveal',
                onTap: () {
                  if (vaultPath.startsWith('(')) return;
                  Reveal.show(vaultPath);
                },
              ),
            ],
          ),
        ),
        if (state is VaultLoaded)
          SettingRow(
            label: 'Workspace name',
            hint: 'Override the folder name in the sidebar header.',
            child: WorkspaceNameField(state: state),
          ),
        if (state is VaultLoaded)
          SettingRow(
            label: 'Workspace icon',
            hint: 'Renders in the sidebar header. Tap to pick.',
            child: WorkspaceIconButton(state: state),
          ),
        SettingRow(
          label: 'Vault stats',
          hint: 'Read directly from disk.',
          child: _VaultStatsRow(pageCount: pageCount, vaultPath: vaultPath),
        ),
        const SizedBox(height: 28),
        _sectionLabel(tokens, 'Sync'),
        Row(
          children: const [
            Expanded(child: SyncPlaceholderCard(name: 'Git', icon: 'git', status: 'visual only', active: true)),
            SizedBox(width: 12),
            Expanded(child: SyncPlaceholderCard(name: 'S3', icon: 'cloud', status: 'not configured')),
            SizedBox(width: 12),
            Expanded(child: SyncPlaceholderCard(name: 'WebDAV', icon: 'cloud', status: 'not configured')),
          ],
        ),
        const SizedBox(height: 20),
        SettingRow(
          label: 'Auto-commit',
          hint: 'Commit pending changes every 5 minutes if there are any.',
          child: const SettingToggle(on: true),
        ),
        SettingRow(
          label: 'Conflict policy',
          hint: 'When a sibling edits the same file.',
          child: Segment<String>(
            value: 'merge',
            onChanged: (_) {},
            options: const [
              SegmentOption(value: 'merge', label: 'Merge YAML, prompt on body'),
              SegmentOption(value: 'ours', label: 'Prefer mine'),
              SegmentOption(value: 'theirs', label: 'Prefer theirs'),
            ],
          ),
        ),
        const SizedBox(height: 28),
        _sectionLabel(tokens, 'Users'),
        SettingRow(
          label: 'Members',
          hint: 'Authenticated via your Git provider.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              _MemberRow(name: 'Diego', role: 'admin'),
              _MemberRow(name: 'Lina', role: 'editor'),
              _MemberRow(name: 'Priya', role: 'editor'),
              _MemberRow(name: 'Marcus', role: 'viewer'),
            ],
          ),
        ),
        const SizedBox(height: 28),
        _sectionLabel(tokens, 'Data'),
        SettingRow(
          label: 'Export vault',
          hint: 'Folder of .md files, frontmatter intact. Open it anywhere.',
          child: SettingButton(
            label: 'Export to folder',
            icon: 'export',
            primary: true,
            onTap: () => _exportVault(context),
          ),
        ),
        SettingRow(
          label: 'Reindex',
          hint: 'Wipe and rebuild the SQLite cache from disk.',
          child: SettingButton(
            label: 'Reindex now',
            icon: 'sync',
            onTap: () {
              context.read<VaultBloc>().add(const ReindexVault());
              context.toastInfo('Reindexing vault…');
            },
          ),
        ),
        SettingRow(
          label: 'Delete workspace',
          hint: 'The vault folder on disk is untouched.',
          danger: true,
          child: SettingButton(
            label: 'Remove from app',
            icon: 'trash',
            onTap: () => _confirmClose(context),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmClose(BuildContext context) async {
    final ok = await showQuillConfirm(
      context,
      title: 'Remove from app?',
      sub:
          'The vault folder on disk is untouched. You can re-open it any time from the picker.',
      icon: 'trash',
      confirmLabel: 'Remove',
      danger: true,
    );
    if (!ok) return;
    if (!context.mounted) return;
    context.read<VaultBloc>().add(const CloseVault());
    // Settings is mounted inside the vault shell; once the bloc transitions
    // to VaultInitial the shell router will replace it with the picker.
  }

  // E32 / sync helper `_onPushAllUnsynced` was extracted to
  // widgets/sync_pane.dart in M1423 (FS-04 slice 2) — it was only
  // called from inside _syncPane, so it moves with the pane.

  Future<void> _exportVault(BuildContext context) async {
    final state = context.read<VaultBloc>().state;
    if (state is! VaultLoaded) return;
    final dest = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Export vault to…',
    );
    if (dest == null) return;
    if (!context.mounted) return;
    try {
      final n = await const VaultExporter().export(
        src: Directory(state.rootPath),
        dest: Directory(dest),
      );
      if (context.mounted) {
        context.toastSuccess(
          'Exported $n ${n == 1 ? 'file' : 'files'}',
          sub: dest,
          subMono: true,
        );
      }
    } catch (e) {
      if (context.mounted) context.toastError('Export failed', sub: '$e');
    }
  }

  Widget _advancedPane(QuillTokens tokens) {
    final state = context.watch<VaultBloc>().state;
    final loaded = state is VaultLoaded;
    final pageCount = loaded ? state.pageCount : 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Advanced',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: tokens.text,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 600,
          child: Text(
            'Operations on the drift cache. The .md files on disk stay '
            'authoritative — anything here can be re-derived from them.',
            style: TextStyle(
                fontSize: 13.5, color: tokens.text3, height: 1.55),
          ),
        ),
        const SizedBox(height: 28),
        _sectionLabel(tokens, 'Cache'),
        SettingRow(
          label: 'Pages indexed',
          hint: 'Total rows in the SQLite cache.',
          child: Text(
            '$pageCount',
            style: mono(fontSize: 14, color: tokens.text),
          ),
        ),
        SettingRow(
          label: 'Reindex',
          hint: 'Wipe and rebuild the SQLite cache from disk.',
          child: SettingButton(
            label: 'Reindex now',
            icon: 'sync',
            primary: true,
            onTap: !loaded
                ? null
                : () {
                    context.read<VaultBloc>().add(const ReindexVault());
                    context.toastInfo('Reindexing vault…');
                  },
          ),
        ),
        SettingRow(
          label: 'Refresh from disk',
          hint: 'Re-read changed files without dropping the cache.',
          child: SettingButton(
            label: 'Refresh',
            icon: 'sync',
            onTap: !loaded
                ? null
                : () => context
                    .read<VaultBloc>()
                    .add(const RefreshFromDisk()),
          ),
        ),
        const SizedBox(height: 18),
        _sectionLabel(tokens, 'Editor'),
        // D28 cutover slice 1b (M1665): opts the user in to the beta
        // WYSIWYG editor. /editor/:ulid (slice 1c) reads the same
        // cubit state to fork between EditorPage and EditorBetaPage.
        BlocBuilder<EditorPreferencesCubit, EditorPreferencesState>(
          buildWhen: (prev, next) =>
              prev.useBetaEditor != next.useBetaEditor,
          builder: (context, prefs) => SettingRow(
            label: 'Use beta WYSIWYG editor',
            hint: 'Open `.md` files with the new block editor '
                '(super_editor) instead of the legacy source/rendered '
                'split. Per-page Find (⌘F), drag-handles, and '
                'Notion-style block selection are beta-only today.',
            child: Switch.adaptive(
              value: prefs.useBetaEditor,
              onChanged: (next) => context
                  .read<EditorPreferencesCubit>()
                  .setUseBetaEditor(useBeta: next),
            ),
          ),
        ),
      ],
    );
  }

  Widget _sidebarPane(QuillTokens tokens) {
    final state = context.watch<VaultBloc>().state;
    final loaded = state is VaultLoaded;
    final order = loaded
        ? (state.workspace.sidebarOrder ?? _canonicalOrder)
        : _canonicalOrder;
    final hidden = loaded
        ? state.workspace.sidebarHidden.toSet()
        : <String>{};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sidebar',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: tokens.text,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 600,
          child: Text(
            'Reorder + hide sidebar sections. Persists to `.quill.yaml` '
            '`sidebar.order:` / `sidebar.hidden:` so the choice rides '
            'along with the vault.',
            style:
                TextStyle(fontSize: 13.5, color: tokens.text3, height: 1.55),
          ),
        ),
        const SizedBox(height: 28),
        _sectionLabel(tokens, 'Sections'),
        if (!loaded)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('Open a vault to customise its sidebar.',
                style: TextStyle(fontSize: 13, color: tokens.text3)),
          )
        else
          SizedBox(
            width: 360,
            child: Column(
              children: [
                for (var i = 0; i < order.length; i++)
                  _SidebarSectionRow(
                    id: order[i],
                    tokens: tokens,
                    isHidden: hidden.contains(order[i]),
                    canMoveUp: i > 0,
                    canMoveDown: i < order.length - 1,
                    onMoveUp: () => _moveSidebarSection(state, order, i, -1),
                    onMoveDown: () => _moveSidebarSection(state, order, i, 1),
                    onToggleHide: () => _toggleSidebarHidden(state, order[i]),
                  ),
                const SizedBox(height: 12),
                SettingButton(
                  label: 'Reset to default',
                  icon: 'sync',
                  onTap: () => _resetSidebar(state),
                ),
              ],
            ),
          ),
      ],
    );
  }

  static const _canonicalOrder = <String>[
    'favorites',
    'recent',
    'workspace',
    'databases',
    'more',
  ];

  Future<void> _moveSidebarSection(
    VaultLoaded state,
    List<String> currentOrder,
    int idx,
    int delta,
  ) async {
    final next = List<String>.from(currentOrder);
    final newIdx = (idx + delta).clamp(0, next.length - 1);
    if (newIdx == idx) return;
    final item = next.removeAt(idx);
    next.insert(newIdx, item);
    final updated = state.workspace.copyWith(sidebarOrder: next);
    try {
      await updated.save(Directory(state.rootPath));
    } catch (e) {
      if (!mounted) return;
      context.toastError('Could not save sidebar order', sub: '$e');
      return;
    }
    if (!mounted) return;
    context.read<VaultBloc>().add(const RefreshFromDisk());
  }

  Future<void> _toggleSidebarHidden(VaultLoaded state, String id) async {
    final hidden = state.workspace.sidebarHidden.toSet();
    if (hidden.contains(id)) {
      hidden.remove(id);
    } else {
      hidden.add(id);
    }
    final updated =
        state.workspace.copyWith(sidebarHidden: hidden.toList());
    try {
      await updated.save(Directory(state.rootPath));
    } catch (e) {
      if (!mounted) return;
      context.toastError('Could not save sidebar visibility', sub: '$e');
      return;
    }
    if (!mounted) return;
    context.read<VaultBloc>().add(const RefreshFromDisk());
  }

  Future<void> _resetSidebar(VaultLoaded state) async {
    final updated = state.workspace.copyWith(
      sidebarOrder: const [],
      sidebarHidden: const [],
    );
    try {
      await updated.save(Directory(state.rootPath));
    } catch (e) {
      if (!mounted) return;
      context.toastError('Could not reset sidebar', sub: '$e');
      return;
    }
    if (!mounted) return;
    context.read<VaultBloc>().add(const RefreshFromDisk());
    context.toastSuccess('Sidebar reset to default order');
  }

  Widget _usersPane(QuillTokens tokens) {
    final state = context.watch<VaultBloc>().state;
    final loaded = state is VaultLoaded;
    final users = loaded ? state.workspace.users : const <WorkspaceUser>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Users',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: tokens.text,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 600,
          child: Text(
            'Names referenced by `person` columns + auto-stamped into '
            '`created_by:` and `last_edited_by:` on save. Stored in '
            '.quill.yaml `users:` — no network, no identity provider.',
            style:
                TextStyle(fontSize: 13.5, color: tokens.text3, height: 1.55),
          ),
        ),
        const SizedBox(height: 28),
        _sectionLabel(tokens, 'Local users'),
        if (!loaded)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Open a vault to manage its users.',
              style: TextStyle(fontSize: 13, color: tokens.text3),
            ),
          )
        else ...[
          if (users.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No users yet. Add one below to start auto-stamping pages.',
                style: TextStyle(fontSize: 12, color: tokens.text3),
              ),
            )
          else
            for (final u in users)
              _UserRow(
                user: u,
                tokens: tokens,
                onSetDefault: () => _setDefaultUser(state, u.name),
                onRemove: () => _removeUser(state, u.name),
              ),
          const SizedBox(height: 12),
          _AddUserField(onAdd: (name) => _addUser(state, name)),
        ],
      ],
    );
  }

  Future<void> _addUser(VaultLoaded state, String rawName) async {
    final name = rawName.trim();
    if (name.isEmpty) return;
    if (state.workspace.users.any((u) => u.name == name)) {
      context.toastInfo('User already exists', sub: name);
      return;
    }
    final next = state.workspace.copyWith(users: [
      ...state.workspace.users,
      WorkspaceUser(name: name),
    ]);
    try {
      await next.save(Directory(state.rootPath));
    } catch (e) {
      if (!mounted) return;
      context.toastError('Could not save user', sub: '$e');
      return;
    }
    if (!mounted) return;
    context.read<VaultBloc>().add(const RefreshFromDisk());
    context.toastSuccess('Added user', sub: name);
  }

  Future<void> _removeUser(VaultLoaded state, String name) async {
    final next = state.workspace.copyWith(
      users: [for (final u in state.workspace.users) if (u.name != name) u],
    );
    try {
      await next.save(Directory(state.rootPath));
    } catch (e) {
      if (!mounted) return;
      context.toastError('Could not save user list', sub: '$e');
      return;
    }
    if (!mounted) return;
    context.read<VaultBloc>().add(const RefreshFromDisk());
    context.toastSuccess('Removed user', sub: name);
  }

  Future<void> _setDefaultUser(VaultLoaded state, String name) async {
    final next = state.workspace.copyWith(
      users: [
        for (final u in state.workspace.users)
          u.copyWith(isDefault: u.name == name),
      ],
    );
    try {
      await next.save(Directory(state.rootPath));
    } catch (e) {
      if (!mounted) return;
      context.toastError('Could not save default user', sub: '$e');
      return;
    }
    if (!mounted) return;
    context.read<VaultBloc>().add(const RefreshFromDisk());
    context.toastSuccess('Default user: $name');
  }

  Widget _exportPane(QuillTokens tokens) {
    final state = context.watch<VaultBloc>().state;
    final loaded = state is VaultLoaded;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Export & Backup',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: tokens.text,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 600,
          child: Text(
            'Snapshot your vault to portable formats. Markdown round-trips '
            'back into Quill (or any other markdown app); HTML and PDF are '
            'one-way reads for sharing.',
            style: TextStyle(
                fontSize: 13.5, color: tokens.text3, height: 1.55),
          ),
        ),
        const SizedBox(height: 28),
        _sectionLabel(tokens, 'Whole vault'),
        SettingRow(
          label: 'Markdown copy',
          hint: 'Folder of .md files with frontmatter intact.',
          child: SettingButton(
            label: 'Export…',
            icon: 'export',
            primary: true,
            onTap: !loaded ? null : () => _exportVault(context),
          ),
        ),
        SettingRow(
          label: 'HTML site',
          hint: 'One .html per page + index. Open the folder in a browser.',
          child: SettingButton(
            label: 'Export…',
            icon: 'export',
            onTap: !loaded ? null : () => _exportHtml(context),
          ),
        ),
        SettingRow(
          label: 'PDF',
          hint: 'Single PDF document. Useful for sharing or archiving.',
          child: SettingButton(
            label: 'Export…',
            icon: 'export',
            onTap: !loaded ? null : () => _exportPdf(context),
          ),
        ),
      ],
    );
  }

  Future<void> _exportHtml(BuildContext context) async {
    final state = context.read<VaultBloc>().state;
    if (state is! VaultLoaded) return;
    final dest = await FilePicker.platform
        .getDirectoryPath(dialogTitle: 'Export HTML to…');
    if (dest == null) return;
    if (!context.mounted) return;
    try {
      final n = await const HtmlExporter().export(
        src: Directory(state.rootPath),
        dest: Directory(dest),
      );
      if (context.mounted) {
        context.toastSuccess(
          'Exported $n HTML ${n == 1 ? 'file' : 'files'}',
          sub: dest,
          subMono: true,
        );
      }
    } catch (e) {
      if (context.mounted) context.toastError('HTML export failed', sub: '$e');
    }
  }

  Future<void> _exportPdf(BuildContext context) async {
    final state = context.read<VaultBloc>().state;
    if (state is! VaultLoaded) return;
    final picked = await FilePicker.platform.saveFile(
      dialogTitle: 'Save PDF…',
      fileName: 'vault.pdf',
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    if (picked == null) return;
    if (!context.mounted) return;
    try {
      final n = await const PdfExporter().export(
        src: Directory(state.rootPath),
        dest: File(picked),
      );
      if (context.mounted) {
        context.toastSuccess(
          'Exported $n ${n == 1 ? 'page' : 'pages'}',
          sub: picked,
          subMono: true,
        );
      }
    } catch (e) {
      if (context.mounted) context.toastError('PDF export failed', sub: '$e');
    }
  }

  Widget _appearancePane(QuillTokens tokens) {
    final themeState = context.watch<ThemeCubit>().state;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Appearance',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: tokens.text,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 600,
          child: Text(
            'Theme, density, and accent. Preferences are stored locally '
            'and apply to every workspace.',
            style: TextStyle(
                fontSize: 13.5, color: tokens.text3, height: 1.55),
          ),
        ),
        const SizedBox(height: 28),
        _sectionLabel(tokens, 'Theme'),
        SettingRow(
          label: 'Mode',
          hint: 'System follows your OS setting.',
          child: Wrap(
            spacing: 8,
            children: [
              for (final m in AppThemeMode.values)
                SettingButton(
                  label: switch (m) {
                    AppThemeMode.light => 'Light',
                    AppThemeMode.dark => 'Dark',
                    AppThemeMode.system => 'System',
                  },
                  primary: themeState.mode == m,
                  onTap: () => context.read<ThemeCubit>().setMode(m),
                ),
            ],
          ),
        ),
        SettingRow(
          label: 'Compact mode',
          hint: 'Tighter text scale across the editor.',
          child: SettingButton(
            label: themeState.compact ? 'On' : 'Off',
            primary: themeState.compact,
            onTap: () => context.read<ThemeCubit>().toggleCompact(),
          ),
        ),
        const SizedBox(height: 20),
        _sectionLabel(tokens, 'Accent'),
        SettingRow(
          label: 'Color',
          hint: 'Picks the link/active hue.',
          child: Wrap(
            spacing: 8,
            children: [
              SettingButton(
                label: 'Sage',
                primary: themeState.accent == AccentKey.sage,
                onTap: () =>
                    context.read<ThemeCubit>().setAccent(AccentKey.sage),
              ),
              SettingButton(
                label: 'Terracotta',
                primary: themeState.accent == AccentKey.terracotta,
                onTap: () =>
                    context.read<ThemeCubit>().setAccent(AccentKey.terracotta),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(QuillTokens tokens, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.0,
          color: tokens.text3,
        ),
      ),
    );
  }

  // Phase E E14 (M1312): Settings → Sync pane lived inline here
  // until M1423 (FS-04 slice 2). Extracted to widgets/sync_pane.
  // dart together with _SyncLoginCard + the bulk-push helper.

  // E58b-iii — Settings → Forms pane was inline here until M1421.
  // Extracted to widgets/forms_pane.dart along with its three
  // private widgets (row, empty state, error row) so this file
  // stays under the FS-04 threshold.
}

/// Square button that opens the emoji picker to change
/// .quill.yaml's workspace.icon. Mirrors the sidebar's WorkspaceHead
/// affordance from M107 but lives here so users browsing settings can
/// find it too.
// WorkspaceIconButton + WorkspaceNameField extracted to
// widgets/workspace_controls.dart in M1428 (FS-04 slice 4).

// _Nav + _NavItem extracted to widgets/settings_nav.dart in
// M1426 (FS-04 slice 3). The 220-px left rail is now a public
// SettingsNav widget that the page constructs from build.

// Atom widgets extracted to widgets/settings_atoms.dart in
// M1430 (FS-04 slice 5, final). SettingRow, SettingField,
// SettingButton, SettingStat, SettingToggle, and
// SyncPlaceholderCard now live in that single file. The
// SettingField rename also dropped the duplicate Tokens.mono
// static helper in favour of the project's existing mono(...)
// helper from shared/theme/tokens.dart.
//
// E26 SyncConnectedCard remains at
// `features/sync/presentation/widgets/sync_connected_card.dart`.
// _SyncLoginCard moved to widgets/sync_pane.dart in M1423.

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.name, required this.role});
  final String name;
  final String role;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    final color = switch (role) {
      'admin' => TagColor.orange,
      'editor' => TagColor.green,
      _ => TagColor.gray,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: kSettingsUserAvatarBg,
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
            child: Text(
              name.substring(0, 1),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(child: Text(name, style: TextStyle(fontSize: 13, color: tokens.text))),
          TagChip(label: role, color: color),
        ],
      ),
    );
  }
}

/// One user row in the Settings → Users pane. Avatar + name + "default"
/// pill if the user is marked default; trailing buttons to flip the
/// default flag and to remove the user.
class _UserRow extends StatelessWidget {
  const _UserRow({
    required this.user,
    required this.tokens,
    required this.onSetDefault,
    required this.onRemove,
  });
  final WorkspaceUser user;
  final QuillTokens tokens;
  final VoidCallback onSetDefault;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: tokens.divider, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          PersonChip(name: user.name),
          if (user.email != null) ...[
            const SizedBox(width: 10),
            Text(user.email!,
                style: mono(fontSize: 11, color: tokens.text3)),
          ],
          const Spacer(),
          if (user.isDefault)
            Tooltip(
              message:
                  'Auto-stamped into created_by + last_edited_by when saving.',
              waitDuration: const Duration(milliseconds: 500),
              child: Container(
                margin: const EdgeInsets.only(right: 10),
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: tokens.accent.withValues(alpha: 0.16),
                  borderRadius:
                      const BorderRadius.all(Radius.circular(3)),
                ),
                child: Text(
                  'default',
                  style: mono(fontSize: 10, color: tokens.accent),
                ),
              ),
            )
          else
            TextButton(
              onPressed: onSetDefault,
              style: TextButton.styleFrom(
                foregroundColor: tokens.text2,
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('Make default',
                  style: TextStyle(fontSize: 11.5)),
            ),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(2),
            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
            tooltip: 'Remove',
            onPressed: onRemove,
            icon: Icon(Icons.close, size: 14, color: tokens.text3),
          ),
        ],
      ),
    );
  }
}

class _AddUserField extends StatefulWidget {
  const _AddUserField({required this.onAdd});
  final void Function(String name) onAdd;

  @override
  State<_AddUserField> createState() => _AddUserFieldState();
}

class _AddUserFieldState extends State<_AddUserField> {
  final _ctl = TextEditingController();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _ctl.text.trim();
    if (name.isEmpty) return;
    widget.onAdd(name);
    _ctl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    return Row(
      children: [
        SizedBox(
          width: 240,
          child: TextField(
            controller: _ctl,
            onSubmitted: (_) => _submit(),
            style: TextStyle(fontSize: 13, color: tokens.text),
            decoration: InputDecoration(
              isCollapsed: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              hintText: 'Add a user…',
              hintStyle: TextStyle(fontSize: 12.5, color: tokens.text3),
              border: OutlineInputBorder(
                borderSide: BorderSide(color: tokens.divider2),
                borderRadius: const BorderRadius.all(Radius.circular(4)),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: tokens.divider2),
                borderRadius: const BorderRadius.all(Radius.circular(4)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: _submit,
          style: TextButton.styleFrom(
            foregroundColor: tokens.accent,
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          ),
          child: const Text('Add', style: TextStyle(fontSize: 12.5)),
        ),
      ],
    );
  }
}

/// Settings → Sidebar pane row: one sidebar section with up/down +
/// hide toggles. Labels are humanised from the canonical id list
/// ('favorites' → 'Favorites'). Hidden rows still appear in the list
/// but are dimmed.
class _SidebarSectionRow extends StatelessWidget {
  const _SidebarSectionRow({
    required this.id,
    required this.tokens,
    required this.isHidden,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onToggleHide,
  });
  final String id;
  final QuillTokens tokens;
  final bool isHidden;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onToggleHide;

  String get _label => switch (id) {
        'favorites' => 'Favorites',
        'recent' => 'Recent',
        'workspace' => 'Workspace (tree)',
        'databases' => 'Databases',
        'more' => 'More (Tags + Trash)',
        _ => id,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: tokens.divider, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _label,
              style: TextStyle(
                fontSize: 13,
                color: isHidden ? tokens.text3 : tokens.text,
                decoration: isHidden
                    ? TextDecoration.lineThrough
                    : TextDecoration.none,
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(2),
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            tooltip: 'Move up',
            onPressed: canMoveUp ? onMoveUp : null,
            icon: Icon(Icons.arrow_upward,
                size: 14,
                color: canMoveUp ? tokens.text2 : tokens.text3),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(2),
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            tooltip: 'Move down',
            onPressed: canMoveDown ? onMoveDown : null,
            icon: Icon(Icons.arrow_downward,
                size: 14,
                color: canMoveDown ? tokens.text2 : tokens.text3),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(2),
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            tooltip: isHidden ? 'Show' : 'Hide',
            onPressed: onToggleHide,
            icon: Icon(
                isHidden ? Icons.visibility_off : Icons.visibility,
                size: 14,
                color: isHidden ? tokens.text3 : tokens.text2),
          ),
        ],
      ),
    );
  }
}

class _VaultStatsRow extends StatefulWidget {
  const _VaultStatsRow({required this.pageCount, required this.vaultPath});
  final int pageCount;
  final String vaultPath;

  @override
  State<_VaultStatsRow> createState() => _VaultStatsRowState();
}

class _VaultStatsRowState extends State<_VaultStatsRow> {
  late Future<({int databases, int? sizeBytes})> _f;

  @override
  void initState() {
    super.initState();
    _f = _load();
  }

  @override
  void didUpdateWidget(_VaultStatsRow old) {
    super.didUpdateWidget(old);
    if (old.vaultPath != widget.vaultPath ||
        old.pageCount != widget.pageCount) {
      _f = _load();
    }
  }

  Future<({int databases, int? sizeBytes})> _load() async {
    final db = context.read<QuillDatabase>();
    final dbsRows = await db.select(db.databases).get();
    int? sizeBytes;
    if (!widget.vaultPath.startsWith('(')) {
      try {
        int total = 0;
        await for (final ent in Directory(widget.vaultPath)
            .list(recursive: true, followLinks: false)) {
          if (ent is File) {
            try {
              total += await ent.length();
            } catch (_) {}
          }
        }
        sizeBytes = total;
      } catch (_) {
        sizeBytes = null;
      }
    }
    return (databases: dbsRows.length, sizeBytes: sizeBytes);
  }

  static String _fmtBytes(int b) {
    if (b < 1024) return '${b}B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(0)}KB';
    if (b < 1024 * 1024 * 1024) {
      return '${(b / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
    return '${(b / (1024 * 1024 * 1024)).toStringAsFixed(2)}GB';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<({int databases, int? sizeBytes})>(
      future: _f,
      builder: (context, snap) {
        final data = snap.data;
        return Row(
          children: [
            SettingStat(
              label: 'pages',
              value: '${widget.pageCount}',
              tooltip: widget.pageCount == 1
                  ? '1 page indexed'
                  : '${widget.pageCount} pages indexed',
            ),
            const SizedBox(width: 28),
            SettingStat(
              label: 'databases',
              value: data == null ? '…' : '${data.databases}',
              tooltip: data == null
                  ? null
                  : data.databases == 1
                      ? '1 database (.database.yaml)'
                      : '${data.databases} databases (.database.yaml)',
            ),
            const SizedBox(width: 28),
            SettingStat(
              label: 'size',
              value: data == null || data.sizeBytes == null
                  ? '…'
                  : _fmtBytes(data.sizeBytes!),
              tooltip: data == null || data.sizeBytes == null
                  ? null
                  : '${data.sizeBytes!} bytes on disk',
            ),
          ],
        );
      },
    );
  }
}
