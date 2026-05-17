import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/editor/domain/block_conversion.dart';
import 'package:super_editor/super_editor.dart';

void main() {
  group('resolveBlockConversion', () {
    late MutableDocument document;

    setUp(() {
      document = MutableDocument(
        nodes: [
          ParagraphNode(id: 'a', text: AttributedText('para')),
          ListItemNode(
            id: 'b',
            itemType: ListItemType.unordered,
            text: AttributedText('item'),
          ),
          TaskNode(
            id: 'c',
            text: AttributedText('task'),
            isComplete: false,
          ),
          HorizontalRuleNode(id: 'hr'),
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
      test('paragraph to unordered list returns (a, unorderedList)', () {
        final result = resolveBlockConversion(
          document: document,
          selection: collapsedAtNode('a', 0),
          target: BlockConversion.unorderedList,
        );
        expect(result, isNotNull);
        expect(result!.nodeId, 'a');
        expect(result.target, BlockConversion.unorderedList);
      });

      test('paragraph to ordered list returns (a, orderedList)', () {
        final result = resolveBlockConversion(
          document: document,
          selection: collapsedAtNode('a', 0),
          target: BlockConversion.orderedList,
        );
        expect(result!.target, BlockConversion.orderedList);
      });

      test('paragraph to task returns (a, task)', () {
        final result = resolveBlockConversion(
          document: document,
          selection: collapsedAtNode('a', 0),
          target: BlockConversion.task,
        );
        expect(result!.target, BlockConversion.task);
      });

      test('list item to task (switch text-node subtype)', () {
        final result = resolveBlockConversion(
          document: document,
          selection: collapsedAtNode('b', 0),
          target: BlockConversion.task,
        );
        expect(result, isNotNull);
        expect(result!.nodeId, 'b');
        expect(result.target, BlockConversion.task);
      });

      test('task to ordered list (switch text-node subtype)', () {
        final result = resolveBlockConversion(
          document: document,
          selection: collapsedAtNode('c', 0),
          target: BlockConversion.orderedList,
        );
        expect(result, isNotNull);
        expect(result!.nodeId, 'c');
        expect(result.target, BlockConversion.orderedList);
      });
    });

    group('no-op (returns null)', () {
      test('null selection', () {
        expect(
          resolveBlockConversion(
            document: document,
            selection: null,
            target: BlockConversion.unorderedList,
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
            nodeId: 'a',
            nodePosition: TextNodePosition(offset: 2),
          ),
        );
        expect(
          resolveBlockConversion(
            document: document,
            selection: selection,
            target: BlockConversion.task,
          ),
          isNull,
        );
      });

      test('selection on unknown node id', () {
        expect(
          resolveBlockConversion(
            document: document,
            selection: collapsedAtNode('ghost', 0),
            target: BlockConversion.task,
          ),
          isNull,
        );
      });

      test('selection on HorizontalRuleNode — not convertible', () {
        final selection = DocumentSelection.collapsed(
          position: const DocumentPosition(
            nodeId: 'hr',
            nodePosition: UpstreamDownstreamNodePosition.downstream(),
          ),
        );
        expect(
          resolveBlockConversion(
            document: document,
            selection: selection,
            target: BlockConversion.task,
          ),
          isNull,
        );
      });
    });

    group('edge cases', () {
      test('all three targets resolvable from the same paragraph', () {
        for (final target in BlockConversion.values) {
          final result = resolveBlockConversion(
            document: document,
            selection: collapsedAtNode('a', 0),
            target: target,
          );
          expect(result, isNotNull, reason: 'target=$target');
          expect(result!.nodeId, 'a');
          expect(result.target, target);
        }
      });
    });
  });
}
