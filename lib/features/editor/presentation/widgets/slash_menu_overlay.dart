import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/theme/quill_tokens.dart';
import '../../../../shared/theme/tokens.dart';
import '../../../../shared/widgets/kbd.dart';
import '../../../../shared/widgets/quill_icon.dart';
import '../../domain/slash_entries.dart';
import '../cubit/slash_menu_cubit.dart';

/// 320-px popover that anchors below the caret. Shows filterable list of
/// markdown-snippet entries; activating one calls [onPick].
class SlashMenuOverlay extends StatelessWidget {
  const SlashMenuOverlay({super.key, required this.onPick, required this.onDismiss});

  final void Function(SlashEntry) onPick;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    return BlocBuilder<SlashMenuCubit, SlashMenuState>(
      builder: (context, state) {
        if (!state.open) return const SizedBox.shrink();
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onDismiss,
              ),
            ),
            Positioned(
              left: state.anchorRect?.left ?? 200,
              top: (state.anchorRect?.bottom ?? 200) + 4,
              child: Material(
                color: Colors.transparent,
                child: _Panel(state: state, tokens: tokens, onPick: onPick),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.state, required this.tokens, required this.onPick});
  final SlashMenuState state;
  final QuillTokens tokens;
  final void Function(SlashEntry) onPick;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border.all(color: tokens.divider2, width: 0.5),
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        boxShadow: [
          BoxShadow(
            color: tokens.isDark
                ? Colors.black.withValues(alpha: 0.5)
                : Colors.black.withValues(alpha: 0.10),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: tokens.divider, width: 0.5)),
            ),
            child: Row(
              children: [
                Text(
                  '/${state.query}',
                  style: mono(fontSize: 12, color: tokens.text2),
                ),
                const Spacer(),
                Text(
                  state.results.isEmpty ? 'no matches' : '${state.results.length}',
                  style: mono(fontSize: 11, color: tokens.text3),
                ),
              ],
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int i = 0; i < state.results.length; i++)
                    _Row(
                      tokens: tokens,
                      entry: state.results[i],
                      selected: state.selectedIndex == i,
                      onTap: () => onPick(state.results[i]),
                    ),
                  if (state.results.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Text('No matches',
                          style: TextStyle(fontSize: 12.5, color: tokens.text3)),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.tokens,
    required this.entry,
    required this.selected,
    required this.onTap,
  });
  final QuillTokens tokens;
  final SlashEntry entry;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          color: selected ? tokens.hover : Colors.transparent,
          child: Row(
            children: [
              QuillIcon(entry.icon, size: 13, strokeWidth: 1.7, color: tokens.text3),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  entry.label,
                  style: TextStyle(
                    fontSize: 13,
                    color: tokens.text,
                    fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              Text(entry.hint, style: mono(fontSize: 11, color: tokens.text3)),
              if (selected)
                const Padding(padding: EdgeInsets.only(left: 8), child: Kbd('↵')),
            ],
          ),
        ),
      ),
    );
  }
}
