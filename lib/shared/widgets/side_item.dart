import 'package:flutter/material.dart';

import '../theme/quill_tokens.dart';
import '../theme/tokens.dart';
import 'quill_icon.dart';

class SideItemGlyph {
  const SideItemGlyph({required this.color, required this.letter});
  final Color color;
  final String letter;
}

enum SideDensity { comfy, compact }

enum SideChevron { none, closed, open }

/// Sidebar row — file/folder/database/generic. Matches `SideItem` from
/// `primitives.jsx:70-107`.
class SideItem extends StatefulWidget {
  const SideItem({
    super.key,
    this.density = SideDensity.comfy,
    this.icon,
    this.glyph,
    this.emojiIcon,
    required this.label,
    this.count,
    this.chevron = SideChevron.none,
    this.active = false,
    this.mute = false,
    this.level = 0,
    this.onTap,
    this.onSecondaryTap,
    this.trailingOnHover,
    this.alwaysTrailing,
  });

  final SideDensity density;
  final String? icon;
  final SideItemGlyph? glyph;

  /// Emoji rendered in place of the standard icon. Takes precedence
  /// over [icon] / [glyph]. No background chip — emojis already carry
  /// their own colour.
  final String? emojiIcon;
  final String label;
  final int? count;
  final SideChevron chevron;
  final bool active;
  final bool mute;
  final int level;
  final VoidCallback? onTap;

  /// Right-click handler. Used for context menus.
  final void Function(Offset globalPosition)? onSecondaryTap;

  /// Widget shown on hover (or always on touch platforms) at the trailing
  /// edge. Replaces the count badge if both are set.
  final Widget? trailingOnHover;

  /// Widget shown at the trailing edge whether or not the row is being
  /// hovered. Rendered to the LEFT of any hover- or count- driven
  /// trailing widget so it doesn't get swapped out on hover.
  final Widget? alwaysTrailing;

  @override
  State<SideItem> createState() => _SideItemState();
}

class _SideItemState extends State<SideItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    final padY = widget.density == SideDensity.compact ? 3.0 : 5.0;
    final fs = widget.density == SideDensity.compact ? 13.0 : 13.5;
    final color = widget.active
        ? tokens.text
        : (widget.mute ? tokens.text3 : tokens.text2);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onSecondaryTapDown: widget.onSecondaryTap == null
            ? null
            : (d) => widget.onSecondaryTap!(d.globalPosition),
        onLongPressStart: widget.onSecondaryTap == null
            ? null
            : (d) => widget.onSecondaryTap!(d.globalPosition),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 6),
          padding: EdgeInsets.fromLTRB(10 + widget.level * 14, padY, 6, padY),
          decoration: BoxDecoration(
            color: widget.active
                ? tokens.selected
                : (_hover ? tokens.hover : Colors.transparent),
            borderRadius: const BorderRadius.all(Radius.circular(5)),
          ),
          child: Row(
            children: [
              if (widget.chevron != SideChevron.none)
                SizedBox(
                  width: 14,
                  child: Transform.rotate(
                    angle:
                        widget.chevron == SideChevron.open ? 1.5708 : 0, // 90°
                    child: QuillIcon('caret',
                        size: 11, strokeWidth: 1.8, color: tokens.text3),
                  ),
                )
              else
                const SizedBox(width: 14),
              if (widget.emojiIcon != null) ...[
                SizedBox(
                  width: 14,
                  height: 14,
                  child: Center(
                    child: Text(
                      widget.emojiIcon!,
                      style: const TextStyle(fontSize: 12, height: 1),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ] else if (widget.glyph != null) ...[
                Container(
                  width: 14,
                  height: 14,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: widget.glyph!.color,
                    borderRadius: const BorderRadius.all(Radius.circular(3.5)),
                  ),
                  child: Text(
                    widget.glyph!.letter,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14 * 0.62,
                      height: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ] else if (widget.icon != null) ...[
                QuillIcon(widget.icon!,
                    size: 14, strokeWidth: 1.7, color: tokens.text3),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Tooltip(
                  message: widget.label,
                  waitDuration: const Duration(milliseconds: 500),
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      color: color,
                      fontSize: fs,
                      fontWeight:
                          widget.active ? FontWeight.w500 : FontWeight.w400,
                      height: 1.3,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    softWrap: false,
                  ),
                ),
              ),
              if (widget.alwaysTrailing != null) widget.alwaysTrailing!,
              if (_hover && widget.trailingOnHover != null)
                widget.trailingOnHover!
              else if (widget.count != null)
                Text('${widget.count}', style: mono(fontSize: 11, color: tokens.text3)),
            ],
          ),
        ),
      ),
    );
  }
}
