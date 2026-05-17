import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/editor/domain/block_duplicate.dart';
import 'package:super_editor/super_editor.dart';

void main() {
  group('resolveBlockDuplicate', () {
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
      test('middle node returns (sourceNodeId, currentIndex + 1)', () {
        final result = resolveBlockDuplicate(
          document: document,
          selection: collapsedAtNode('b', 2),
        );
        expect(result, isNotNull);
        expect(result!.sourceNodeId, 'b');
        expect(result.newIndex, 2);
      });

      test('first node returns (a, 1)', () {
        final result = resolveBlockDuplicate(
          document: document,
          selection: collapsedAtNode('a', 0),
        );
        expect(result, isNotNull);
        expect(result!.sourceNodeId, 'a');
        expect(result.newIndex, 1);
      });

      test('last node returns (c, 3) — append-at-end is valid', () {
        final result = resolveBlockDuplicate(
          document: document,
          selection: collapsedAtNode('c', 0),
        );
        expect(result, isNotNull);
        expect(result!.sourceNodeId, 'c');
        expect(result.newIndex, 3);
      });
    });

    group('no-op (returns null)', () {
      test('null selection', () {
        expect(
          resolveBlockDuplicate(document: document, selection: null),
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
          resolveBlockDuplicate(document: document, selection: selection),
          isNull,
        );
      });

      test('selection on unknown node id', () {
        expect(
          resolveBlockDuplicate(
            document: document,
            selection: collapsedAtNode('ghost', 0),
          ),
          isNull,
        );
      });
    });

    group('edge cases', () {
      test('single-node document — duplicate returns (x, 1)', () {
        final solo = MutableDocument(
          nodes: [ParagraphNode(id: 'x', text: AttributedText('only'))],
        );
        final result = resolveBlockDuplicate(
          document: solo,
          selection: collapsedAtNode('x', 0),
        );
        expect(result, isNotNull);
        expect(result!.sourceNodeId, 'x');
        expect(result.newIndex, 1);
      });

      test('newIndex equals document.nodeCount when on last node', () {
        final result = resolveBlockDuplicate(
          document: document,
          selection: collapsedAtNode('c', 0),
        );
        expect(result!.newIndex, document.nodeCount);
      });
    });
  });
}
