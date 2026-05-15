import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/paths.dart';
import '../../../../shared/theme/quill_tokens.dart';
import '../../../../shared/theme/tokens.dart';
import '../../../../shared/widgets/kbd.dart';
import '../../../../shared/widgets/quill_icon.dart';
import '../../../database/domain/entities/database_schema.dart';
import '../../../relations/domain/usecases/search_pages.dart';
import '../../domain/command_entry.dart';
import '../cubit/command_palette_cubit.dart';

class CommandPaletteOverlay extends StatefulWidget {
  const CommandPaletteOverlay({
    super.key,
    required this.onPickPage,
    required this.onPickDatabase,
    required this.onInvokeAction,
  });

  final void Function(PageSearchResult) onPickPage;
  final void Function(DatabaseSchema) onPickDatabase;
  final void Function(CommandEntry) onInvokeAction;

  @override
  State<CommandPaletteOverlay> createState() => _CommandPaletteOverlayState();
}

class _CommandPaletteOverlayState extends State<CommandPaletteOverlay> {
  final FocusNode _focus = FocusNode();
  final TextEditingController _controller = TextEditingController();
  CommandPaletteCubit? _cubit;

  @override
  void dispose() {
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CommandPaletteCubit, CommandPaletteState>(
      listener: (context, state) {
        _cubit ??= context.read<CommandPaletteCubit>();
        if (state.open && !_focus.hasFocus) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
        }
        if (!state.open) {
          _controller.clear();
        }
      },
      builder: (context, state) {
        if (!state.open) return const SizedBox.shrink();
        final tokens = QuillTokens.of(context);
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => context.read<CommandPaletteCubit>().dismiss(),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  color: tokens.isDark
                      ? Colors.black.withValues(alpha: 0.45)
                      : const Color.fromRGBO(40, 38, 33, 0.22),
                ),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 200),
                child: Material(
                  color: Colors.transparent,
                  child: _Panel(
                    state: state,
                    tokens: tokens,
                    focus: _focus,
                    controller: _controller,
                    onPickPage: widget.onPickPage,
                    onPickDatabase: widget.onPickDatabase,
                    onInvokeAction: widget.onInvokeAction,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.state,
    required this.tokens,
    required this.focus,
    required this.controller,
    required this.onPickPage,
    required this.onPickDatabase,
    required this.onInvokeAction,
  });

  final CommandPaletteState state;
  final QuillTokens tokens;
  final FocusNode focus;
  final TextEditingController controller;
  final void Function(PageSearchResult) onPickPage;
  final void Function(DatabaseSchema) onPickDatabase;
  final void Function(CommandEntry) onInvokeAction;

