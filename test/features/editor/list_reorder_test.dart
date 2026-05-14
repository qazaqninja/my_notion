import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/editor/data/list_reorder.dart';

void main() {
  group('ListReorder.emit', () {
    test('ul emits "- " prefix', () {
      expect(
        ListReorder.emit(['a', 'b'], isOrdered: false),
        '- a\n- b',
      );
    });

    test('ol renumbers sequentially', () {
      expect(
        ListReorder.emit(['a', 'b', 'c'], isOrdered: true),
        '1. a\n2. b\n3. c',
      );
    });

    test('empty list → empty string', () {
      expect(ListReorder.emit(const [], isOrdered: false), '');
      expect(ListReorder.emit(const [], isOrdered: true), '');
    });
  });

  group('ListReorder.reorderSource', () {
    test('move last item to first (ul)', () {
      expect(
        ListReorder.reorderSource(['a', 'b', 'c'], 2, 0, isOrdered: false),
        '- c\n- a\n- b',
      );
    });

    test('move first to last (ul)', () {
      // sourceIndex=0, targetIndex=3 → drop AFTER the last existing index
      expect(
        ListReorder.reorderSource(['a', 'b', 'c'], 0, 3, isOrdered: false),
        '- b\n- c\n- a',
      );
    });

    test('move middle right by one (ol renumbers)', () {
      expect(
        ListReorder.reorderSource(['a', 'b', 'c', 'd'], 1, 3,
            isOrdered: true),
        '1. a\n2. c\n3. b\n4. d',
      );
    });

    test('source == target → no-op (still re-emits source)', () {
      expect(
        ListReorder.reorderSource(['a', 'b'], 0, 0, isOrdered: false),
        '- a\n- b',
      );
    });

    test('out-of-bounds source → no-op', () {
      expect(
        ListReorder.reorderSource(['a', 'b'], 99, 0, isOrdered: false),
        '- a\n- b',
      );
    });

    test('move to the same logical slot is idempotent', () {
      // moving index 1 to target 2 (drop after index 1 — i.e. between
      // items 1 and 2) is a no-op since item 1 already sits there.
      expect(
        ListReorder.reorderSource(['a', 'b', 'c'], 1, 2, isOrdered: false),
        '- a\n- b\n- c',
      );
    });
  });
}
