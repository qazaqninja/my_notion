import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/editor/presentation/controllers/super_editor_caret.dart';
import 'package:super_editor/super_editor.dart';

void main() {
  group('plainTextAndCaret', () {
    test('returns (empty, 0) when the document has no nodes', () {
      final doc = MutableDocument();
      final composer = MutableDocumentComposer();
      final result = plainTextAndCaret(doc: doc, composer: composer);
      expect(result.text, '');
      expect(result.caret, 0);
    });

    test('single paragraph with no selection returns text and caret 0', () {
      final doc = MutableDocument(nodes: [
        ParagraphNode(id: 'p1', text: AttributedText('hello world')),
      ]);
      final composer = MutableDocumentComposer();
      final result = plainTextAndCaret(doc: doc, composer: composer);
      expect(result.text, 'hello world');
      expect(result.caret, 0);
    });

    test('single paragraph with caret inside returns that offset', () {
      final doc = MutableDocument(nodes: [
        ParagraphNode(id: 'p1', text: AttributedText('hello world')),
      ]);
      final composer = MutableDocumentComposer()
        ..setSelectionWithReason(
          const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: 'p1',
              nodePosition: TextNodePosition(offset: 6),
            ),
          ),
          SelectionReason.userInteraction,
        );
      final result = plainTextAndCaret(doc: doc, composer: composer);
      expect(result.text, 'hello world');
      expect(result.caret, 6);
    });

    test('two paragraphs joined by \\n; caret in second paragraph adds '
        'prior paragraph length + 1 (the newline)', () {
      final doc = MutableDocument(nodes: [
        ParagraphNode(id: 'p1', text: AttributedText('abc')),
        ParagraphNode(id: 'p2', text: AttributedText('defg')),
      ]);
      final composer = MutableDocumentComposer()
        ..setSelectionWithReason(
          const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: 'p2',
              nodePosition: TextNodePosition(offset: 2),
            ),
          ),
          SelectionReason.userInteraction,
        );
      final result = plainTextAndCaret(doc: doc, composer: composer);
      expect(result.text, 'abc\ndefg');
      expect(result.caret, 4 + 2); // 'abc' (3) + '\n' (1) + 2
    });

    test('caret at the very start of the document returns 0', () {
      final doc = MutableDocument(nodes: [
        ParagraphNode(id: 'p1', text: AttributedText('abc')),
      ]);
      final composer = MutableDocumentComposer()
        ..setSelectionWithReason(
          const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: 'p1',
              nodePosition: TextNodePosition(offset: 0),
            ),
          ),
          SelectionReason.userInteraction,
        );
      final result = plainTextAndCaret(doc: doc, composer: composer);
      expect(result.caret, 0);
    });

    test('expanded (non-collapsed) selection returns the extent offset', () {
      final doc = MutableDocument(nodes: [
        ParagraphNode(id: 'p1', text: AttributedText('hello world')),
      ]);
      final composer = MutableDocumentComposer()
        ..setSelectionWithReason(
          const DocumentSelection(
            base: DocumentPosition(
              nodeId: 'p1',
              nodePosition: TextNodePosition(offset: 0),
            ),
            extent: DocumentPosition(
              nodeId: 'p1',
              nodePosition: TextNodePosition(offset: 5),
            ),
          ),
          SelectionReason.userInteraction,
        );
      final result = plainTextAndCaret(doc: doc, composer: composer);
      expect(result.caret, 5);
    });

    test('non-text node (HorizontalRule) contributes one char to the '
        'concat (a sentinel newline) so cross-node math stays consistent', () {
      final doc = MutableDocument(nodes: [
        ParagraphNode(id: 'p1', text: AttributedText('foo')),
        HorizontalRuleNode(id: 'hr1'),
        ParagraphNode(id: 'p2', text: AttributedText('bar')),
      ]);
      final composer = MutableDocumentComposer()
        ..setSelectionWithReason(
          const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: 'p2',
              nodePosition: TextNodePosition(offset: 1),
            ),
          ),
          SelectionReason.userInteraction,
        );
      final result = plainTextAndCaret(doc: doc, composer: composer);
      // foo (3) + \n (1) + hr placeholder line (0 chars) + \n (1) + 1 inside bar
      expect(result.caret, 3 + 1 + 0 + 1 + 1);
    });
  });
}
