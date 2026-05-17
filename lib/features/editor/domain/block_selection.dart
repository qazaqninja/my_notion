import 'package:equatable/equatable.dart';

/// Immutable value object representing a Notion-style multi-block
/// selection: a (possibly non-contiguous) set of selected block node
/// ids alongside the editor's text-caret `DocumentSelection`.
///
/// Phase D D25 slice 1 of the 1m-loop plan. Subsequent slices add the
/// owning Cubit, the UI overlay, gesture wiring (⌘+Click /
/// Shift+Click), and integration with the D24-family keyboard ops so
/// they act on the whole set when it's non-empty.
///
/// Pure-Dart, no super_editor or Flutter imports — the value object
/// is intentionally framework-agnostic so it can be unit-tested in
/// isolation. The cubit (slice 2) bridges it to super_editor's state.
class BlockSelection extends Equatable {
  /// Construct a selection wrapping the given [nodeIds]. The
  /// [BlockSelection.empty] factory is the canonical entry point;
  /// passing a non-empty initial set is supported for tests + future
  /// rehydration flows.
  const BlockSelection(this.nodeIds);

  /// The canonical empty selection. Stable identity for the
  /// `BlocBuilder` initial-state comparison in slice 2.
  factory BlockSelection.empty() => const BlockSelection({});

  /// The selected node ids. Always treated as immutable; mutating
  /// operations return a fresh [BlockSelection] instance.
  final Set<String> nodeIds;

  /// True when no blocks are selected.
  bool get isEmpty => nodeIds.isEmpty;

  /// True when at least one block is selected.
  bool get isNotEmpty => nodeIds.isNotEmpty;

  /// Number of selected blocks.
  int get size => nodeIds.length;

  /// Whether [nodeId] is part of the selection.
  bool isSelected(String nodeId) => nodeIds.contains(nodeId);

  /// Returns a new selection with [nodeId] added (idempotent).
  BlockSelection add(String nodeId) {
    if (nodeIds.contains(nodeId)) return this;
    return BlockSelection({...nodeIds, nodeId});
  }

  /// Returns a new selection with [nodeId] removed (no-op when
  /// absent).
  BlockSelection remove(String nodeId) {
    if (!nodeIds.contains(nodeId)) return this;
    return BlockSelection({...nodeIds}..remove(nodeId));
  }

  /// Returns a new selection with [nodeId] removed if present, added
  /// otherwise. Mirrors `Set.toggle` semantics.
  BlockSelection toggle(String nodeId) =>
      isSelected(nodeId) ? remove(nodeId) : add(nodeId);

  /// Returns an empty selection.
  BlockSelection clear() => BlockSelection.empty();

  /// Returns a new selection containing exactly [nodeIds]. The input
  /// is copied; subsequent caller mutation does not leak.
  BlockSelection replaceWith(Set<String> nodeIds) =>
      BlockSelection({...nodeIds});

  @override
  List<Object?> get props => [nodeIds];
}
