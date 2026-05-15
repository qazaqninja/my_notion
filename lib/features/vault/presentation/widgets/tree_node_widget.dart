import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;

import '../../../../core/platform/reveal.dart';
import '../../../commands/presentation/cubit/command_palette_cubit.dart';
import '../../../../shared/widgets/quill_icon.dart';
import '../../../../shared/widgets/quill_overlays.dart';
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
          DragTarget<String>(
            onWillAcceptWithDetails: (_) => true,
            onAcceptWithDetails: (d) {
              context.read<VaultBloc>().add(
                    MovePage(ulid: d.data, targetFolder: n.relativePath),
                  );
              context.toastSuccess('Moved to ${n.relativePath}/');
            },
            builder: (context, candidate, _) {
              final hovering = candidate.isNotEmpty;
              return Container(
                decoration: hovering
                    ? BoxDecoration(
                        color: QuillTokens.of(context).accentTint,
                      )
                    : null,
                child: SideItem(
                  level: level,
                  icon: 'folder',
                  label: n.name,
                  chevron:
                      open ? SideChevron.open : SideChevron.closed,
                  onTap: () => context
                      .read<VaultBloc>()
                      .add(ToggleFolder(n.relativePath)),
                  onSecondaryTap: (pos) => _showFolderMenu(context, n, pos),
                  trailingOnHover: _AddSubpageButton(
                    onTap: () => _promptNewSubpage(context,
                        folderPath: n.relativePath),
                  ),
                  mute: !open,
                ),
              );
            },
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
      final state = context.watch<VaultBloc>().state;
      final pinned = state is VaultLoaded &&
          n.ulid.isNotEmpty &&
          state.workspace.favorites.contains(n.ulid);
      // When the page's frontmatter declares an emoji `icon:`, use that
      // as a glyph in place of the generic file-md icon.
      final emoji = n.icon;
      final inner = SideItem(
        level: level,
        icon: emoji == null ? 'file-md' : null,
        emojiIcon: emoji,
        label: n.name,
        active: n.ulid == activeUlid && n.ulid.isNotEmpty,
        onTap: () => n.ulid.isNotEmpty ? context.go('/editor/${n.ulid}') : null,
        onSecondaryTap: (pos) => _showFileMenu(context, n, pos),
        alwaysTrailing: pinned
            ? Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Tooltip(
                  message: 'Pinned to favorites',
                  waitDuration: const Duration(milliseconds: 500),
                  child: Icon(Icons.star,
                      size: 11,
                      color: QuillTokens.of(context)
                          .accent
                          .withValues(alpha: 0.85)),
                ),
              )
            : null,
      );
      if (n.ulid.isEmpty) return inner;
      return Draggable<String>(
        data: n.ulid,
        feedback: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: QuillTokens.of(context).surface,
              border:
                  Border.all(color: QuillTokens.of(context).divider2, width: 0.5),
              borderRadius: const BorderRadius.all(Radius.circular(4)),
            ),
            child: Text(
              n.name,
              style: TextStyle(
                fontSize: 13,
                color: QuillTokens.of(context).text2,
              ),
            ),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.4, child: inner),
        child: inner,
      );
    }
    return const SizedBox.shrink();
  }

  Future<void> _showFolderMenu(
      BuildContext context, VaultFolder f, Offset pos) async {
    final state = context.read<VaultBloc>().state;
    if (state is! VaultLoaded) return;
    final selected = await showQuillMenu<String>(
      context: context,
      position: quillMenuPosition(context, pos),
      width: 232,
      items: const [
        QuillMenuItem(icon: 'plus', label: 'New page here', value: 'subpage'),
        QuillMenuItem(icon: 'folder', label: 'New subfolder…', value: 'subfolder'),
        QuillMenuItem(icon: 'search', label: 'Search this folder…', value: 'search'),
        QuillMenuItem(icon: 'link', label: 'Copy folder path', value: 'copy-path'),
        QuillMenuItem(icon: 'reveal', label: 'Reveal in Finder', value: 'reveal'),
      ],
    );
    if (!context.mounted) return;
    if (selected == 'subpage') {
      await _promptNewSubpage(context, folderPath: f.relativePath);
    } else if (selected == 'subfolder') {
      await _promptNewSubfolder(context, parentFolder: f.relativePath);
    } else if (selected == 'search') {
      final cubit = context.read<CommandPaletteCubit>();
      cubit.open();
      cubit.setQuery('path:${f.relativePath}/');
    } else if (selected == 'copy-path') {
      final path = p.join(state.rootPath, f.relativePath);
      await Clipboard.setData(ClipboardData(text: path));
      if (context.mounted) context.toastSuccess('Copied path', sub: path, subMono: true);
    } else if (selected == 'reveal') {
      final path = p.join(state.rootPath, f.relativePath);
      final ok = await Reveal.show(path);
      if (!ok && context.mounted) {
        context.toastError('Could not reveal', sub: path, subMono: true);
      }
    }
  }

  Future<void> _promptNewSubfolder(BuildContext context,
      {required String parentFolder}) async {
    final bloc = context.read<VaultBloc>();
    final name = await showQuillPrompt(
      context,
      title: 'New subfolder',
      icon: 'folder',
      label: 'Folder name',
      hint: parentFolder.isEmpty ? null : 'in $parentFolder/',
      confirmLabel: 'Create',
    );
    if (name == null || name.isEmpty) return;
    bloc.add(CreateFolder(parentFolder: parentFolder, name: name));
    if (!context.mounted) return;
    final fullPath = parentFolder.isEmpty ? name : '$parentFolder/$name';
    context.toastSuccess('Created folder', sub: fullPath, subMono: true);
  }

  Future<void> _showFileMenu(
      BuildContext context, VaultFile fl, Offset pos) async {
    final state = context.read<VaultBloc>().state;
    if (state is! VaultLoaded) return;
    final pinned = state.workspace.favorites.contains(fl.ulid);
    final selected = await showQuillMenu<String>(
      context: context,
      position: quillMenuPosition(context, pos),
      width: 244,
      items: [
        const QuillMenuItem(icon: 'reveal', label: 'Reveal in Finder', value: 'reveal'),
        const QuillMenuItem(icon: 'link', label: 'Copy ULID', value: 'copy-ulid'),
        const QuillMenuItem(icon: 'link', label: 'Copy [[link]]', value: 'copy-link'),
        const QuillMenuItem(icon: 'folder', label: 'Copy file path', value: 'copy-path'),
        const QuillMenuItem(icon: 'note', label: 'Duplicate page', value: 'duplicate'),
        const QuillMenuItem(icon: 'edit', label: 'Rename file…', value: 'rename'),
        const QuillMenuItem(icon: 'clock', label: 'Page history', value: 'history'),
        QuillMenuItem(
          icon: 'pin',
          label: pinned ? 'Unpin from favorites' : 'Pin to favorites',
          value: 'pin',
        ),
        QuillMenuItem.separator<String>(),
        const QuillMenuItem(
          icon: 'trash',
          label: 'Move to trash',
          hint: '⌫',
          danger: true,
          value: 'trash',
        ),
      ],
    );
    if (!context.mounted) return;
    if (selected == 'reveal') {
      final path = p.join(state.rootPath, fl.relativePath);
      final ok = await Reveal.show(path);
      if (!ok && context.mounted) {
        context.toastError('Could not reveal', sub: path, subMono: true);
      }
    } else if (selected == 'copy-ulid') {
      await _copyUlid(context, fl.ulid);
    } else if (selected == 'copy-link') {
      if (fl.ulid.isEmpty) return;
      await Clipboard.setData(ClipboardData(text: '[[${fl.ulid}]]'));
      if (context.mounted) context.toastSuccess('Copied [[${fl.ulid}]]', subMono: true);
    } else if (selected == 'copy-path') {
      final path = p.join(state.rootPath, fl.relativePath);
      await Clipboard.setData(ClipboardData(text: path));
      if (context.mounted) context.toastSuccess('Copied path', sub: path, subMono: true);
    } else if (selected == 'history') {
      await showQuillModal<void>(
        context,
        builder: (_) => PageHistoryDialog(
          vaultRoot: state.rootPath,
          relativePath: fl.relativePath,
        ),
      );
    } else if (selected == 'duplicate') {
      if (fl.ulid.isEmpty) return;
      final router = GoRouter.of(context);
      final scope = context;
      final sourceName = fl.name;
      context.read<VaultBloc>().add(DuplicatePage(
            fl.ulid,
            onCreated: (newUlid) {
              if (scope.mounted) {
                scope.toastSuccess(
                    sourceName.isEmpty
                        ? 'Page duplicated'
                        : 'Duplicated "$sourceName"',
                    sub: 'New ULID: $newUlid',
                    subMono: true);
              }
              router.go('/editor/$newUlid');
            },
          ));
    } else if (selected == 'rename') {
      if (fl.ulid.isEmpty) return;
      await _promptRenameFile(context, fl);
    } else if (selected == 'pin') {
      if (fl.ulid.isEmpty) return;
      context.read<VaultBloc>().add(ToggleFavorite(fl.ulid));
    } else if (selected == 'trash') {
      if (fl.ulid.isEmpty) return;
      final now = DateTime.now();
      final bucket =
          '${now.year}-${now.month.toString().padLeft(2, '0')}';
      final confirmed = await showQuillConfirm(
        context,
        title: 'Move to trash?',
        sub:
            'The .md file moves to .trash/$bucket/${fl.relativePath}. '
            'You can restore it from the Trash dialog later.',
        icon: 'trash',
        confirmLabel: 'Move to trash',
        danger: true,
      );
      if (!confirmed || !context.mounted) return;
      context.read<VaultBloc>().add(MoveToTrash(fl.ulid));
      context.toastSuccess('Moved to trash', sub: fl.name);
    }
  }

  Future<void> _copyUlid(BuildContext context, String ulid) async {
    if (ulid.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: ulid));
    }
    if (!context.mounted) return;
    if (ulid.isEmpty) {
      context.toastError('No ULID for this page');
    } else {
      context.toastSuccess('Copied $ulid', subMono: true);
    }
  }

  Future<void> _promptRenameFile(BuildContext context, VaultFile fl) async {
    final basename = p.basenameWithoutExtension(fl.relativePath);
    final bloc = context.read<VaultBloc>();
    final picked = await showQuillPrompt(
      context,
      title: 'Rename file',
      icon: 'edit',
      label: 'New name',
      hint: 'ULID is unchanged — wikilinks survive the rename.',
      placeholder: 'new-name (without .md)',
      initial: basename,
      confirmLabel: 'Rename',
    );
    if (picked == null || picked.isEmpty) return;
    bloc.add(RenamePage(ulid: fl.ulid, newBasename: picked));
    if (!context.mounted) return;
    // Mirror _safeFileName so the toast reflects what lands on disk.
    var preview = picked
        .replaceAll(RegExp(r'[\\/<>:"|?*]+'), '-')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (preview.toLowerCase().endsWith('.md')) {
      preview = preview.substring(0, preview.length - 3).trim();
    }
    if (preview.isEmpty) preview = 'Untitled';
    context.toastSuccess('Renamed to $preview.md');
  }

  Future<void> _promptNewSubpage(BuildContext context,
      {required String folderPath}) async {
    final router = GoRouter.of(context);
    final bloc = context.read<VaultBloc>();
    final scope = context;
    final title = await showQuillPrompt(
      context,
      title: 'New subpage',
      icon: 'file-md',
      label: 'Title',
      hint: 'in $folderPath/',
      confirmLabel: 'Create',
    );
    if (title == null || title.isEmpty) return;
    bloc.add(CreatePage(
      title: title,
      folderPath: folderPath,
      onCreated: (ulid) {
        if (scope.mounted) {
          scope.toastSuccess('Created "$title" in $folderPath/',
              sub: 'ULID: $ulid', subMono: true);
        }
        router.go('/editor/$ulid');
      },
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
        child: Tooltip(
          message: 'New page in this folder',
          waitDuration: const Duration(milliseconds: 500),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: QuillIcon('plus',
                size: 12, strokeWidth: 1.7, color: tokens.text3),
          ),
        ),
      ),
    );
  }
}