  @override
  Widget build(BuildContext context) {
    // Responsive width: thumb-friendly full-width minus margin on
    // narrow viewports, capped at 580px on desktop so the palette
    // doesn't sprawl across wide monitors.
    final screenW = MediaQuery.of(context).size.width;
    final width =
        screenW < 640 ? (screenW - 16).clamp(280.0, 580.0) : 580.0;
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border.all(color: tokens.divider2, width: 0.5),
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        boxShadow: [
          BoxShadow(
            color: tokens.isDark
                ? Colors.black.withValues(alpha: 0.55)
                : Colors.black.withValues(alpha: 0.15),
            blurRadius: 80,
            offset: const Offset(0, 32),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Search header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: tokens.divider, width: 0.5)),
            ),
            child: Row(
              children: [
                QuillIcon('search', size: 15, strokeWidth: 1.7, color: tokens.text3),
                const SizedBox(width: 10),
                Expanded(
                  child: KeyboardListener(
                    focusNode: FocusNode(),
                    onKeyEvent: _handleKey(context),
                    child: TextField(
                      focusNode: focus,
                      controller: controller,
                      autofocus: true,
                      decoration: const InputDecoration.collapsed(hintText: 'Search pages, databases, commands…'),
                      style: TextStyle(fontSize: 14, color: tokens.text),
                      onChanged: (v) => context.read<CommandPaletteCubit>().setQuery(v),
                    ),
                  ),
                ),
                Text('pages · databases · commands', style: mono(fontSize: 11, color: tokens.text3)),
              ],
            ),
          ),
          // Results
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (state.pages.isNotEmpty)
                    _Group(
                      label: 'Pages',
                      tokens: tokens,
                      children: [
                        for (int i = 0; i < state.pages.length; i++)
                          _ResultRow(
                            tokens: tokens,
                            icon: 'file-md',
                            emojiIcon: state.pages[i].emojiIcon,
                            label: state.pages[i].title,
                            hint: stripMdExtension(
                                state.pages[i].relativePath),
                            selected: state.selectedIndex == i,
                            onTap: () => onPickPage(state.pages[i]),
                            onHover: () => context
                                .read<CommandPaletteCubit>()
                                .setSelection(i),
                          ),
                      ],
                    ),
                  if (state.databases.isNotEmpty)
                    _Group(
                      label: 'Databases',
                      tokens: tokens,
                      children: [
                        for (int j = 0; j < state.databases.length; j++)
                          _ResultRow(
                            tokens: tokens,
                            icon: 'database',
                            label: 'Open ${state.databases[j].name}',
                            hint: 'Database',
                            selected: state.selectedIndex == state.pages.length + j,
                            onTap: () => onPickDatabase(state.databases[j]),
                            onHover: () => context
                                .read<CommandPaletteCubit>()
                                .setSelection(state.pages.length + j),
                          ),
                      ],
                    ),
                  if (state.actions.isNotEmpty)
                    _Group(
                      label: 'Actions',
                      tokens: tokens,
                      children: [
                        for (int k = 0; k < state.actions.length; k++)
                          _ResultRow(
                            tokens: tokens,
                            icon: state.actions[k].icon,
                            label: state.actions[k].label,
                            hint: state.actions[k].hint,
                            selected: state.selectedIndex ==
                                state.pages.length + state.databases.length + k,
                            onTap: () => onInvokeAction(state.actions[k]),
                            onHover: () => context
                                .read<CommandPaletteCubit>()
                                .setSelection(state.pages.length +
                                    state.databases.length +
                                    k),
                          ),
                      ],
                    ),
                  if (state.totalResults == 0)
                    Padding(
                      padding: const EdgeInsets.all(28),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            QuillIcon('search',
                                size: 22,
                                strokeWidth: 1.4,
                                color: tokens.text3),
                            const SizedBox(height: 8),
                            Text(
                              'No matches',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: tokens.text2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              state.query.isEmpty
                                  ? 'Start typing to search pages, databases, and commands.\nFilters: db: · tag: · in: · path: · folder:'
                                  : 'No pages, databases, or commands match "${state.query}".',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: tokens.text3,
                                  height: 1.5),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: tokens.surface2,
              border: Border(top: BorderSide(color: tokens.divider, width: 0.5)),
            ),
            child: Row(
              children: [
                _FooterKbd(tokens: tokens, label: 'nav', children: const [Kbd('↑'), Kbd('↓')]),
                const SizedBox(width: 12),
                _FooterKbd(tokens: tokens, label: 'open', children: const [Kbd('↵')]),
                const SizedBox(width: 12),
                _FooterKbd(tokens: tokens, label: 'close', children: const [Kbd('esc')]),
                const Spacer(),
                Text(
                  '${state.totalResults} ${state.totalResults == 1 ? 'result' : 'results'}',
                  style: mono(fontSize: 11, color: tokens.text3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void Function(KeyEvent) _handleKey(BuildContext context) {
    return (event) {
      if (event is! KeyDownEvent) return;
      final key = event.logicalKey;
      if (key == LogicalKeyboardKey.escape) {
        context.read<CommandPaletteCubit>().dismiss();
      } else if (key == LogicalKeyboardKey.arrowDown) {
        context.read<CommandPaletteCubit>().moveSelection(1);
      } else if (key == LogicalKeyboardKey.arrowUp) {
        context.read<CommandPaletteCubit>().moveSelection(-1);
      } else if (key == LogicalKeyboardKey.enter) {
        final cubit = context.read<CommandPaletteCubit>();
        final item = cubit.selectedItem();
        if (item is PageSearchResult) {
          onPickPage(item);
        } else if (item is DatabaseSchema) {
          onPickDatabase(item);
        } else if (item is CommandEntry) {
          onInvokeAction(item);
        }
      }
    };
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.label, required this.tokens, required this.children});
  final String label;
  final QuillTokens tokens;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
            child: Row(
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                    color: tokens.text3,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${children.length}',
                  style: mono(fontSize: 10.5, color: tokens.text3),
                ),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.tokens,
    required this.icon,
    required this.label,
    required this.hint,
    required this.selected,
    required this.onTap,
    this.onHover,
    this.emojiIcon,
  });

  final QuillTokens tokens;
  final String icon;
  final String label;
  final String hint;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onHover;

  /// Plain-emoji glyph rendered in place of [icon] when non-null.
  final String? emojiIcon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: onHover == null ? null : (_) => onHover!(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? tokens.hover : Colors.transparent,
            border: selected
                ? Border(left: BorderSide(color: tokens.accent, width: 2))
                : const Border(left: BorderSide(color: Colors.transparent, width: 2)),
          ),
          child: Row(
            children: [
              if (emojiIcon != null)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: Center(
                    child: Text(emojiIcon!,
                        style: const TextStyle(fontSize: 13, height: 1)),
                  ),
                )
              else
                QuillIcon(icon,
                    size: 14, strokeWidth: 1.7, color: tokens.text2),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 13.5, color: tokens.text),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (hint.isNotEmpty)
                Text(hint, style: mono(fontSize: 11, color: tokens.text3)),
              if (selected) const Padding(padding: EdgeInsets.only(left: 8), child: Kbd('↵')),
            ],
          ),
        ),
      ),
    );
  }
}

class _FooterKbd extends StatelessWidget {
  const _FooterKbd({required this.tokens, required this.label, required this.children});
  final QuillTokens tokens;
  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...children.expand((c) => [c, const SizedBox(width: 2)]).take(children.length * 2 - 1),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11.5, color: tokens.text3)),
      ],
    );
  }
}
