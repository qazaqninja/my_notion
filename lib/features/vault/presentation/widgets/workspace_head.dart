import 'package:flutter/material.dart';

import '../../../../shared/theme/quill_tokens.dart';
import '../../../../shared/theme/tokens.dart';
import '../../../../shared/widgets/quill_icon.dart';

/// Matches `WorkspaceHead` from `shell.jsx:6-30`. Accent square with
/// the workspace's first letter, name + mono path.
class WorkspaceHead extends StatelessWidget {
  const WorkspaceHead({
    super.key,
    required this.name,
    required this.vaultPath,
    this.density = WorkspaceDensity.comfy,
  });

  final String name;
  final String vaultPath;
  final WorkspaceDensity density;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    return Padding(
      padding: density == WorkspaceDensity.compact
          ? const EdgeInsets.fromLTRB(12, 10, 12, 8)
          : const EdgeInsets.fromLTRB(14, 14, 14, 10),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tokens.accent,
              borderRadius: const BorderRadius.all(Radius.circular(6)),
            ),
            child: Text(
              name.isNotEmpty ? name[0].toLowerCase() : 'q',
              style: mono(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: tokens.text,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
                Text(
                  vaultPath,
                  style: mono(fontSize: 11, color: tokens.text3),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  softWrap: false,
                ),
              ],
            ),
          ),
          QuillIcon('caret-down', size: 13, strokeWidth: 1.7, color: tokens.text3),
        ],
      ),
    );
  }
}

enum WorkspaceDensity { comfy, compact }
