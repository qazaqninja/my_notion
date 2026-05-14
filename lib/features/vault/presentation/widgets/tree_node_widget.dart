import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;

import '../../../../core/platform/reveal.dart';
import '../../../../shared/widgets/quill_icon.dart';
import '../../../../shared/theme/quill_tokens.dart';
import '../../../../shared/widgets/side_item.dart';
import '../../../editor/presentation/widgets/page_history_dialog.dart';
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
            onSecondaryTap: (pos) => _showFolderMenu(context, n, pos),
            trailingOnHover: _AddSubpageButton(
              onTap: () => _promptNewSubpage(context, folderPath: n.relativePath),
            ),
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
        onSecondaryTap: (pos) => _showFileMenu(context, n, pos),
      );
    }
    return const SizedBox.shrink();
  }

  Future<void> _showFolderMenu(
      BuildContext context, VaultFolder f, Offset pos) async {
    final state = context.read<VaultBloc>().state;
    if (state is! VaultLoaded) return;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(pos.dx, pos.dy, 1, 1),
        Offset.zero & overlay.size,
      ),
      items: const [
        PopupMenuItem(value: 'subpage', child: Text('New page here')),
        PopupMenuItem(value: 'reveal', child: Text('Reveal in Finder')),
      ],
    );
    if (!context.mounted) return;
    if (selected == 'subpage') {
      await _promptNewSubpage(context, folderPath: f.relativePath);
    } else if (selected == 'reveal') {
      await Reveal.show(p.join(state.rootPath, f.relativePath));
    }
  }

  Future<void> _showFileMenu(
      BuildContext context, VaultFile fl, Offset pos) async {
    final state = context.read<VaultBloc>().state;
    if (state is! VaultLoaded) return;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(pos.dx, pos.dy, 1, 1),
        Offset.zero & overlay.size,
      ),
      items: const [
        PopupMenuItem(value: 'reveal', child: Text('Reveal in Finder')),
        PopupMenuItem(value: 'copy-ulid', child: Text('Copy ULID')),
        PopupMenuItem(value: 'duplicate', child: Text('Duplicate page')),
        PopupMenuItem(value: 'history', child: Text('Page history')),
        PopupMenuDivider(),
        PopupMenuItem(value: 'trash', child: Text('Move to trash')),
      ],
    );
    if (!context.mounted) return;
    if (selected == 'reveal') {
      await Reveal.show(p.join(state.rootPath, fl.relativePath));
    } else if (selected == 'copy-ulid') {
      await _copyUlid(context, fl.ulid);
    } else if (selected == 'history') {
      await showDialog(
        context: context,
        builder: (_) => PageHistoryDialog(
          vaultRoot: state.rootPath,
          relativePath: fl.relativePath,
        ),
      );
    } else if (selected == 'duplicate') {
      if (fl.ulid.isEmpty) return;
      final router = GoRouter.of(context);
      context.read<VaultBloc>().add(DuplicatePage(
            fl.ulid,
            onCreated: (newUlid) => router.go('/editor/$newUlid'),
          ));
    } else if (selected == 'trash') {
      if (fl.ulid.isEmpty) return;
      context.read<VaultBloc>().add(MoveToTrash(fl.ulid));
    }
  }

  Future<void> _copyUlid(BuildContext context, String ulid) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (ulid.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: ulid));
    }
    messenger?.showSnackBar(SnackBar(
        content: Text(ulid.isEmpty ? 'No ULID for this page' : 'Copied $ulid'),
        duration: const Duration(seconds: 2)));
  }

  Future<void> _promptNewSubpage(BuildContext context,
      {required String folderPath}) async {
    final controller = TextEditingController();
    final router = GoRouter.of(context);
    final bloc = context.read<VaultBloc>();
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New subpage'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: 'Title  ·  in $folderPath/'),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (title == null || title.trim().isEmpty) return;
    bloc.add(CreatePage(
      title: title.trim(),
      folderPath: folderPath,
      onCreated: (ulid) => router.go('/editor/$ulid'),
    ));
  }
}

class _AddSubpageButton extends StatelessWidget {
  const _AddSubpageButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: QuillIcon('plus', size: 12, strokeWidth: 1.7, color: tokens.text3),
        ),
      ),
    );
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
