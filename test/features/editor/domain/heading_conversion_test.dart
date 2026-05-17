import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/editor/domain/heading_conversion.dart';
import 'package:super_editor/super_editor.dart';

void main() {
  group('resolveHeadingConversion', () {
    late MutableDocument document;

    setUp(() {
      document = MutableDocument(
        nodes: [
          ParagraphNode(id: 'a', text: AttributedText('first')),
          ListItemNode(
            id: 'b',
            itemType: ListItemType.unordered,
            text: AttributedText('item'),
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
      test('paragraph to h1 returns header1Attribution', () {
        final result = resolveHeadingConversion(
          document: document,
          selection: collapsedAtNode('a', 2),
          target: HeadingLevel.h1,
        );
        expect(result, isNotNull);
        expect(result!.nodeId, 'a');
        expect(result.blockType, header1Attribution);
      });

      test('paragraph to h2 returns header2Attribution', () {
        final result = resolveHeadingConversion(
          document: document,
          selection: collapsedAtNode('a', 0),
          target: HeadingLevel.h2,
        );
        expect(result!.blockType, header2Attribution);
      });

      test('paragraph to h3 returns header3Attribution', () {
        final result = resolveHeadingConversion(
          document: document,
          selection: collapsedAtNode('a', 0),
          target: HeadingLevel.h3,
        );
        expect(result!.blockType, header3Attribution);
      });

      test('paragraph to paragraph returns null blockType (reset)', () {
        final result = resolveHeadingConversion(
          document: document,
          selection: collapsedAtNode('a', 0),
          target: HeadingLevel.paragraph,
        );
        expect(result, isNotNull);
        expect(result!.blockType, isNull);
      });
    });

    group('no-op (returns null)', () {
      test('null selection', () {
        expect(
          resolveHeadingConversion(
            document: document,
            selection: null,
            target: HeadingLevel.h1,
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
            nodePosition: TextNodePosition(offset: 3),
          ),
        );
        expect(
          resolveHeadingConversion(
            document: document,
            selection: selection,
            target: HeadingLevel.h1,
          ),
          isNull,
        );
      });

      test('selection on unknown node id', () {
        expect(
          resolveHeadingConversion(
            document: document,
            selection: collapsedAtNode('ghost', 0),
            target: HeadingLevel.h1,
          ),
          isNull,
        );
      });

      test('selection on ListItemNode — not a ParagraphNode, no-op', () {
        expect(
          resolveHeadingConversion(
            document: document,
            selection: collapsedAtNode('b', 0),
            target: HeadingLevel.h1,
          ),
          isNull,
        );
      });

      test('selection on HorizontalRuleNode — not a ParagraphNode, no-op',
          () {
        final selection = DocumentSelection.collapsed(
          position: const DocumentPosition(
            nodeId: 'hr',
            nodePosition: UpstreamDownstreamNodePosition.downstream(),
          ),
        );
        expect(
          resolveHeadingConversion(
            document: document,
            selection: selection,
            target: HeadingLevel.h1,
          ),
          isNull,
        );
      });
    });

    group('edge cases', () {
      test('h1 paragraph converting back to paragraph returns null blockType',
          () {
        final headerDoc = MutableDocument(
          nodes: [
            ParagraphNode(
              id: 'h',
              text: AttributedText('Heading'),
              metadata: const {'blockType': header1Attribution},
            ),
          ],
        );
        final result = resolveHeadingConversion(
          document: headerDoc,
          selection: collapsedAtNode('h', 0),
          target: HeadingLevel.paragraph,
        );
        expect(result, isNotNull);
        expect(result!.blockType, isNull);
      });

      test('all four levels round-trip via the same paragraph node', () {
        for (final level in HeadingLevel.values) {
          final result = resolveHeadingConversion(
            document: document,
            selection: collapsedAtNode('a', 0),
            target: level,
          );
          expect(result, isNotNull, reason: 'level=$level');
          expect(result!.nodeId, 'a');
        }
      });
    });
  });
}
