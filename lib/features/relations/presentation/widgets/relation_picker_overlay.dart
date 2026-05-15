import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/theme/quill_tokens.dart';
import '../../../../shared/theme/tokens.dart';
import '../../../../shared/widgets/kbd.dart';
import '../../../../shared/widgets/quill_icon.dart';
import '../../domain/usecases/search_pages.dart';
import '../cubit/relation_picker_cubit.dart';

/// 380-px popover matching `overlays.jsx`'s `RelationPicker`:
/// search header → result list → hover-preview footer.
class RelationPickerOverlay extends StatelessWidget {
  const RelationPickerOverlay({
    super.key,
    required this.onPick,
    required this.onDismiss,
  });

  final void Function(PageSearchResult) onPick;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    return BlocBuilder<RelationPickerCubit, RelationPickerState>(
      builder: (context, state) {
        if (!state.open) return const SizedBox.shrink();
        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Backdrop — tap to dismiss
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
  final RelationPickerState state;
  final QuillTokens tokens;
  final void Function(PageSearchResult) onPick;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 380,
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border.all(color: tokens.divider2, width: 0.5),
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        boxShadow: [
          BoxShadow(
            color: tokens.isDark
                ? Colors.black.withValues(alpha: 0.5)
                : Colors.black.withValues(alpha: 0.10),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header — search query + caption
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: tokens.divider, width: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '↳ link to a page',
                  style: mono(fontSize: 11, color: tokens.text3),
                ),
                const SizedBox(height: 7),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: tokens.inputBg,
                    border: Border.all(color: tokens.divider2, width: 0.5),
                    borderRadius: const BorderRadius.all(Radius.circular(5)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          state.query.isEmpty ? 'type to filter…' : state.query,
                          style: TextStyle(
                            fontSize: 13,
                            color: state.query.isEmpty ? tokens.text3 : tokens.text,
                          ),
                        ),
                      ),
                      const Kbd('↵'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Results list
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: state.results.length,
                itemBuilder: (context, i) {
                  final r = state.results[i];
                  final selected = i == state.selectedIndex;
                  return GestureDetector(
                    onTap: () => onPick(r),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        color: selected ? tokens.hover : Colors.transparent,
                        child: Row(
                          children: [
                            if (r.emojiIcon != null)
                              SizedBox(
                                width: 13,
                                height: 13,
                                child: Center(
                                  child: Text(r.emojiIcon!,
                                      style: const TextStyle(
                                          fontSize: 12, height: 1)),
                                ),
                              )
                            else
                              QuillIcon('file-md',
                                  size: 13,
                                  strokeWidth: 1.7,
                                  color: tokens.text3),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    r.title,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: tokens.text,
                                      fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                  if (r.relativePath.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 1),
                                      child: Text(
                                        r.relativePath,
                                        style: mono(fontSize: 10.5, color: tokens.text3),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (selected) const Kbd('↵'),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          // Hover-preview footer — shows the focused page's first line
          if (state.selectedResult != null)
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: tokens.surface2,
                border: Border(top: BorderSide(color: tokens.divider2, width: 0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    state.selectedResult!.emojiIcon == null
                        ? state.selectedResult!.title
                        : '${state.selectedResult!.emojiIcon!}  ${state.selectedResult!.title}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: tokens.text2,
                    ),
                  ),
                  if (state.selectedResult!.relativePath.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        state.selectedResult!.relativePath,
                        style: mono(fontSize: 10.5, color: tokens.text3),
                      ),
                    ),
                  if (state.selectedResult!.snippet.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        state.selectedResult!.snippet,
                        style: TextStyle(fontSize: 11.5, color: tokens.text2, height: 1.4),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