/// Stateless adapter — reads vault state and renders the top-level tree.
class TreeRoot extends StatelessWidget {
  const TreeRoot({super.key, required this.activeUlid, this.filter = ''});
  final String? activeUlid;

  /// Non-empty filter narrows the tree to nodes whose name contains
  /// the query (case-insensitive), plus their ancestor folders. Empty
  /// = no filtering.
  final String filter;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<VaultBloc>().state;
    if (state is! VaultLoaded) return const SizedBox.shrink();
    final tokens = QuillTokens.of(context);

    final q = filter.toLowerCase();
    final activeFilter = q.isNotEmpty;
    final visible = activeFilter
        ? _filterNodes(state.tree.topLevel, q)
        : state.tree.topLevel;
    // When filtering, expand every visible folder so matches are reachable
    // without manual clicking. Otherwise, union the user's expandedFolders
    // with the ancestor folder paths of the active page so navigating
    // anywhere auto-reveals the source in the tree.
    final Set<String> expanded;
    if (activeFilter) {
      expanded = _allFolderPaths(visible);
    } else if (activeUlid != null) {
      expanded = {
        ...state.expandedFolders,
        ..._ancestorsOf(state.tree.topLevel, activeUlid!),
      };
    } else {
      expanded = state.expandedFolders;
    }

