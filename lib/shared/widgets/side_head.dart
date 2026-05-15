import 'package:flutter/material.dart';

import '../theme/quill_tokens.dart';
import 'quill_icon.dart';

/// Sidebar section heading, matches `SideHead` from `primitives.jsx:110-122`.
class SideHead extends StatelessWidget {
  const SideHead({
    super.key,
    required this.label,
    this.actionIcon,
    this.onAction,
    this.actionTooltip,
    this.count,
  });
  final String label;
  final String? actionIcon;
  final VoidCallback? onAction;

  /// Optional tooltip shown when hovering the trailing action icon.
  /// Defaults to nothing — the caller can opt in.
  final String? actionTooltip;

  /// Optional count badge rendered next to the label as a faint mono
  /// number. Suppressed when null.
  final int? count;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
              color: tokens.text3,
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 6),
            Tooltip(
              message: count == 1
                  ? '1 item in ${label.toLowerCase()}'
                  : '${count!} items in ${label.toLowerCase()}',
              waitDuration: const Duration(milliseconds: 500),
              child: Text(
                '${count!}',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: tokens.text3.withValues(alpha: 0.7),
                  fontFamily: 'JetBrainsMono',
                ),
              ),
            ),
          ],
          const Spacer(),
          if (actionIcon != null)
            MouseRegion(
              cursor: onAction == null
                  ? SystemMouseCursors.basic
                  : SystemMouseCursors.click,
              child: GestureDetector(
                onTap: onAction,
                child: actionTooltip == null
                    ? QuillIcon(actionIcon!,
                        size: 12,
                        strokeWidth: 1.7,
                        color: tokens.text3)
                    : Tooltip(
                        message: actionTooltip,
                        waitDuration: const Duration(milliseconds: 500),
                        child: QuillIcon(actionIcon!,
                            size: 12,
                            strokeWidth: 1.7,
                            color: tokens.text3),
                      ),
              ),
            ),
        ],
      ),
    );
  }
}
