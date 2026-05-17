import 'package:flutter/material.dart';

import '../../../../shared/theme/quill_tokens.dart';
import '../../../../shared/theme/tag_colors.dart';
import '../../../../shared/theme/tokens.dart';
import '../../../../shared/widgets/quill_icon.dart';
import '../../../../shared/widgets/status_dot.dart';

/// Settings page atom widgets — the reusable layout + control
/// primitives every pane stitches together. Extracted from
/// settings_page.dart in M1430 (FS-04 slice 5, the final slice
/// of the decomposition). Each widget was private (`_Foo`) in
/// the page; the extraction flips them public so the page can
/// import + reference them across the file boundary.
///
/// What lives here vs `forms_pane` / `sync_pane` / `settings_nav`
/// / `workspace_controls`: those four files are pane-specific
/// composers. This file is the shared atom layer the panes
/// stack into rows.

/// Single labelled row used inside every pane: 200-px label
/// column on the left (title + hint) and a flex child on the
/// right (input, button, toggle, etc.). The row is separated
/// from the next by a 0.5-px divider.
class SettingRow extends StatelessWidget {
  const SettingRow({
    super.key,
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
                    color: danger ? tokens.danger : tokens.text,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  hint,
                  style: TextStyle(
                      fontSize: 12, color: tokens.text3, height: 1.45),
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

/// Read-only display field — looks like an input but renders a
/// single-line string. Used for things like the vault path or
/// the SyncBloc's lastFetched relpath.
class SettingField extends StatelessWidget {
  const SettingField({
    super.key,
    required this.value,
    this.monospace = false,
    this.width = double.infinity,
  });

  final String value;

  /// When true, renders in JetBrainsMono via the shared `mono(...)`
  /// helper. (Renamed from the original `_Field.mono` parameter to
  /// avoid shadowing the top-level helper of the same name; the
  /// pre-extraction file carried a duplicate `Tokens.mono(...)`
  /// static helper just to dodge that shadow — gone now.)
  final bool monospace;

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
        style: monospace
            ? mono(fontSize: 13, color: tokens.text)
            : TextStyle(fontSize: 13, color: tokens.text),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }
}

/// Compact button used across panes. `primary: true` flips to the
/// accent-fill variant for the destructive/affirmative actions.
class SettingButton extends StatefulWidget {
  const SettingButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.primary = false,
  });

  final String label;
  final String? icon;
  final VoidCallback? onTap;
  final bool primary;

  @override
  State<SettingButton> createState() => _SettingButtonState();
}

class _SettingButtonState extends State<SettingButton> {
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
                  ? (_hover
                      ? tokens.accent.withValues(alpha: 0.85)
                      : tokens.accent)
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
                      color: primary
                          ? Theme.of(context).colorScheme.onPrimary
                          : tokens.text2),
                  const SizedBox(width: 6),
                ],
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: primary
                        ? Theme.of(context).colorScheme.onPrimary
                        : tokens.text,
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

/// label-on-top, value-below stat tile. Used in the vault pane's
/// page-count / size summary row + the advanced pane's index
/// counters. Optional [tooltip] surfaces a hover hint with extra
/// detail (e.g., raw byte count for a human-formatted size).
class SettingStat extends StatelessWidget {
  const SettingStat({
    super.key,
    required this.label,
    required this.value,
    this.tooltip,
  });

  final String label;
  final String value;
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
          style:
              mono(fontSize: 18, color: tokens.text, fontWeight: FontWeight.w500),
        ),
      ],
    );
    if (tooltip != null) {
      body = Tooltip(
        message: tooltip,
        waitDuration: const Duration(milliseconds: 500),
        child: body,
      );
    }
    return body;
  }
}

/// 34×20 pill toggle used in the Appearance + Advanced panes for
/// the boolean settings (compact mode, dark mode, etc.). Knob is
/// canonically white-against-rail in both light + dark modes —
/// `colorScheme.onPrimary` mirrors that semantic (rail is
/// `tokens.accent`).
class SettingToggle extends StatelessWidget {
  const SettingToggle({super.key, required this.on});
  final bool on;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    return Container(
      width: 34,
      height: 20,
      decoration: BoxDecoration(
        color: on
            ? tokens.accent
            : (tokens.isDark ? kToggleRailOffDark : kToggleRailOffLight),
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
                color: Theme.of(context).colorScheme.onPrimary,
                borderRadius: const BorderRadius.all(Radius.circular(8)),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context)
                        .colorScheme
                        .shadow
                        .withValues(alpha: 0.15),
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

/// Visual-only placeholder card for the Git/S3/WebDAV connector
/// teasers in the vault pane. The actual sync flow runs through
/// SyncPane + SyncBloc; this card is just the "we know you
/// expected this here" affordance. `active: true` paints the
/// accent border + StatusDot.
class SyncPlaceholderCard extends StatelessWidget {
  const SyncPlaceholderCard({
    super.key,
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
        border: Border.all(
            color: active ? tokens.accent : tokens.divider2, width: 0.5),
        borderRadius: const BorderRadius.all(Radius.circular(6)),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              // Subtle inverse-of-bg wash so the chiclet shows up
              // against the page surface — `tokens.text` is dark on
              // light, light on dark, which matches the original
              // black/white toggle exactly.
              color: tokens.text.withValues(alpha: 0.04),
              borderRadius: const BorderRadius.all(Radius.circular(5)),
            ),
            child: QuillIcon(icon,
                size: 15,
                strokeWidth: 1.7,
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
