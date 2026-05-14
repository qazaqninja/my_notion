import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/theme/quill_tokens.dart';
import '../../../../shared/theme/tokens.dart';
import '../../../../shared/widgets/quill_icon.dart';
import '../../../../shared/widgets/segment.dart';
import '../../../../shared/widgets/status_dot.dart';
import '../../../../shared/widgets/tag_chip.dart';
import '../../../../shared/theme/tag_colors.dart';
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
              _Btn(label: 'Reveal', icon: 'reveal', onTap: () {}),
            ],
          ),
        ),
        _SettingRow(
          label: 'Vault stats',
          hint: 'Read directly from disk.',
          child: Row(
            children: [
              _Stat(label: 'pages', value: '$pageCount'),
              const SizedBox(width: 28),
              _Stat(label: 'databases', value: '1'),
              const SizedBox(width: 28),
              _Stat(label: 'size', value: '—'),
            ],
          ),
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
          child: _Btn(label: 'Export to folder', icon: 'export', primary: true, onTap: () {}),
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
          child: _Btn(label: 'Remove from app', icon: 'trash', onTap: () {}),
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

class _Nav extends StatelessWidget {
  const _Nav({required this.active, required this.onSelect});
  final String active;
  final void Function(String id) onSelect;

  static const _groups = [
    ('Workspace', [('vault', 'Vault', 'folder'), ('theme', 'Appearance', 'eye')]),
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

  Widget _item(QuillTokens tokens, {required String id, required String label, required String icon}) {
    final isActive = id == active;
    return GestureDetector(
      onTap: () => onSelect(id),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
          decoration: BoxDecoration(
            color: isActive ? tokens.selected : Colors.transparent,
            border: Border(
              left: BorderSide(
                color: isActive ? tokens.accent : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            children: [
              QuillIcon(icon, size: 14, strokeWidth: 1.7,
                  color: isActive ? tokens.text2 : tokens.text3),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: isActive ? FontWeight.w500 : FontWeight.w400,
                  color: isActive ? tokens.text : tokens.text2,
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

class _Btn extends StatelessWidget {
  const _Btn({required this.label, this.icon, this.onTap, this.primary = false});
  final String label;
  final String? icon;
  final VoidCallback? onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: primary ? tokens.accent : Colors.transparent,
            border: Border.all(color: primary ? Colors.transparent : tokens.divider2, width: 0.5),
            borderRadius: const BorderRadius.all(Radius.circular(5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                QuillIcon(icon!, size: 13, strokeWidth: 1.7,
                    color: primary ? Colors.white : tokens.text2),
                const SizedBox(width: 6),
              ],
              Text(
                label,
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
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    return Column(
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
