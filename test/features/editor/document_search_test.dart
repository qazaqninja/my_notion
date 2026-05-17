import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/editor/domain/document_search.dart';
import 'package:super_editor/super_editor.dart';

MutableDocument _docFromTexts(List<String> texts) {
  return MutableDocument(
    nodes: [
      for (var i = 0; i < texts.length; i++)
        ParagraphNode(id: 'n$i', text: AttributedText(texts[i])),
    ],
  );
}

void main() {
  group('findMatches', () {
    test('returns empty list for empty query', () {
      final doc = _docFromTexts(['hello world']);
      expect(findMatches(document: doc, query: ''), isEmpty);
    });

    test('returns empty list when no matches', () {
      final doc = _docFromTexts(['hello world']);
      expect(findMatches(document: doc, query: 'xyz'), isEmpty);
    });

    test('finds a single case-insensitive match', () {
      final doc = _docFromTexts(['Hello World']);
      final matches = findMatches(document: doc, query: 'hello');
      expect(matches, [
        const DocumentMatch(nodeId: 'n0', start: 0, end: 5),
      ]);
    });

    test('finds matches across multiple nodes', () {
      final doc = _docFromTexts(['foo bar', 'baz foo qux']);
      final matches = findMatches(document: doc, query: 'foo');
      expect(matches, [
        const DocumentMatch(nodeId: 'n0', start: 0, end: 3),
        const DocumentMatch(nodeId: 'n1', start: 4, end: 7),
      ]);
    });

    test('finds multiple matches within a single node', () {
      final doc = _docFromTexts(['foo foo foo']);
      final matches = findMatches(document: doc, query: 'foo');
      expect(matches, [
        const DocumentMatch(nodeId: 'n0', start: 0, end: 3),
        const DocumentMatch(nodeId: 'n0', start: 4, end: 7),
        const DocumentMatch(nodeId: 'n0', start: 8, end: 11),
      ]);
    });

    test('finds overlapping matches with forward-by-1 scan', () {
      final doc = _docFromTexts(['aaaa']);
      final matches = findMatches(document: doc, query: 'aa');
      expect(matches.map((m) => (m.start, m.end)), [
        (0, 2),
        (1, 3),
        (2, 4),
      ]);
    });

    test('case-sensitive mode skips differently-cased text', () {
      final doc = _docFromTexts(['Hello hello HELLO']);
      final matches = findMatches(
        document: doc,
        query: 'hello',
        caseSensitive: true,
      );
      expect(matches, [
        const DocumentMatch(nodeId: 'n0', start: 6, end: 11),
      ]);
    });

    test('skips non-TextNode blocks silently', () {
      final doc = MutableDocument(
        nodes: [
          ParagraphNode(id: 'p1', text: AttributedText('hello there')),
          HorizontalRuleNode(id: 'hr1'),
          ParagraphNode(id: 'p2', text: AttributedText('hello world')),
        ],
      );
      final matches = findMatches(document: doc, query: 'hello');
      expect(matches, [
        const DocumentMatch(nodeId: 'p1', start: 0, end: 5),
        const DocumentMatch(nodeId: 'p2', start: 0, end: 5),
      ]);
    });

    test('DocumentMatch.length returns span size', () {
      const m = DocumentMatch(nodeId: 'n0', start: 3, end: 8);
      expect(m.length, 5);
    });

    test('DocumentMatch equality is value-based', () {
      const a = DocumentMatch(nodeId: 'n0', start: 1, end: 4);
      const b = DocumentMatch(nodeId: 'n0', start: 1, end: 4);
      const c = DocumentMatch(nodeId: 'n0', start: 1, end: 5);
      expect(a, b);
      expect(a, isNot(c));
    });

    test('handles list-item nodes as text', () {
      final doc = MutableDocument(
        nodes: [
          ListItemNode.unordered(id: 'li1', text: AttributedText('find me')),
        ],
      );
      final matches = findMatches(document: doc, query: 'find');
      expect(matches, [
        const DocumentMatch(nodeId: 'li1', start: 0, end: 4),
      ]);
    });

    test('handles task nodes as text', () {
      final doc = MutableDocument(
        nodes: [
          TaskNode(
            id: 't1',
            text: AttributedText('todo find it'),
            isComplete: false,
          ),
        ],
      );
      final matches = findMatches(document: doc, query: 'find');
      expect(matches, [
        const DocumentMatch(nodeId: 't1', start: 5, end: 9),
      ]);
    });
  });
}
