import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/editor/domain/block_conversion.dart';
import 'package:my_notion/features/editor/domain/block_selection.dart';
import 'package:my_notion/features/editor/domain/heading_conversion.dart';
import 'package:my_notion/features/editor/domain/multi_block_ops.dart';
import 'package:super_editor/super_editor.dart';

void main() {
  MutableDocument fourNodeDoc() => MutableDocument(
        nodes: [
          ParagraphNode(id: 'a', text: AttributedText('A')),
          ParagraphNode(id: 'b', text: AttributedText('B')),
          ListItemNode(
            id: 'c',
            itemType: ListItemType.unordered,
            text: AttributedText('C'),
          ),
          HorizontalRuleNode(id: 'hr'),
        ],
      );

  group('deleteSelectedBlocks', () {
    test('empty selection → empty list', () {
      expect(
        deleteSelectedBlocks(
          selection: BlockSelection.empty(),
          document: fourNodeDoc(),
        ),
        isEmpty,
      );
    });

    test('one id → one DeleteNodeRequest', () {
      final reqs = deleteSelectedBlocks(
        selection: const BlockSelection({'b'}),
        document: fourNodeDoc(),
      );
      expect(reqs, hasLength(1));
      expect(reqs.first, isA<DeleteNodeRequest>());
      expect((reqs.first as DeleteNodeRequest).nodeId, 'b');
    });

    test('multiple ids → reverse document order (last index first)', () {
      final reqs = deleteSelectedBlocks(
        selection: const BlockSelection({'a', 'c', 'b'}),
        document: fourNodeDoc(),
      );
      expect(reqs, hasLength(3));
      // Document order is a(0), b(1), c(2) → reverse is c, b, a.
      expect((reqs[0] as DeleteNodeRequest).nodeId, 'c');
      expect((reqs[1] as DeleteNodeRequest).nodeId, 'b');
      expect((reqs[2] as DeleteNodeRequest).nodeId, 'a');
    });
  });

  group('applyHeadingToSelection', () {
    test('empty selection → empty list', () {
      expect(
        applyHeadingToSelection(
          selection: BlockSelection.empty(),
          document: fourNodeDoc(),
          target: HeadingLevel.h1,
        ),
        isEmpty,
      );
    });

    test('paragraph + ListItem mix → only paragraphs get requests', () {
      final reqs = applyHeadingToSelection(
        selection: const BlockSelection({'a', 'b', 'c'}),
        document: fourNodeDoc(),
        target: HeadingLevel.h2,
      );
      // c is a ListItemNode — skipped. Two requests for a + b.
      expect(reqs, hasLength(2));
      for (final r in reqs) {
        expect(r, isA<ChangeParagraphBlockTypeRequest>());
        expect((r as ChangeParagraphBlockTypeRequest).blockType,
            header2Attribution);
      }
    });

    test('paragraph target maps to null blockType (reset)', () {
      final reqs = applyHeadingToSelection(
        selection: const BlockSelection({'a'}),
        document: fourNodeDoc(),
        target: HeadingLevel.paragraph,
      );
      expect(reqs, hasLength(1));
      expect((reqs.first as ChangeParagraphBlockTypeRequest).blockType, isNull);
    });

    test('HorizontalRuleNode silently skipped', () {
      expect(
        applyHeadingToSelection(
          selection: const BlockSelection({'hr'}),
          document: fourNodeDoc(),
          target: HeadingLevel.h1,
        ),
        isEmpty,
      );
    });
  });

  group('applyBlockConversionToSelection', () {
    test('empty selection → empty list', () {
      expect(
        applyBlockConversionToSelection(
          selection: BlockSelection.empty(),
          document: fourNodeDoc(),
          target: BlockConversion.unorderedList,
        ),
        isEmpty,
      );
    });

    test('paragraph → list emits one ConvertParagraphToListItem per id', () {
      final reqs = applyBlockConversionToSelection(
        selection: const BlockSelection({'a', 'b'}),
        document: fourNodeDoc(),
        target: BlockConversion.orderedList,
      );
      expect(reqs, hasLength(2));
      for (final r in reqs) {
        expect(r, isA<ConvertParagraphToListItemRequest>());
        expect((r as ConvertParagraphToListItemRequest).type,
            ListItemType.ordered);
      }
    });

    test('ListItem-to-task chains list→paragraph→task (2 requests per id)',
        () {
      final reqs = applyBlockConversionToSelection(
        selection: const BlockSelection({'c'}),
        document: fourNodeDoc(),
        target: BlockConversion.task,
      );
      expect(reqs, hasLength(2));
      expect(reqs[0], isA<ConvertListItemToParagraphRequest>());
      expect(reqs[1], isA<ConvertParagraphToTaskRequest>());
    });

    test('HorizontalRuleNode silently skipped (non-TextNode)', () {
      expect(
        applyBlockConversionToSelection(
          selection: const BlockSelection({'hr'}),
          document: fourNodeDoc(),
          target: BlockConversion.task,
        ),
        isEmpty,
      );
    });
  });
}