    return DragTarget<String>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (d) {
        context
            .read<VaultBloc>()
            .add(MovePage(ulid: d.data, targetFolder: ''));
        context.toastSuccess('Moved to vault root');
      },
      builder: (context, candidate, _) {
        final hovering = candidate.isNotEmpty;
        return Container(
          decoration: hovering
              ? BoxDecoration(
                  border: Border.all(color: tokens.accent, width: 1),
                  borderRadius:
                      const BorderRadius.all(Radius.circular(4)),
                )
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (state.tree.topLevel.isEmpty)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Empty vault',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: tokens.text2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Use ⌘N to add a page.',
                        style: TextStyle(fontSize: 11, color: tokens.text3),
                      ),
                    ],
                  ),
                ),
              if (state.tree.topLevel.isNotEmpty && visible.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No matches',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: tokens.text2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Clear the filter to see the full tree.',
                        style:
                            TextStyle(fontSize: 11, color: tokens.text3),
                      ),
                    ],
                  ),
                ),
              for (final node in visible)
                TreeNodeWidget(
                  node: node,
                  level: 0,
                  expandedFolders: expanded,
                  activeUlid: activeUlid,
                ),
            ],
          ),
        );
      },
    );
  }

  /// Walk [nodes] keeping any file whose name contains [q] and any
  /// folder that has a matching descendant. Order preserved.
  static List<VaultNode> _filterNodes(List<VaultNode> nodes, String q) {
    final out = <VaultNode>[];
    for (final node in nodes) {
      if (node is VaultFile) {
        if (node.name.toLowerCase().contains(q)) out.add(node);
      } else if (node is VaultFolder) {
        final keptChildren = _filterNodes(node.children, q);
        if (keptChildren.isNotEmpty ||
            node.name.toLowerCase().contains(q)) {
          out.add(VaultFolder(
            name: node.name,
            relativePath: node.relativePath,
            children: keptChildren,
          ));
        }
      }
    }
    return out;
  }

  /// Folder paths that should be open so the file with [activeUlid]
  /// is visible in the tree. Returns an empty set when the ULID isn't
  /// found (the page might be in trash or pre-index).
  static Set<String> _ancestorsOf(List<VaultNode> nodes, String activeUlid) {
    final stack = <String>[];
    Set<String>? hit;
    void walk(List<VaultNode> level) {
      if (hit != null) return;
      for (final n in level) {
        if (n is VaultFile && n.ulid == activeUlid) {
          hit = {...stack};
          return;
        }
        if (n is VaultFolder) {
          stack.add(n.relativePath);
          walk(n.children);
          if (hit != null) return;
          stack.removeLast();
        }
      }
    }
    walk(nodes);
    return hit ?? const {};
  }

  static Set<String> _allFolderPaths(List<VaultNode> nodes) {
    final out = <String>{};
    void walk(VaultNode n) {
      if (n is VaultFolder) {
        out.add(n.relativePath);
        for (final c in n.children) {
          walk(c);
        }
      }
    }
    for (final n in nodes) {
      walk(n);
    }
    return out;
  }
}
