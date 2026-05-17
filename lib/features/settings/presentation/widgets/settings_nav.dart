import 'package:flutter/material.dart';

import '../../../../shared/theme/quill_tokens.dart';
import '../../../../shared/widgets/quill_icon.dart';

/// Settings page left rail (220 px). One section per group, each
/// section is a small caps label + clickable rows. The active row
/// gets an accent left-border and the `tokens.selected` background.
///
/// Extracted from settings_page.dart in M1426 (FS-04 slice 3) —
/// pure-presentational nav widget reusable in isolation if Quill
/// ever grows a settings dialog alongside the full-page route.
class SettingsNav extends StatelessWidget {
  const SettingsNav({
    super.key,
    required this.active,
    required this.onSelect,
  });

  /// Id of the currently-active row. Compared against each entry's
  /// id; the matching row renders in its active state.
  final String active;

  /// Fired when the user taps a row. The id passed in matches one
  /// of the entries below.
  final void Function(String id) onSelect;

  static const _groups = [
    ('Workspace', [
      ('vault', 'Vault', 'folder'),
      ('theme', 'Appearance', 'eye'),
      ('sidebar', 'Sidebar', 'sidebar'),
    ]),
    ('Sync', [
      ('sync', 'Sync target', 'sync'),
      ('git', 'Git', 'git'),
      ('s3', 'S3 / WebDAV', 'cloud'),
    ]),
    ('Access', [
      ('users', 'Users', 'users'),
      ('perms', 'Permissions', 'lock'),
    ]),
    // E58b-iii: 'forms' surfaces every form-bearing page in the
    // current vault + opens the existing FormSubmissionsDialog per
    // row. Sits next to Export & Backup in the Data group since
    // it's about reading from rather than writing to the vault.
    ('Data', [
      ('forms', 'Forms', 'inbox'),
      ('export', 'Export & Backup', 'export'),
      ('advanced', 'Advanced', 'gear'),
    ]),
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

  Widget _item(
    QuillTokens tokens, {
    required String id,
    required String label,
    required String icon,
  }) {
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
                  fontWeight: isActive ? FontWeight.w500 : FontWeight.w400,
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
