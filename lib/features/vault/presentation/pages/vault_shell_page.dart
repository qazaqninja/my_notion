import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/db/quill_database.dart' hide Page;
import '../../../../shared/theme/quill_tokens.dart';
import '../../../commands/presentation/cubit/command_palette_cubit.dart';
import '../../../commands/presentation/widgets/command_palette_overlay.dart';
import '../../../database/data/repositories/database_repository_impl.dart';
import '../../../relations/domain/usecases/search_pages.dart';
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
        },
        child: Focus(
          focusNode: _rootFocus,
          autofocus: true,
          child: Scaffold(
            backgroundColor: tokens.bg,
            body: Stack(
              children: [
                Row(
                  children: [
                    SidebarWidget(activeUlid: widget.activeUlid),
                    Expanded(child: widget.child),
                  ],
                ),
                CommandPaletteOverlay(
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
                    // Actions are visual-only in v1 — the user can wire
                    // real handlers in subsequent milestones.
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
