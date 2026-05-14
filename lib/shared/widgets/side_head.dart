import 'package:flutter/material.dart';

import '../theme/quill_tokens.dart';
import 'quill_icon.dart';

/// Sidebar section heading, matches `SideHead` from `primitives.jsx:110-122`.
class SideHead extends StatelessWidget {
  const SideHead({super.key, required this.label, this.actionIcon, this.onAction});
  final String label;
  final String? actionIcon;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Expanded(
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
          if (actionIcon != null)
            GestureDetector(
              onTap: onAction,
              child: QuillIcon(actionIcon!, size: 12, strokeWidth: 1.7, color: tokens.text3),
            ),
        ],
      ),
    );
  }
}
