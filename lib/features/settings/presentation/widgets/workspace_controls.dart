import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/theme/quill_tokens.dart';
import '../../../../shared/widgets/emoji_picker.dart';
import '../../../../shared/widgets/quill_overlays.dart';
import '../../../vault/presentation/bloc/vault_bloc.dart';
import '../../../vault/presentation/bloc/vault_event.dart';
import '../../../vault/presentation/bloc/vault_state.dart';

/// Workspace identity controls that the Settings → Vault pane
/// renders: the 32×32 emoji button (`WorkspaceIconButton`) and
/// the 300-px name field (`WorkspaceNameField`). Both write
/// `.quill.yaml` on commit and dispatch `RefreshFromDisk` so the
/// sidebar's WorkspaceHead picks up the new value.
///
/// Extracted from settings_page.dart in M1428 (FS-04 slice 4) —
/// fourth and second-to-last decomposition slice. Public widget
/// names match the underscore-stripped originals to keep the
/// import-site change mechanical.

/// Square button that opens the emoji picker to change
/// .quill.yaml's workspace.icon. Mirrors the sidebar's
/// WorkspaceHead affordance from M107 but lives here so users
/// browsing settings can find it too.
class WorkspaceIconButton extends StatelessWidget {
  const WorkspaceIconButton({super.key, required this.state});
  final VaultLoaded state;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    final icon = state.workspace.icon;
    final hasIcon = icon != null && icon.trim().isNotEmpty;
    return GestureDetector(
      onTap: () async {
        final picked = await pickEmoji(context);
        if (picked == null) return;
        final current = (icon ?? '').trim();
        final pickedTrimmed = picked.trim();
        if (current == pickedTrimmed) {
          if (!context.mounted) return;
          context.toastInfo(pickedTrimmed.isEmpty
              ? 'Workspace already has no icon'
              : 'Workspace icon already $pickedTrimmed');
          return;
        }
        final next =
            state.workspace.copyWith(icon: picked.isEmpty ? '' : picked);
        try {
          await next.save(Directory(state.rootPath));
        } catch (e) {
          if (!context.mounted) return;
          context.toastError('Could not save workspace icon', sub: '$e');
          return;
        }
        if (!context.mounted) return;
        context.read<VaultBloc>().add(const RefreshFromDisk());
        context.toastSuccess(picked.isEmpty
            ? 'Workspace icon cleared'
            : 'Workspace icon: $picked');
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Tooltip(
          message: hasIcon ? 'Change workspace icon' : 'Pick workspace icon',
          waitDuration: const Duration(milliseconds: 500),
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: hasIcon ? tokens.surface2 : tokens.accent,
              border: Border.all(color: tokens.divider2, width: 0.5),
              borderRadius: const BorderRadius.all(Radius.circular(6)),
            ),
            child: hasIcon
                ? Text(icon, style: const TextStyle(fontSize: 18))
                : Icon(Icons.tag_faces_outlined,
                    size: 16,
                    color: Theme.of(context).colorScheme.onPrimary),
          ),
        ),
      ),
    );
  }
}

/// TextField that edits .quill.yaml's workspace.name on commit
/// (focus loss or Enter). Clearing the field removes the override
/// so the sidebar falls back to the folder basename.
class WorkspaceNameField extends StatefulWidget {
  const WorkspaceNameField({super.key, required this.state});
  final VaultLoaded state;

  @override
  State<WorkspaceNameField> createState() => _WorkspaceNameFieldState();
}

class _WorkspaceNameFieldState extends State<WorkspaceNameField> {
  late final TextEditingController _ctl;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _ctl = TextEditingController(text: widget.state.workspace.name ?? '');
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    _ctl.dispose();
    super.dispose();
  }

  Future<void> _commit() async {
    final trimmed = _ctl.text.trim();
    final current = widget.state.workspace.name ?? '';
    if (trimmed == current) return;
    final next = widget.state.workspace.copyWith(
      name: trimmed.isEmpty ? '' : trimmed,
    );
    try {
      await next.save(Directory(widget.state.rootPath));
    } catch (e) {
      if (!mounted) return;
      context.toastError('Could not save workspace name', sub: '$e');
      return;
    }
    if (!mounted) return;
    context.read<VaultBloc>().add(const RefreshFromDisk());
    context.toastSuccess(trimmed.isEmpty
        ? 'Workspace name cleared'
        : 'Workspace name: $trimmed');
  }

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    return SizedBox(
      width: 300,
      child: TextField(
        controller: _ctl,
        focusNode: _focus,
        onSubmitted: (_) => _commit(),
        style: TextStyle(fontSize: 13, color: tokens.text),
        decoration: InputDecoration(
          isCollapsed: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          border: OutlineInputBorder(
            borderSide: BorderSide(color: tokens.divider2),
            borderRadius: const BorderRadius.all(Radius.circular(4)),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: tokens.divider2),
            borderRadius: const BorderRadius.all(Radius.circular(4)),
          ),
          hintText: widget.state.rootPath.split('/').last.replaceAll('_', ' '),
          hintStyle: TextStyle(fontSize: 13, color: tokens.text3),
        ),
      ),
    );
  }
}
