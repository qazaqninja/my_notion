import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/db/quill_database.dart' hide Page;
import '../../../../core/platform/reveal.dart';
import '../../../../shared/theme/quill_tokens.dart';
import '../../../../shared/theme/tokens.dart';
import '../../../../shared/widgets/quill_icon.dart';
import '../../../../shared/widgets/quill_overlays.dart';
import '../../../../shared/widgets/segment.dart';
import '../../../../shared/widgets/status_dot.dart';
import '../../../../shared/widgets/person_chip.dart';
import '../../../../shared/widgets/tag_chip.dart';
import '../../../../shared/theme/accent.dart';
import '../../../../shared/widgets/emoji_picker.dart';
import '../../../../shared/theme/tag_colors.dart';
import '../../../../shared/theme/theme_cubit.dart';
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
              _Nav(active: _active, onSelect: (id) => setState(() => _active = id)),
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
        _SettingRow(
          label: 'Vault path',
          hint: 'Folder of .md files. Each page is one file.',
          child: Row(
            children: [
              _Field(value: vaultPath, mono: true, width: 300),
              const SizedBox(width: 8),
              _Btn(label: 'Change…', onTap: () {
                context.read<VaultBloc>().add(const PickVault());
              }),
              const SizedBox(width: 8),
              _Btn(
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
          _SettingRow(
            label: 'Workspace name',
            hint: 'Override the folder name in the sidebar header.',
            child: _WorkspaceNameField(state: state),
          ),
        if (state is VaultLoaded)
          _SettingRow(
            label: 'Workspace icon',
            hint: 'Renders in the sidebar header. Tap to pick.',
            child: _WorkspaceIconButton(state: state),
          ),
        _SettingRow(
          label: 'Vault stats',
          hint: 'Read directly from disk.',
          child: _VaultStatsRow(pageCount: pageCount, vaultPath: vaultPath),
        ),
        const SizedBox(height: 28),
        _sectionLabel(tokens, 'Sync'),
        Row(
          children: const [
            Expanded(child: _SyncCard(name: 'Git', icon: 'git', status: 'visual only', active: true)),
            SizedBox(width: 12),
            Expanded(child: _SyncCard(name: 'S3', icon: 'cloud', status: 'not configured')),
            SizedBox(width: 12),
            Expanded(child: _SyncCard(name: 'WebDAV', icon: 'cloud', status: 'not configured')),
          ],
        ),
        const SizedBox(height: 20),
        _SettingRow(
          label: 'Auto-commit',
          hint: 'Commit pending changes every 5 minutes if there are any.',
          child: const _Toggle(on: true),
        ),
        _SettingRow(
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
        _SettingRow(
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
        _SettingRow(
          label: 'Export vault',
          hint: 'Folder of .md files, frontmatter intact. Open it anywhere.',
          child: _Btn(
            label: 'Export to folder',
            icon: 'export',
            primary: true,
            onTap: () => _exportVault(context),
          ),
        ),
        _SettingRow(
          label: 'Reindex',
          hint: 'Wipe and rebuild the SQLite cache from disk.',
          child: _Btn(
            label: 'Reindex now',
            icon: 'sync',
            onTap: () => context.read<VaultBloc>().add(const ReindexVault()),
          ),
        ),
        _SettingRow(
          label: 'Delete workspace',
          hint: 'The vault folder on disk is untouched.',
          danger: true,
          child: _Btn(
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
        _SettingRow(
          label: 'Pages indexed',
          hint: 'Total rows in the SQLite cache.',
          child: Text(
            '$pageCount',
            style: mono(fontSize: 14, color: tokens.text),
          ),
        ),
        _SettingRow(
          label: 'Reindex',
          hint: 'Wipe and rebuild the SQLite cache from disk.',
          child: _Btn(
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
        _SettingRow(
          label: 'Refresh from disk',
          hint: 'Re-read changed files without dropping the cache.',
          child: _Btn(
            label: 'Refresh',
            icon: 'sync',
            onTap: !loaded
                ? null
                : () => context
                    .read<VaultBloc>()
                    .add(const RefreshFromDisk()),
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
                _Btn(
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
    await updated.save(Directory(state.rootPath));
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
    await updated.save(Directory(state.rootPath));
    if (!mounted) return;
    context.read<VaultBloc>().add(const RefreshFromDisk());
  }

  Future<void> _resetSidebar(VaultLoaded state) async {
    final updated = state.workspace.copyWith(
      sidebarOrder: const [],
      sidebarHidden: const [],
    );
    await updated.save(Directory(state.rootPath));
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
    if (state.workspace.users.any((u) => u.name == name)) return;
    final next = state.workspace.copyWith(users: [
      ...state.workspace.users,
      WorkspaceUser(name: name),
    ]);
    await next.save(Directory(state.rootPath));
    if (!mounted) return;
    context.read<VaultBloc>().add(const RefreshFromDisk());
    context.toastSuccess('Added user', sub: name);
  }

  Future<void> _removeUser(VaultLoaded state, String name) async {
    final next = state.workspace.copyWith(
      users: [for (final u in state.workspace.users) if (u.name != name) u],
    );
    await next.save(Directory(state.rootPath));
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
    await next.save(Directory(state.rootPath));
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
        _SettingRow(
          label: 'Markdown copy',
          hint: 'Folder of .md files with frontmatter intact.',
          child: _Btn(
            label: 'Export…',
            icon: 'export',
            primary: true,
            onTap: !loaded ? null : () => _exportVault(context),
          ),
        ),
        _SettingRow(
          label: 'HTML site',
          hint: 'One .html per page + index. Open the folder in a browser.',
          child: _Btn(
            label: 'Export…',
            icon: 'export',
            onTap: !loaded ? null : () => _exportHtml(context),
          ),
        ),
        _SettingRow(
          label: 'PDF',
          hint: 'Single PDF document. Useful for sharing or archiving.',
          child: _Btn(
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
        _SettingRow(
          label: 'Mode',
          hint: 'System follows your OS setting.',
          child: Wrap(
            spacing: 8,
            children: [
              for (final m in ThemeMode.values)
                _Btn(
                  label: switch (m) {
                    ThemeMode.light => 'Light',
                    ThemeMode.dark => 'Dark',
                    ThemeMode.system => 'System',
                  },
                  primary: themeState.mode == m,
                  onTap: () => context.read<ThemeCubit>().setMode(m),
                ),
            ],
          ),
        ),
        _SettingRow(
          label: 'Compact mode',
          hint: 'Tighter text scale across the editor.',
          child: _Btn(
            label: themeState.compact ? 'On' : 'Off',
            primary: themeState.compact,
            onTap: () => context.read<ThemeCubit>().toggleCompact(),
          ),
        ),
        const SizedBox(height: 20),
        _sectionLabel(tokens, 'Accent'),
        _SettingRow(
          label: 'Color',
          hint: 'Picks the link/active hue.',
          child: Wrap(
            spacing: 8,
            children: [
              _Btn(
                label: 'Sage',
                primary: themeState.accent == AccentKey.sage,
                onTap: () =>
                    context.read<ThemeCubit>().setAccent(AccentKey.sage),
              ),
              _Btn(
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
}

/// Square button that opens the emoji picker to change
/// .quill.yaml's workspace.icon. Mirrors the sidebar's WorkspaceHead
/// affordance from M107 but lives here so users browsing settings can
/// find it too.
class _WorkspaceIconButton extends StatelessWidget {
  const _WorkspaceIconButton({required this.state});
  final VaultLoaded state;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    final icon = state.workspace.icon;
    final hasIcon = icon != null && icon.trim().isNotEmpty;
    return GestureDetector(
      onTap: () async {
        final picked = await pickEmoji(context);
        if (picked == null) return;
        final next =
            state.workspace.copyWith(icon: picked.isEmpty ? '' : picked);
        await next.save(Directory(state.rootPath));
        if (!context.mounted) return;
        context.read<VaultBloc>().add(const RefreshFromDisk());
        context.toastSuccess(picked.isEmpty
            ? 'Workspace icon cleared'
            : 'Workspace icon: $picked');
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Tooltip(
          message: hasIcon ? 'Change workspace icon' : 'Pick workspace icon',
          waitDuration: const Duration(milliseconds: 500),
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: hasIcon ? tokens.surface2 : tokens.accent,
              border: Border.all(color: tokens.divider2, width: 0.5),
              borderRadius: const BorderRadius.all(Radius.circular(6)),
            ),
            child: hasIcon
                ? Text(icon, style: const TextStyle(fontSize: 18))
                : Icon(Icons.tag_faces_outlined,
                    size: 16, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

/// TextField that edits .quill.yaml's workspace.name on commit (focus
/// loss or Enter). Clearing the field removes the override so the
/// sidebar falls back to the folder basename.
class _WorkspaceNameField extends StatefulWidget {
  const _WorkspaceNameField({required this.state});
  final VaultLoaded state;

  @override
  State<_WorkspaceNameField> createState() => _WorkspaceNameFieldState();
}

class _WorkspaceNameFieldState extends State<_WorkspaceNameField> {
  late final TextEditingController _ctl;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _ctl = TextEditingController(text: widget.state.workspace.name ?? '');
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    _ctl.dispose();
    super.dispose();
  }

  Future<void> _commit() async {
    final trimmed = _ctl.text.trim();
    final current = widget.state.workspace.name ?? '';
    if (trimmed == current) return;
    final next = widget.state.workspace.copyWith(
      name: trimmed.isEmpty ? '' : trimmed,
    );
    await next.save(Directory(widget.state.rootPath));
    if (!mounted) return;
    context.read<VaultBloc>().add(const RefreshFromDisk());
    context.toastSuccess(trimmed.isEmpty
        ? 'Workspace name cleared'
        : 'Workspace name: $trimmed');
  }

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    return SizedBox(
      width: 300,
      child: TextField(
        controller: _ctl,
        focusNode: _focus,
        onSubmitted: (_) => _commit(),
        style: TextStyle(fontSize: 13, color: tokens.text),
        decoration: InputDecoration(
          isCollapsed: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          border: OutlineInputBorder(
            borderSide: BorderSide(color: tokens.divider2),
            borderRadius: const BorderRadius.all(Radius.circular(4)),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: tokens.divider2),
            borderRadius: const BorderRadius.all(Radius.circular(4)),
          ),
          hintText:
              widget.state.rootPath.split('/').last.replaceAll('_', ' '),
          hintStyle: TextStyle(fontSize: 13, color: tokens.text3),
        ),
      ),
    );
  }
}

class _Nav extends StatelessWidget {
  const _Nav({required this.active, required this.onSelect});
  final String active;
  final void Function(String id) onSelect;

  static const _groups = [
    ('Workspace', [
      ('vault', 'Vault', 'folder'),
      ('theme', 'Appearance', 'eye'),
      ('sidebar', 'Sidebar', 'sidebar'),
    ]),
    ('Sync', [('sync', 'Sync target', 'sync'), ('git', 'Git', 'git'), ('s3', 'S3 / WebDAV', 'cloud')]),
    ('Access', [('users', 'Users', 'users'), ('perms', 'Permissions', 'lock')]),
    ('Data', [('export', 'Export & Backup', 'export'), ('advanced', 'Advanced', 'gear')]),
  ];

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    return Container(
      width: 220,
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: tokens.divider, width: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (label, items) in _groups) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 4, 10, 2),
                child: Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                    color: tokens.text3,
                  ),
                ),
              ),
              for (final (id, label, icon) in items)
                _item(tokens, id: id, label: label, icon: icon),
              const SizedBox(height: 14),
            ],
          ],
        ),
      ),
    );
  }

  Widget _item(QuillTokens tokens,
      {required String id, required String label, required String icon}) {
    return _NavItem(
      id: id,
      label: label,
      icon: icon,
      active: id == active,
      onTap: () => onSelect(id),
    );
  }
}

class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String id;
  final String label;
  final String icon;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    final isActive = widget.active;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
          decoration: BoxDecoration(
            color: isActive
                ? tokens.selected
                : (_hover ? tokens.hover : Colors.transparent),
            border: Border(
              left: BorderSide(
                color: isActive ? tokens.accent : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            children: [
              QuillIcon(widget.icon,
                  size: 14,
                  strokeWidth: 1.7,
                  color: isActive
                      ? tokens.text2
                      : (_hover ? tokens.text2 : tokens.text3)),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight:
                      isActive ? FontWeight.w500 : FontWeight.w400,
                  color: isActive
                      ? tokens.text
                      : (_hover ? tokens.text : tokens.text2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.label,
    required this.hint,
    required this.child,
    this.danger = false,
  });

  final String label;
  final String hint;
  final Widget child;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.divider, width: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 200,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: danger ? const Color(0xFFA8584C) : tokens.text,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  hint,
                  style: TextStyle(fontSize: 12, color: tokens.text3, height: 1.45),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.value, this.mono = false, this.width = double.infinity});
  final String value;
  final bool mono;
  final double width;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    return Container(
      width: width == double.infinity ? null : width,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tokens.inputBg,
        border: Border.all(color: tokens.divider2, width: 0.5),
        borderRadius: const BorderRadius.all(Radius.circular(5)),
      ),
      child: Text(
        value,
        style: mono
            ? Tokens.mono(fontSize: 13, color: tokens.text)
            : TextStyle(fontSize: 13, color: tokens.text),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }
}

class Tokens {
  static TextStyle mono({double? fontSize, Color? color}) =>
      TextStyle(fontFamily: 'JetBrainsMono', fontSize: fontSize, color: color);
}

class _Btn extends StatefulWidget {
  const _Btn({required this.label, this.icon, this.onTap, this.primary = false});
  final String label;
  final String? icon;
  final VoidCallback? onTap;
  final bool primary;

  @override
  State<_Btn> createState() => _BtnState();
}

class _BtnState extends State<_Btn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    final primary = widget.primary;
    final enabled = widget.onTap != null;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: enabled ? (_) => setState(() => _hover = true) : null,
      onExit: enabled ? (_) => setState(() => _hover = false) : null,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Opacity(
          opacity: enabled ? 1.0 : 0.5,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: primary
                  ? (_hover ? tokens.accent.withValues(alpha: 0.85) : tokens.accent)
                  : (_hover ? tokens.hover : Colors.transparent),
              border: Border.all(
                  color: primary
                      ? Colors.transparent
                      : (_hover ? tokens.accent : tokens.divider2),
                  width: 0.5),
              borderRadius: const BorderRadius.all(Radius.circular(5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.icon != null) ...[
                  QuillIcon(widget.icon!,
                      size: 13,
                      strokeWidth: 1.7,
                      color: primary ? Colors.white : tokens.text2),
                  const SizedBox(width: 6),
                ],
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: primary ? Colors.white : tokens.text,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.tooltip});
  final String label;
  final String value;

  /// Optional hover hint with extra detail (e.g. raw byte count for a
  /// human-formatted size).
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    Widget body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: mono(fontSize: 11, color: tokens.text3)),
        const SizedBox(height: 2),
        Text(
          value,
          style: mono(fontSize: 18, color: tokens.text, fontWeight: FontWeight.w500),
        ),
      ],
    );
    if (tooltip != null) {
      body = Tooltip(
        message: tooltip!,
        waitDuration: const Duration(milliseconds: 500),
        child: body,
      );
    }
    return body;
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.on});
  final bool on;
  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    return Container(
      width: 34,
      height: 20,
      decoration: BoxDecoration(
        color: on ? tokens.accent : (tokens.isDark ? const Color(0xFF3A3833) : const Color(0xFFD5D1C8)),
        borderRadius: const BorderRadius.all(Radius.circular(10)),
      ),
      child: Stack(
        children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 150),
            top: 2,
            left: on ? 16 : 2,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.all(Radius.circular(8)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncCard extends StatelessWidget {
  const _SyncCard({
    required this.name,
    required this.icon,
    required this.status,
    this.active = false,
  });

  final String name;
  final String icon;
  final String status;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: active ? tokens.accentTint : tokens.surface,
        border: Border.all(color: active ? tokens.accent : tokens.divider2, width: 0.5),
        borderRadius: const BorderRadius.all(Radius.circular(6)),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tokens.isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.black.withValues(alpha: 0.04),
              borderRadius: const BorderRadius.all(Radius.circular(5)),
            ),
            child: QuillIcon(icon, size: 15, strokeWidth: 1.7,
                color: active ? tokens.accent : tokens.text2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: active ? tokens.accent : tokens.text,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text(
                    status,
                    style: mono(fontSize: 11.5, color: tokens.text3),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
          if (active)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const StatusDot(),
                const SizedBox(width: 6),
                Text(status,
                    style: TextStyle(fontSize: 11.5, color: tokens.accent)),
              ],
            ),
        ],
      ),
    );
  }
}

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
            decoration: BoxDecoration(
              color: const Color(0xFF8C9F8B),
              borderRadius: const BorderRadius.all(Radius.circular(10)),
            ),
            child: Text(
              name.substring(0, 1),
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600, fontSize: 11),
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
            Container(
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
            _Stat(
              label: 'pages',
              value: '${widget.pageCount}',
              tooltip: widget.pageCount == 1
                  ? '1 page indexed'
                  : '${widget.pageCount} pages indexed',
            ),
            const SizedBox(width: 28),
            _Stat(
              label: 'databases',
              value: data == null ? '…' : '${data.databases}',
              tooltip: data == null
                  ? null
                  : data.databases == 1
                      ? '1 database (.database.yaml)'
                      : '${data.databases} databases (.database.yaml)',
            ),
            const SizedBox(width: 28),
            _Stat(
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
