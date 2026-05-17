import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:super_editor/super_editor.dart';

import '../../domain/block_selection.dart';

/// Owns the Notion-style multi-block selection (independent of the
/// editor's text-caret `DocumentSelection`). State is the immutable
/// [BlockSelection] from M1593.
///
/// Slice 2 of D25 (Phase D D25 slices: value object → cubit → UI
/// overlay → gesture wiring → ops integration).
///
/// All mutations debounce through Cubit's `emit` so listeners receive
/// a fresh [BlockSelection] only when content actually changes (the
/// value object's Equatable-based equality short-circuits no-op
/// emissions automatically thanks to `Equatable`'s `==`).
class BlockSelectionCubit extends Cubit<BlockSelection> {
  /// Start with no blocks selected.
  BlockSelectionCubit() : super(BlockSelection.empty());

  /// Replace the selection with exactly [nodeId]. Used by plain
  /// "click block edge" — closes any existing multi-selection.
  void selectBlock(String nodeId) {
    emit(BlockSelection({nodeId}));
  }

  /// Toggle [nodeId] in the current selection. Used by ⌘+Click (or
  /// Ctrl+Click on Linux/Windows) to add or remove a single block
  /// from a non-contiguous set.
  void toggleBlock(String nodeId) {
    emit(state.toggle(nodeId));
  }

  /// Replace the selection with the inclusive range of nodes between
  /// [anchor] and [extent] in document order. Direction-agnostic
  /// (Shift+Click works in either direction). When [anchor] == [extent]
  /// the selection collapses to that single node. No-op when either
  /// id is missing from [document].
  void extendSelection({
    required String anchor,
    required String extent,
    required Document document,
  }) {
    final anchorIdx = document.getNodeIndexById(anchor);
    final extentIdx = document.getNodeIndexById(extent);
    if (anchorIdx < 0 || extentIdx < 0) return;
    final start = anchorIdx <= extentIdx ? anchorIdx : extentIdx;
    final end = anchorIdx <= extentIdx ? extentIdx : anchorIdx;
    final nodeIds = <String>{};
    for (var i = start; i <= end; i++) {
      final node = document.getNodeAt(i);
      if (node != null) nodeIds.add(node.id);
    }
    emit(BlockSelection(nodeIds));
  }

  /// Clear the multi-selection. Called when the user clicks empty
  /// space or starts typing in a block.
  void clearSelection() {
    if (state.isEmpty) return;
    emit(BlockSelection.empty());
  }
}
