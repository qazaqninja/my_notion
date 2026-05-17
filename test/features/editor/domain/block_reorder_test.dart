import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/editor/domain/block_reorder.dart';
import 'package:super_editor/super_editor.dart';

void main() {
  group('resolveBlockReorder', () {
    late MutableDocument document;

    setUp(() {
      document = MutableDocument(
        nodes: [
          ParagraphNode(id: 'a', text: AttributedText('first')),
          ParagraphNode(id: 'b', text: AttributedText('second')),
          ParagraphNode(id: 'c', text: AttributedText('third')),
        ],
      );
    });

    DocumentSelection collapsedAtNode(String nodeId, int offset) =>
        DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: nodeId,
            nodePosition: TextNodePosition(offset: offset),
          ),
        );

    group('happy path', () {
      test('up from middle node returns previous index', () {
        final result = resolveBlockReorder(
          document: document,
          selection: collapsedAtNode('b', 2),
          direction: BlockMoveDirection.up,
        );
        expect(result, isNotNull);
        expect(result!.nodeId, 'b');
        expect(result.newIndex, 0);
      });

      test('down from middle node returns next index', () {
        final result = resolveBlockReorder(
          document: document,
          selection: collapsedAtNode('b', 2),
          direction: BlockMoveDirection.down,
        );
        expect(result, isNotNull);
        expect(result!.nodeId, 'b');
        expect(result.newIndex, 2);
      });

      test('up from last node returns previous index', () {
        final result = resolveBlockReorder(
          document: document,
          selection: collapsedAtNode('c', 0),
          direction: BlockMoveDirection.up,
        );
        expect(result, isNotNull);
        expect(result!.newIndex, 1);
      });

      test('down from first node returns next index', () {
        final result = resolveBlockReorder(
          document: document,
          selection: collapsedAtNode('a', 0),
          direction: BlockMoveDirection.down,
        );
        expect(result, isNotNull);
        expect(result!.newIndex, 1);
      });
    });

    group('no-op (returns null)', () {
      test('null selection', () {
        expect(
          resolveBlockReorder(
            document: document,
            selection: null,
            direction: BlockMoveDirection.up,
          ),
          isNull,
        );
      });

      test('non-collapsed selection', () {
        final selection = DocumentSelection(
          base: const DocumentPosition(
            nodeId: 'a',
            nodePosition: TextNodePosition(offset: 0),
          ),
          extent: const DocumentPosition(
            nodeId: 'b',
            nodePosition: TextNodePosition(offset: 2),
          ),
        );
        expect(
          resolveBlockReorder(
            document: document,
            selection: selection,
            direction: BlockMoveDirection.up,
          ),
          isNull,
        );
      });

      test('up from first node — already at top', () {
        expect(
          resolveBlockReorder(
            document: document,
            selection: collapsedAtNode('a', 0),
            direction: BlockMoveDirection.up,
          ),
          isNull,
        );
      });

      test('down from last node — already at bottom', () {
        expect(
          resolveBlockReorder(
            document: document,
            selection: collapsedAtNode('c', 0),
            direction: BlockMoveDirection.down,
          ),
          isNull,
        );
      });

      test('selection on unknown node id', () {
        expect(
          resolveBlockReorder(
            document: document,
            selection: collapsedAtNode('ghost', 0),
            direction: BlockMoveDirection.up,
          ),
          isNull,
        );
      });
    });

    group('edge cases', () {
      test('single-node document — up is null', () {
        final solo = MutableDocument(
          nodes: [ParagraphNode(id: 'x', text: AttributedText('only'))],
        );
        expect(
          resolveBlockReorder(
            document: solo,
            selection: collapsedAtNode('x', 0),
            direction: BlockMoveDirection.up,
          ),
          isNull,
        );
      });

      test('single-node document — down is null', () {
        final solo = MutableDocument(
          nodes: [ParagraphNode(id: 'x', text: AttributedText('only'))],
        );
        expect(
          resolveBlockReorder(
            document: solo,
            selection: collapsedAtNode('x', 0),
            direction: BlockMoveDirection.down,
          ),
          isNull,
        );
      });
    });
  });
}
