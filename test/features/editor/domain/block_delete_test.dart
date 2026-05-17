import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/editor/domain/block_delete.dart';
import 'package:super_editor/super_editor.dart';

void main() {
  group('resolveBlockDelete', () {
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
      test('middle node returns nodeId b', () {
        final result = resolveBlockDelete(
          document: document,
          selection: collapsedAtNode('b', 2),
        );
        expect(result, isNotNull);
        expect(result!.nodeId, 'b');
      });

      test('first node returns nodeId a', () {
        final result = resolveBlockDelete(
          document: document,
          selection: collapsedAtNode('a', 0),
        );
        expect(result, isNotNull);
        expect(result!.nodeId, 'a');
      });

      test('last node returns nodeId c', () {
        final result = resolveBlockDelete(
          document: document,
          selection: collapsedAtNode('c', 0),
        );
        expect(result, isNotNull);
        expect(result!.nodeId, 'c');
      });
    });

    group('no-op (returns null)', () {
      test('null selection', () {
        expect(
          resolveBlockDelete(document: document, selection: null),
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
          resolveBlockDelete(document: document, selection: selection),
          isNull,
        );
      });

      test('selection on unknown node id', () {
        expect(
          resolveBlockDelete(
            document: document,
            selection: collapsedAtNode('ghost', 0),
          ),
          isNull,
        );
      });

      test('single-node document — last-node guard blocks delete', () {
        final solo = MutableDocument(
          nodes: [ParagraphNode(id: 'x', text: AttributedText('only'))],
        );
        expect(
          resolveBlockDelete(
            document: solo,
            selection: collapsedAtNode('x', 0),
          ),
          isNull,
        );
      });
    });

    group('edge cases', () {
      test('two-node document — both nodes deletable (nodeCount > 1)', () {
        final pair = MutableDocument(
          nodes: [
            ParagraphNode(id: 'p1', text: AttributedText('first')),
            ParagraphNode(id: 'p2', text: AttributedText('second')),
          ],
        );
        expect(
          resolveBlockDelete(
            document: pair,
            selection: collapsedAtNode('p1', 0),
          )!
              .nodeId,
          'p1',
        );
        expect(
          resolveBlockDelete(
            document: pair,
            selection: collapsedAtNode('p2', 0),
          )!
              .nodeId,
          'p2',
        );
      });
    });
  });
}
