import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/theme/quill_tokens.dart';
import '../../../../shared/theme/tokens.dart';
import '../../../../shared/widgets/kbd.dart';
import '../../../../shared/widgets/quill_icon.dart';
import '../../../../shared/widgets/responsive_layout.dart';
import '../../domain/slash_entries.dart';
import '../cubit/slash_menu_cubit.dart';

// ---------------------------------------------------------------------------
// M1680 — touch-tuned slash menu rows. Pure-Dart helpers picked between
// dense (desktop) and tall-touch (mobile) sizing. Exported for unit test
// coverage; production reads them from [_Row.build] via [isMobileWidth].
// ---------------------------------------------------------------------------

/// Row container padding. Mobile bumps to 12 vertical + 16 horizontal so
/// the resulting row height clears the 44pt Material touch-target floor
/// (12 + ~20 content + 12 = ~44). Desktop stays at the current dense
/// 7 / 12.
EdgeInsets slashRowPaddingFor({required bool isMobile}) => isMobile
    ? const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
    : const EdgeInsets.symmetric(horizontal: 12, vertical: 7);

/// Leading-icon size. Mobile bumps to 18 (matches typical tab-bar icon
/// affordance); desktop stays at 13.
double slashRowIconSizeFor({required bool isMobile}) => isMobile ? 18 : 13;

/// Label text size. Mobile bumps to 15 (touch-comfortable body); desktop
/// stays at the dense 13.
double slashRowLabelFontSizeFor({required bool isMobile}) =>
    isMobile ? 15 : 13;

/// Whether to render the trailing `Kbd('↵')` hint chip on the selected
/// row. Hidden on mobile — touch users can't press Enter on a physical
/// keyboard, and the chip eats horizontal space.
bool slashRowShowsKeyboardHint({required bool isMobile}) => !isMobile;

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
    // Cap the panel width to the narrower of 320px or the viewport
    // width minus a small breathing margin — keeps the menu on-screen
    // when the editor is narrow (mobile, split-view, narrow window).
    final screen = MediaQuery.of(context).size;
    final w = screen.width < 360 ? (screen.width - 32).clamp(220.0, 320.0) : 320.0;
    // Trim list height when the available space below the anchor is
    // tight — keeps the menu fully on-screen on short windows.
    final anchorBottom = state.anchorRect?.bottom ?? 200;
    final availBelow = (screen.height - anchorBottom - 16).clamp(120.0, 320.0);
    return Container(
      width: w,
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border.all(color: tokens.divider2, width: 0.5),
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context)
                .colorScheme
                .shadow
                .withValues(alpha: tokens.isDark ? 0.5 : 0.10),
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
                Tooltip(
                  message: state.results.isEmpty
                      ? 'No blocks match this query'
                      : state.results.length == 1
                          ? '1 block matches'
                          : '${state.results.length} blocks match',
                  waitDuration: const Duration(milliseconds: 500),
                  child: Text(
                    state.results.isEmpty
                        ? 'no matches'
                        : '${state.results.length}',
                    style: mono(fontSize: 11, color: tokens.text3),
                  ),
                ),
              ],
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: availBelow),
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
                      onHover: () => context
                          .read<SlashMenuCubit>()
                          .setSelection(i),
                    ),
                  if (state.results.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('No blocks match',
                              style: TextStyle(
                                  fontSize: 12.5,
                                  color: tokens.text3,
                                  fontWeight: FontWeight.w500)),
                          const SizedBox(height: 2),
                          Text(
                            'Try /h1 /code /quote /button /db: …',
                            style: mono(fontSize: 10.5, color: tokens.text3),
                          ),
                        ],
                      ),
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
    this.onHover,
  });
  final QuillTokens tokens;
  final SlashEntry entry;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onHover;

  @override
  Widget build(BuildContext context) {
    // M1680: switch between desktop-dense and mobile-touch sizing on a
    // per-row basis. The breakpoint is the same `isMobileWidth` helper
    // the mobile shell + responsive command palette already use.
    final isMobile = isMobileWidth(context);
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: onHover == null ? null : (_) => onHover!(),
        child: Container(
          padding: slashRowPaddingFor(isMobile: isMobile),
          color: selected ? tokens.hover : Colors.transparent,
          child: Row(
            children: [
              QuillIcon(
                entry.icon,
                size: slashRowIconSizeFor(isMobile: isMobile),
                strokeWidth: 1.7,
                color: tokens.text3,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  entry.label,
                  style: TextStyle(
                    fontSize: slashRowLabelFontSizeFor(isMobile: isMobile),
                    color: tokens.text,
                    fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              Text(entry.hint, style: mono(fontSize: 11, color: tokens.text3)),
              if (selected && slashRowShowsKeyboardHint(isMobile: isMobile))
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Kbd('↵'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
