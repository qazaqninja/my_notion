import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/db/quill_database.dart' hide Page;
import '../../../../core/platform/reveal.dart';
import '../../../../shared/theme/quill_tokens.dart';
import '../../../../shared/theme/theme_cubit.dart';
import '../../../commands/presentation/cubit/command_palette_cubit.dart';
import '../../../commands/presentation/widgets/command_palette_overlay.dart';
import '../../../database/data/repositories/database_repository_impl.dart';
import '../../../relations/domain/usecases/search_pages.dart';
import '../../../../shared/widgets/responsive_layout.dart';
import '../../data/exporter.dart';
import '../bloc/vault_bloc.dart';
import '../bloc/vault_event.dart';
import '../bloc/vault_state.dart';
import '../widgets/mobile_chrome.dart';
import '../widgets/sidebar_widget.dart';

/// Desktop shell — sidebar on the left, child route content on the right,
/// ⌘K / Ctrl+K command palette on top.
class VaultShellPage extends StatefulWidget {
  const VaultShellPage({super.key, required this.child, this.activeUlid});

  final Widget child;
  final String? activeUlid;

  @override
  State<VaultShellPage> createState() => _VaultShellPageState();
}

class _VaultShellPageState extends State<VaultShellPage> {
  CommandPaletteCubit? _palette;
  final FocusNode _rootFocus = FocusNode(skipTraversal: true);

  @override
  void initState() {
    super.initState();
  }

  CommandPaletteCubit _cubit(BuildContext context) {
    return _palette ??= CommandPaletteCubit(
      searchPages: SearchPages(context.read<QuillDatabase>()),
      dbRepo: DatabaseRepositoryImpl(context.read<QuillDatabase>()),
    );
  }

  @override
  void dispose() {
    _palette?.close();
    _rootFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    return BlocProvider<CommandPaletteCubit>.value(
      value: _cubit(context),
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () {
            _cubit(context).open();
          },
          const SingleActivator(LogicalKeyboardKey.keyK, control: true): () {
            _cubit(context).open();
          },
          const SingleActivator(LogicalKeyboardKey.keyR, meta: true): () {
            _invokeAction(context, 'Reindex vault');
          },
          const SingleActivator(LogicalKeyboardKey.keyR, control: true): () {
            _invokeAction(context, 'Reindex vault');
          },
          const SingleActivator(LogicalKeyboardKey.keyR, meta: true, shift: true): () {
            _invokeAction(context, 'Reveal vault in Finder');
          },
          const SingleActivator(LogicalKeyboardKey.keyR, control: true, shift: true): () {
            _invokeAction(context, 'Reveal vault in Finder');
          },
        },
        child: Focus(
          focusNode: _rootFocus,
          autofocus: true,
          child: ResponsiveLayout(
            desktop: Scaffold(
              backgroundColor: tokens.bg,
              body: Stack(
                children: [
                  Row(
                    children: [
                      SidebarWidget(activeUlid: widget.activeUlid),
                      Expanded(child: widget.child),
                    ],
                  ),
                  _paletteOverlay(context),
                ],
              ),
            ),
            mobile: Scaffold(
              backgroundColor: tokens.bg,
              drawer: Drawer(
                width: 300,
                backgroundColor: tokens.sidebar,
                child: SidebarWidget(activeUlid: widget.activeUlid, width: 300),
              ),
              body: Stack(
                children: [
                  Column(
                    children: [
                      Expanded(child: widget.child),
                      const MobileTabBar(),
                    ],
                  ),
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 4,
                    left: 4,
                    child: Builder(
                      builder: (innerContext) => IconButton(
                        icon: Icon(Icons.menu, color: tokens.text2, size: 18),
                        onPressed: () => Scaffold.of(innerContext).openDrawer(),
                      ),
                    ),
                  ),
                  _paletteOverlay(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _invokeAction(BuildContext context, String label) async {
    final vaultBloc = context.read<VaultBloc>();
    final themeCubit = context.read<ThemeCubit>();
    final vaultState = vaultBloc.state;
    final vaultPath = vaultState is VaultLoaded ? vaultState.rootPath : null;
    final messenger = ScaffoldMessenger.maybeOf(context);

    switch (label) {
      case 'Reveal vault in Finder':
        if (vaultPath == null) {
          messenger?.showSnackBar(
            const SnackBar(content: Text('No vault open')),
          );
          return;
        }
        final ok = await Reveal.show(vaultPath);
        if (!ok) {
          messenger?.showSnackBar(
            SnackBar(content: Text('Could not open $vaultPath')),
          );
        }
      case 'Export vault to folder':
        if (vaultPath == null) {
          messenger?.showSnackBar(
            const SnackBar(content: Text('No vault open')),
          );
          return;
        }
        final dest = await FilePicker.platform.getDirectoryPath(
          dialogTitle: 'Export vault to…',
        );
        if (dest == null) return;
        try {
          final n = await const VaultExporter().export(
            src: Directory(vaultPath),
            dest: Directory(dest),
          );
          messenger?.showSnackBar(
            SnackBar(
              content: Text('Exported $n files to $dest'),
              duration: const Duration(seconds: 4),
            ),
          );
        } catch (e) {
          messenger?.showSnackBar(
            SnackBar(content: Text('Export failed: $e')),
          );
        }
      case 'Reindex vault':
        vaultBloc.add(const ReindexVault());
        messenger?.showSnackBar(
          const SnackBar(content: Text('Reindexing vault…')),
        );
      case 'Toggle theme':
        await themeCubit.cycleMode();
    }
  }

  Widget _paletteOverlay(BuildContext context) {
    return CommandPaletteOverlay(
      onPickPage: (p) {
        context.read<CommandPaletteCubit>().dismiss();
        context.go('/editor/${p.ulid}');
      },
      onPickDatabase: (d) {
        context.read<CommandPaletteCubit>().dismiss();
        context.go('/db/${d.id}');
      },
      onInvokeAction: (a) {
        context.read<CommandPaletteCubit>().dismiss();
        _invokeAction(context, a.label);
      },
    );
  }
}
