import 'package:flutter/material.dart';

import '../theme/quill_tokens.dart';
import '../theme/tokens.dart';
import 'quill_icon.dart';

/// Relation chip — used inline in markdown and in lists. Matches `Chip` from
/// `primitives.jsx:4-25`.
class RelationChip extends StatelessWidget {
  const RelationChip({
    super.key,
    required this.label,
    this.ulid,
    this.showUlid = false,
    this.icon = 'file-md',
    this.emojiIcon,
    this.prefix,
    this.onTap,
    this.tooltip,
  });

  final String label;
  final String? ulid;
  final bool showUlid;
  final String icon;

  /// Optional plain-emoji glyph; rendered in place of [icon] when set.
  /// Wikilink chips use this to surface the linked page's frontmatter
  /// `icon:` so the chip stays in sync with the sidebar / palette
  /// emoji sweep (M253–M257).
  final String? emojiIcon;

  final String? prefix;
  final VoidCallback? onTap;

  /// Optional tooltip surfaced on hover. When null, falls back to the
  /// chip's own label so long titles aren't lost behind ellipsis.
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    final t = tooltip ?? label;
    return Tooltip(
      message: t,
      waitDuration: const Duration(milliseconds: 400),
      child: GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: onTap == null
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        child: Container(
        constraints: const BoxConstraints(maxWidth: 220),
        padding: const EdgeInsets.fromLTRB(6, 1.5, 7, 1.5),
        decoration: BoxDecoration(
          color: tokens.chipBg,
          borderRadius: const BorderRadius.all(Radius.circular(4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (emojiIcon != null)
              SizedBox(
                width: 11,
                height: 11,
                child: Center(
                  child: Text(emojiIcon!,
                      style: const TextStyle(fontSize: 10, height: 1)),
                ),
              )
            else
              QuillIcon(icon,
                  size: 11, strokeWidth: 1.7, color: tokens.chipText),
            const SizedBox(width: 5),
            if (prefix != null) ...[
              Text(
                prefix!,
                style: TextStyle(
                  color: tokens.chipText.withValues(alpha: 0.55),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: tokens.chipText,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  height: 1.45,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                softWrap: false,
              ),
            ),
            if (showUlid && ulid != null) ...[
              const SizedBox(width: 4),
              Text(
                ulid!.substring(ulid!.length - 6),
                style: mono(
                  fontSize: 10.5,
                  color: tokens.chipText.withValues(alpha: 0.45),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
      ),
    );
  }
}
