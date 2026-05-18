import 'package:flutter/material.dart';

import '../../../../shared/theme/quill_tokens.dart';
import '../../../../shared/widgets/quill_icon.dart';

/// G2 — sticky bottom toolbar that surfaces the most-used kebab
/// actions on mobile/narrow widths. Pure presentation; callbacks
/// are wired by the parent editor's body column.
///
/// On wide layouts the kebab itself stays as the action surface;
/// this toolbar only renders when `isMobileWidth(context)` is true.
class MobileEditorToolbar extends StatelessWidget {
  const MobileEditorToolbar({
    super.key,
    required this.onSetReminder,
    required this.onPublish,
    required this.onViewFormSubmissions,
    required this.onMore,
    this.hasForms = false,
    this.isPublished = false,
  });

  /// Tapped on the bell icon — opens the reminder picker.
  final VoidCallback onSetReminder;

  /// Tapped on the link icon — publish or unpublish toggle. The
  /// parent inspects the current frontmatter to decide which action
  /// to dispatch; we just surface the tap.
  final VoidCallback onPublish;

  /// Tapped on the inbox icon — opens the form-submissions dialog.
  /// Hidden when [hasForms] is false (the page isn't form-bearing).
  final VoidCallback onViewFormSubmissions;

  /// Tapped on the kebab icon — opens the full overflow menu for
  /// any kebab entry not surfaced as its own toolbar button.
  final VoidCallback onMore;

  /// Whether the current page declares a `forms:` field. Drives the
  /// inbox-icon visibility (forms-only).
  final bool hasForms;

  /// Whether the current page is already published. Drives the
  /// link-icon color so a glance distinguishes Publish vs Unpublish.
  final bool isPublished;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<QuillTokens>()!;
    return Material(
      color: tokens.surface,
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: tokens.divider, width: 0.5),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _ToolBtn(
                icon: 'clock',
                tooltip: 'Set reminder',
                color: tokens.text2,
                onTap: onSetReminder,
              ),
              _ToolBtn(
                icon: 'link',
                tooltip: isPublished ? 'Unpublish' : 'Publish & copy link',
                color: isPublished ? tokens.accent : tokens.text2,
                onTap: onPublish,
              ),
              if (hasForms)
                _ToolBtn(
                  icon: 'inbox',
                  tooltip: 'View form submissions',
                  color: tokens.text2,
                  onTap: onViewFormSubmissions,
                ),
              _ToolBtn(
                icon: 'kebab-h',
                tooltip: 'More actions',
                color: tokens.text2,
                onTap: onMore,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolBtn extends StatelessWidget {
  const _ToolBtn({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  final String icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onTap,
        // Hit target stays at the Material 48-dp default; the
        // icon-only style matches the existing wide-mode kebab.
        icon: QuillIcon(icon, size: 22, color: color),
        splashRadius: 22,
        padding: const EdgeInsets.all(10),
      ),
    );
  }
}
