import 'package:flutter/material.dart';

import '../theme/quill_tokens.dart';
import '../theme/tag_colors.dart';
import 'quill_icon.dart';

/// Select / multi-select chip. Matches `Tag` from `primitives.jsx:28-42`.
class TagChip extends StatelessWidget {
  const TagChip({
    super.key,
    required this.label,
    this.color = TagColor.gray,
    this.icon,
    this.tooltip,
  });

  final String label;
  final TagColor color;
  final String? icon;

  /// Optional hover hint. Useful when [label] is abbreviated or when
  /// the chip is shown without its column key — the tooltip can carry
  /// the extra context.
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    final palette = tagPalette(tokens.brightness, color);
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
      decoration: BoxDecoration(
        color: palette.bg,
        borderRadius: const BorderRadius.all(Radius.circular(4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            QuillIcon(icon!, size: 10, strokeWidth: 1.8, color: palette.text),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              color: palette.text,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
    if (tooltip == null) return chip;
    return Tooltip(
      message: tooltip!,
      waitDuration: const Duration(milliseconds: 500),
      child: chip,
    );
  }
}
