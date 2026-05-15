import 'package:flutter/material.dart';

import '../../../../shared/theme/quill_tokens.dart';
import '../../../../shared/theme/tokens.dart';

/// Matches `WorkspaceHead` from `shell.jsx:6-30`. Accent square with
/// the workspace's first letter, name + mono path.
class WorkspaceHead extends StatelessWidget {
  const WorkspaceHead({
    super.key,
    required this.name,
    required this.vaultPath,
    this.icon,
    this.onIconTap,
    this.density = WorkspaceDensity.comfy,
  });

  final String name;
  final String vaultPath;

  /// Optional emoji / glyph stored in workspace.icon. Renders inside the
  /// accent square in place of the first-letter fallback when set.
  final String? icon;

  /// Tap target on the icon square — when set, opens the emoji picker
  /// so the user can change the workspace icon.
  final VoidCallback? onIconTap;
  final WorkspaceDensity density;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    final hasIcon = icon != null && icon!.trim().isNotEmpty;
    final square = Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: hasIcon ? tokens.surface2 : tokens.accent,
        borderRadius: const BorderRadius.all(Radius.circular(6)),
      ),
      child: hasIcon
          ? Text(
              icon!,
              style: TextStyle(fontSize: 15, color: tokens.text),
            )
          : Text(
              name.isNotEmpty ? name[0].toLowerCase() : 'q',
              style: mono(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
    );
    return Padding(
      padding: density == WorkspaceDensity.compact
          ? const EdgeInsets.fromLTRB(12, 10, 12, 8)
          : const EdgeInsets.fromLTRB(14, 14, 14, 10),
      child: Row(
        children: [
          if (onIconTap != null)
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: onIconTap,
                child: Tooltip(
                  message: 'Change workspace icon',
                  waitDuration: const Duration(milliseconds: 500),
                  child: square,
                ),
              ),
            )
          else
            square,
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Tooltip(
                  message: name,
                  waitDuration: const Duration(milliseconds: 600),
                  child: Text(
                    name,
                    style: TextStyle(
                      color: tokens.text,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                Tooltip(
                  message: vaultPath,
                  waitDuration: const Duration(milliseconds: 600),
                  child: Text(
                    vaultPath,
                    style: mono(fontSize: 11, color: tokens.text3),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    softWrap: false,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum WorkspaceDensity { comfy, compact }
