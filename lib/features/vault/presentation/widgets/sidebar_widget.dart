import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;

import '../../../../shared/theme/quill_tokens.dart';
import '../../../../shared/widgets/quill_icon.dart';
import '../../../../shared/widgets/side_head.dart';
import '../bloc/vault_bloc.dart';
import '../bloc/vault_state.dart';
import 'sidebar_search.dart';
import 'tree_node_widget.dart';
import 'workspace_head.dart';

/// Full sidebar. Matches `Sidebar` from `shell.jsx:72-126`.
class SidebarWidget extends StatelessWidget {
  const SidebarWidget({super.key, this.activeUlid, this.width = 260});

  final String? activeUlid;
  final double width;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    final state = context.watch<VaultBloc>().state;

    final workspaceName = state is VaultLoaded
        ? p.basename(state.rootPath).isNotEmpty
            ? p.basename(state.rootPath).replaceAll(RegExp(r'_+'), ' ').replaceFirstMapped(
                  RegExp(r'^[a-z]'),
                  (m) => m.group(0)!.toUpperCase(),
                )
            : 'Vault'
        : 'Vault';
    final vaultPath = state is VaultLoaded
        ? _abbreviateHome(state.rootPath)
        : 'No vault opened';
    final pageCount = state is VaultLoaded ? state.pageCount : 0;

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: tokens.sidebar,
        border: Border(right: BorderSide(color: tokens.divider, width: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WorkspaceHead(name: workspaceName, vaultPath: vaultPath),
          const SidebarSearch(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SideHead(label: 'Workspace', actionIcon: 'plus'),
                  TreeRoot(activeUlid: activeUlid),
                  const SideHead(label: 'Databases', actionIcon: 'plus'),
                  // Databases section will surface .database.yaml folders in M7.
                  // For now, placeholder when none.
                  if (state is VaultLoaded && state.tree.topLevel.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Text(
                        'No databases yet',
                        style: TextStyle(fontSize: 12, color: tokens.text3),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Text(
                        'No databases configured yet',
                        style: TextStyle(fontSize: 11.5, color: tokens.text3),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Footer: sync status + gear
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: tokens.divider, width: 0.5)),
            ),
            child: Row(
              children: [
                QuillIcon('sync', size: 12, strokeWidth: 1.7, color: tokens.text3),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    state is VaultLoaded ? '$pageCount pages indexed' : 'No vault',
                    style: TextStyle(fontSize: 11.5, color: tokens.text3),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: () {},
                  child: QuillIcon('gear', size: 13, strokeWidth: 1.7, color: tokens.text3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _abbreviateHome(String path) {
    final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '';
    if (home.isNotEmpty && path.startsWith(home)) {
      return '~${path.substring(home.length)}';
    }
    return path;
  }
}
