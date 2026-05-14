/// Pure helpers behind the drag-to-reorder list-item UX in
/// [MarkdownRenderer]. Lives here (not inside the renderer) so the
/// logic is testable without spinning up the widget tree.
library;

class ListReorder {
  const ListReorder._();

  /// Rebuild a list source slice from [items]. Bullet lists emit
  /// `- <item>`; numbered (ordered) lists emit `${n}. <item>` so numbers
  /// stay sequential 1, 2, 3 after a reorder.
  static String emit(List<String> items, {required bool isOrdered}) {
    if (isOrdered) {
      return [for (var i = 0; i < items.length; i++) '${i + 1}. ${items[i]}']
          .join('\n');
    }
    return [for (final item in items) '- $item'].join('\n');
  }

  /// Move `items[sourceIndex]` to land *before* the slot that was
  /// `targetIndex` (i.e. the dragged item is dropped on the row whose
  /// pre-drag index is `targetIndex`). Returns the rewritten source
  /// slice. No-op when source == target or out-of-bounds.
  static String reorderSource(
    List<String> items,
    int sourceIndex,
    int targetIndex, {
    required bool isOrdered,
  }) {
    if (sourceIndex == targetIndex ||
        sourceIndex < 0 ||
        sourceIndex >= items.length) {
      return emit(items, isOrdered: isOrdered);
    }
    final next = List<String>.from(items);
    final moved = next.removeAt(sourceIndex);
    final insertAt =
        sourceIndex < targetIndex ? targetIndex - 1 : targetIndex;
    next.insert(insertAt.clamp(0, next.length), moved);
    return emit(next, isOrdered: isOrdered);
  }
}
