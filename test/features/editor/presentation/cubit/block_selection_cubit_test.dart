import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/editor/domain/block_selection.dart';
import 'package:my_notion/features/editor/presentation/cubit/block_selection_cubit.dart';
import 'package:super_editor/super_editor.dart';

void main() {
  group('BlockSelectionCubit', () {
    MutableDocument threeNodeDoc() => MutableDocument(
          nodes: [
            ParagraphNode(id: 'a', text: AttributedText('A')),
            ParagraphNode(id: 'b', text: AttributedText('B')),
            ParagraphNode(id: 'c', text: AttributedText('C')),
          ],
        );

    group('initial state', () {
      test('starts empty', () {
        final cubit = BlockSelectionCubit();
        expect(cubit.state, BlockSelection.empty());
        cubit.close();
      });
    });

    group('selectBlock', () {
      blocTest<BlockSelectionCubit, BlockSelection>(
        'from empty emits {nodeId}',
        build: BlockSelectionCubit.new,
        act: (c) => c.selectBlock('a'),
        expect: () => [
          const BlockSelection({'a'}),
        ],
      );

      blocTest<BlockSelectionCubit, BlockSelection>(
        'replaces existing selection',
        build: BlockSelectionCubit.new,
        seed: () => const BlockSelection({'a', 'b'}),
        act: (c) => c.selectBlock('c'),
        expect: () => [
          const BlockSelection({'c'}),
        ],
      );
    });

    group('toggleBlock', () {
      blocTest<BlockSelectionCubit, BlockSelection>(
        'adds when missing',
        build: BlockSelectionCubit.new,
        act: (c) => c.toggleBlock('a'),
        expect: () => [
          const BlockSelection({'a'}),
        ],
      );

      blocTest<BlockSelectionCubit, BlockSelection>(
        'removes when present',
        build: BlockSelectionCubit.new,
        seed: () => const BlockSelection({'a', 'b'}),
        act: (c) => c.toggleBlock('a'),
        expect: () => [
          const BlockSelection({'b'}),
        ],
      );
    });

    group('extendSelection', () {
      blocTest<BlockSelectionCubit, BlockSelection>(
        'forward range (a → c) selects all three',
        build: BlockSelectionCubit.new,
        act: (c) => c.extendSelection(
          anchor: 'a',
          extent: 'c',
          document: threeNodeDoc(),
        ),
        expect: () => [
          const BlockSelection({'a', 'b', 'c'}),
        ],
      );

      blocTest<BlockSelectionCubit, BlockSelection>(
        'backward range (c → a) selects all three',
        build: BlockSelectionCubit.new,
        act: (c) => c.extendSelection(
          anchor: 'c',
          extent: 'a',
          document: threeNodeDoc(),
        ),
        expect: () => [
          const BlockSelection({'a', 'b', 'c'}),
        ],
      );

      blocTest<BlockSelectionCubit, BlockSelection>(
        'anchor == extent selects just that node',
        build: BlockSelectionCubit.new,
        act: (c) => c.extendSelection(
          anchor: 'b',
          extent: 'b',
          document: threeNodeDoc(),
        ),
        expect: () => [
          const BlockSelection({'b'}),
        ],
      );

      blocTest<BlockSelectionCubit, BlockSelection>(
        'unknown anchor is a no-op',
        build: BlockSelectionCubit.new,
        act: (c) => c.extendSelection(
          anchor: 'ghost',
          extent: 'a',
          document: threeNodeDoc(),
        ),
        expect: () => <BlockSelection>[],
      );

      blocTest<BlockSelectionCubit, BlockSelection>(
        'unknown extent is a no-op',
        build: BlockSelectionCubit.new,
        act: (c) => c.extendSelection(
          anchor: 'a',
          extent: 'ghost',
          document: threeNodeDoc(),
        ),
        expect: () => <BlockSelection>[],
      );
    });

    group('clearSelection', () {
      blocTest<BlockSelectionCubit, BlockSelection>(
        'from non-empty emits empty',
        build: BlockSelectionCubit.new,
        seed: () => const BlockSelection({'a', 'b'}),
        act: (c) => c.clearSelection(),
        expect: () => [BlockSelection.empty()],
      );

      blocTest<BlockSelectionCubit, BlockSelection>(
        'from empty is a no-op (no emission)',
        build: BlockSelectionCubit.new,
        act: (c) => c.clearSelection(),
        expect: () => <BlockSelection>[],
      );
    });
  });
}
