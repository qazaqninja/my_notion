import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/theme/quill_tokens.dart';
import '../../domain/block_selection.dart';
import '../cubit/block_selection_cubit.dart';

/// UI overlay that paints a faint highlight behind each block in the
/// current `BlockSelectionCubit` state. Notion-style multi-block
/// selection visuals.
///
/// The widget is rect-resolver-injection driven: callers supply a
/// `Rect? Function(String nodeId)` that maps node ids to their
/// visual rect in document-layout coordinates. EditorBetaPage will
/// wrap super_editor's `DocumentLayoutState.getComponentByNodeId(id)`
/// + the component's `RenderBox.localToGlobal` chain; tests can stub
/// the function with a fixed map.
///
/// The widget is intentionally a pure presentational layer with no
/// knowledge of super_editor — its only collaborators are the cubit
/// and the theme tokens.
class BlockSelectionOverlay extends StatelessWidget {
  /// Construct the overlay with a node-rect resolver.
  const BlockSelectionOverlay({super.key, required this.rectForNode});

  /// Resolves a node id to its visual rect, or null when the node
  /// isn't laid out (e.g., off-screen, just deleted, layout not yet
  /// built). Null rects are skipped.
  final Rect? Function(String nodeId) rectForNode;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BlockSelectionCubit, BlockSelection>(
      builder: (context, selection) {
        if (selection.isEmpty) {
          return const SizedBox.shrink();
        }
        final tokens = QuillTokens.of(context);
        return IgnorePointer(
          child: Stack(
            children: [
              for (final nodeId in selection.nodeIds)
                if (rectForNode(nodeId) case final rect?)
                  Positioned.fromRect(
                    rect: rect,
                    child: Container(
                      decoration: BoxDecoration(
                        color: tokens.selected.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }
}
