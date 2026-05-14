import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/side_item.dart';
import '../../domain/entities/vault_tree.dart';
import '../bloc/vault_bloc.dart';
import '../bloc/vault_event.dart';
import '../bloc/vault_state.dart';

/// Recursive tree row. Folders are tappable to toggle; files are tappable to
/// open the editor.
class TreeNodeWidget extends StatelessWidget {
  const TreeNodeWidget({
    super.key,
    required this.node,
    required this.level,
    required this.expandedFolders,
    required this.activeUlid,
  });

  final VaultNode node;
  final int level;
  final Set<String> expandedFolders;
  final String? activeUlid;

  @override
  Widget build(BuildContext context) {
    final n = node;
    if (n is VaultFolder) {
      final open = expandedFolders.contains(n.relativePath);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SideItem(
            level: level,
            icon: 'folder',
            label: n.name,
            chevron: open ? SideChevron.open : SideChevron.closed,
            onTap: () => context.read<VaultBloc>().add(ToggleFolder(n.relativePath)),
            mute: !open,
          ),
          if (open)
            for (final child in n.children)
              TreeNodeWidget(
                node: child,
                level: level + 1,
                expandedFolders: expandedFolders,
                activeUlid: activeUlid,
              ),
        ],
      );
    }
    if (n is VaultFile) {
      return SideItem(
        level: level,
        icon: 'file-md',
        label: n.name,
        active: n.ulid == activeUlid && n.ulid.isNotEmpty,
        onTap: () => n.ulid.isNotEmpty ? context.go('/editor/${n.ulid}') : null,
      );
    }
    return const SizedBox.shrink();
  }
}

/// Stateless adapter — reads vault state and renders the top-level tree.
class TreeRoot extends StatelessWidget {
  const TreeRoot({super.key, required this.activeUlid});
  final String? activeUlid;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<VaultBloc>().state;
    if (state is! VaultLoaded) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final node in state.tree.topLevel)
          TreeNodeWidget(
            node: node,
            level: 0,
            expandedFolders: state.expandedFolders,
            activeUlid: activeUlid,
          ),
      ],
    );
  }
}
