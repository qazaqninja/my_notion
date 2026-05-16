// Smoke test for SuperEditorSerializer (Phase D / D1 slice 1 of the
// 1m-loop plan).
//
// Slice 1 only handles paragraph nodes. Headings, lists, code, quotes,
// math, mermaid, image cards etc. land in subsequent slices. The test
// verifies the round-trip contract at the paragraph level: a single
// markdown line → 1 ParagraphNode → same text on the way back.

import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/core/markdown/super_editor_serializer.dart';
import 'package:super_editor/super_editor.dart';

void main() {
  const serializer = SuperEditorSerializer();

  group('SuperEditorSerializer paragraph round-trip (D1 slice 1)', () {
    test('empty markdown returns a document with one empty paragraph', () {
      final doc = serializer.markdownToDocument('');
      final nodes = doc.toList();
      expect(nodes, hasLength(1));
      expect(nodes.first, isA<ParagraphNode>());
      expect((nodes.first as ParagraphNode).text.toPlainText(), '');
    });

    test('single paragraph round-trips as one ParagraphNode', () {
      const md = 'hello world';
      final doc = serializer.markdownToDocument(md);
      expect(doc.toList(), hasLength(1));
      expect(serializer.documentToMarkdown(doc), 'hello world');
    });

    test('blank-line-separated paragraphs become two ParagraphNodes', () {
      const md = 'first paragraph\n\nsecond paragraph';
      final doc = serializer.markdownToDocument(md);
      final nodes = doc.toList();
      expect(nodes, hasLength(2));
      expect(serializer.documentToMarkdown(doc), md);
    });

    test('soft-wrapped lines within a paragraph merge with a single space', () {
      const md = 'line one\nline two\nline three';
      final doc = serializer.markdownToDocument(md);
      final nodes = doc.toList();
      expect(nodes, hasLength(1));
      expect((nodes.first as ParagraphNode).text.toPlainText(),
          'line one line two line three');
    });
  });

  group('SuperEditorSerializer heading round-trip (D1 slice 2)', () {
    test('# Title round-trips as header1 ParagraphNode', () {
      const md = '# Title';
      final doc = serializer.markdownToDocument(md);
      final nodes = doc.toList();
      expect(nodes, hasLength(1));
      final node = nodes.first as ParagraphNode;
      expect(node.getMetadataValue('blockType'), header1Attribution);
      expect(node.text.toPlainText(), 'Title');
      expect(serializer.documentToMarkdown(doc), '# Title');
    });

    test('## Subtitle round-trips as header2', () {
      const md = '## Subtitle';
      final doc = serializer.markdownToDocument(md);
      final node = doc.first as ParagraphNode;
      expect(node.getMetadataValue('blockType'), header2Attribution);
      expect(serializer.documentToMarkdown(doc), '## Subtitle');
    });

    test('### Section round-trips as header3', () {
      const md = '### Section';
      final doc = serializer.markdownToDocument(md);
      final node = doc.first as ParagraphNode;
      expect(node.getMetadataValue('blockType'), header3Attribution);
      expect(serializer.documentToMarkdown(doc), '### Section');
    });

    test('headings can be mixed with paragraphs', () {
      const md = '# Title\n\nFirst paragraph\n\n## Subtitle\n\nSecond paragraph';
      final doc = serializer.markdownToDocument(md);
      expect(doc.toList(), hasLength(4));
      expect(serializer.documentToMarkdown(doc), md);
    });

    test('#### (level 4) is not a heading — stays a paragraph with the # marks',
        () {
      const md = '#### Deep';
      final doc = serializer.markdownToDocument(md);
      final node = doc.first as ParagraphNode;
      // super_editor only ships header1-3; level 4+ stays as plain
      // paragraph text per slice 2's scope. super_editor sets a default
      // `paragraphAttribution` block type so we check the *negation* —
      // it must not be a header attribution.
      final block = node.getMetadataValue('blockType');
      expect(block, isNot(header1Attribution));
      expect(block, isNot(header2Attribution));
      expect(block, isNot(header3Attribution));
      expect(node.text.toPlainText(), '#### Deep');
    });
  });

  group('SuperEditorSerializer list round-trip (D1 slice 3)', () {
    test('unordered list with `-` markers round-trips', () {
      const md = '- alpha\n- beta\n- gamma';
      final doc = serializer.markdownToDocument(md);
      final nodes = doc.toList();
      expect(nodes, hasLength(3));
      expect(nodes.every((n) => n is ListItemNode), isTrue);
      expect(
        nodes.every(
          (n) => (n as ListItemNode).type == ListItemType.unordered,
        ),
        isTrue,
      );
      expect(serializer.documentToMarkdown(doc), md);
    });

    test('unordered list with `*` markers normalises to `-`', () {
      const md = '* alpha\n* beta';
      final doc = serializer.markdownToDocument(md);
      // Serialise emits `- ` for unordered items (canonical form).
      expect(serializer.documentToMarkdown(doc), '- alpha\n- beta');
    });

    test('ordered list re-numbers from 1 on serialise', () {
      const md = '7. seven\n8. eight\n9. nine';
      final doc = serializer.markdownToDocument(md);
      // Numbering is re-emitted as 1, 2, 3 regardless of source.
      expect(serializer.documentToMarkdown(doc), '1. seven\n2. eight\n3. nine');
    });

    test('mixed ordered + unordered separated by blank line', () {
      const md = '1. one\n2. two\n\n- a\n- b';
      final doc = serializer.markdownToDocument(md);
      final nodes = doc.toList();
      expect(nodes, hasLength(4));
      expect(
        (nodes[0] as ListItemNode).type,
        ListItemType.ordered,
      );
      expect(
        (nodes[2] as ListItemNode).type,
        ListItemType.unordered,
      );
      expect(serializer.documentToMarkdown(doc), md);
    });

    test('todo `- [ ] task` becomes incomplete TaskNode', () {
      const md = '- [ ] write tests';
      final doc = serializer.markdownToDocument(md);
      final node = doc.first as TaskNode;
      expect(node.isComplete, isFalse);
      expect(node.text.toPlainText(), 'write tests');
      expect(serializer.documentToMarkdown(doc), md);
    });

    test('todo `- [x] task` becomes complete TaskNode', () {
      const md = '- [x] done';
      final doc = serializer.markdownToDocument(md);
      final node = doc.first as TaskNode;
      expect(node.isComplete, isTrue);
      expect(serializer.documentToMarkdown(doc), md);
    });

    test('mixed todos and bullets', () {
      const md = '- [ ] todo one\n- bullet\n- [x] done';
      final doc = serializer.markdownToDocument(md);
      final nodes = doc.toList();
      expect(nodes[0], isA<TaskNode>());
      expect(nodes[1], isA<ListItemNode>());
      expect(nodes[2], isA<TaskNode>());
      expect(serializer.documentToMarkdown(doc), md);
    });
  });

  group('SuperEditorSerializer code + hr round-trip (D1 slice 4)', () {
    test('fenced code block with language tag round-trips', () {
      const md = '```dart\nvoid main() {}\n```';
      final doc = serializer.markdownToDocument(md);
      final node = doc.first as ParagraphNode;
      expect(node.getMetadataValue('blockType'), codeAttribution);
      expect(node.getMetadataValue('language'), 'dart');
      expect(node.text.toPlainText(), 'void main() {}');
      expect(serializer.documentToMarkdown(doc), md);
    });

    test('fenced code block without language tag', () {
      const md = '```\nplain text\n```';
      final doc = serializer.markdownToDocument(md);
      final node = doc.first as ParagraphNode;
      expect(node.getMetadataValue('blockType'), codeAttribution);
      expect(node.getMetadataValue('language'), isNull);
      expect(serializer.documentToMarkdown(doc), md);
    });

    test('multi-line code block preserves internal newlines', () {
      const md = '```py\ndef hi():\n    print("hi")\n```';
      final doc = serializer.markdownToDocument(md);
      final node = doc.first as ParagraphNode;
      expect(node.text.toPlainText(), 'def hi():\n    print("hi")');
      expect(serializer.documentToMarkdown(doc), md);
    });

    test('--- emits HorizontalRuleNode and round-trips', () {
      const md = '---';
      final doc = serializer.markdownToDocument(md);
      expect(doc.first, isA<HorizontalRuleNode>());
      expect(serializer.documentToMarkdown(doc), '---');
    });

    test('*** and ___ also emit HorizontalRuleNode', () {
      final docStar = serializer.markdownToDocument('***');
      expect(docStar.first, isA<HorizontalRuleNode>());
      final docUnder = serializer.markdownToDocument('___');
      expect(docUnder.first, isA<HorizontalRuleNode>());
      // Both serialise back to canonical `---`.
      expect(serializer.documentToMarkdown(docStar), '---');
      expect(serializer.documentToMarkdown(docUnder), '---');
    });

    test('paragraph, hr, paragraph round-trip', () {
      const md = 'before\n\n---\n\nafter';
      final doc = serializer.markdownToDocument(md);
      expect(doc.toList(), hasLength(3));
      expect(serializer.documentToMarkdown(doc), md);
    });
  });

  group('SuperEditorSerializer blockquote + callout (D1 slice 5)', () {
    test('single-line blockquote', () {
      const md = '> just a quote';
      final doc = serializer.markdownToDocument(md);
      final node = doc.first as ParagraphNode;
      expect(node.getMetadataValue('blockType'), blockquoteAttribution);
      expect(node.text.toPlainText(), 'just a quote');
      expect(serializer.documentToMarkdown(doc), md);
    });

    test('multi-line blockquote merges with internal newlines', () {
      const md = '> first line\n> second line';
      final doc = serializer.markdownToDocument(md);
      final node = doc.first as ParagraphNode;
      expect(node.text.toPlainText(), 'first line\nsecond line');
      expect(serializer.documentToMarkdown(doc), md);
    });

    test('GFM admonition with [!NOTE] stores callout kind', () {
      const md = '> [!NOTE]\n> Pay attention.';
      final doc = serializer.markdownToDocument(md);
      final node = doc.first as ParagraphNode;
      expect(node.getMetadataValue('blockType'), blockquoteAttribution);
      expect(node.getMetadataValue('callout'), 'note');
      expect(node.text.toPlainText(), 'Pay attention.');
      expect(serializer.documentToMarkdown(doc), md);
    });

    test('GFM admonition kinds tip / important / warning / caution', () {
      for (final kind in const ['TIP', 'IMPORTANT', 'WARNING', 'CAUTION']) {
        final md = '> [!$kind]\n> body';
        final doc = serializer.markdownToDocument(md);
        final node = doc.first as ParagraphNode;
        expect(
          node.getMetadataValue('callout'),
          kind.toLowerCase(),
          reason: 'callout key for $kind',
        );
        expect(serializer.documentToMarkdown(doc), md);
      }
    });

    test('paragraph, blockquote, paragraph round-trip', () {
      const md = 'before\n\n> a quote\n\nafter';
      final doc = serializer.markdownToDocument(md);
      expect(doc.toList(), hasLength(3));
      expect(serializer.documentToMarkdown(doc), md);
    });
  });

  group('SuperEditorSerializer math + mermaid (D1 slice 6)', () {
    test('single-line math \$\$E=mc^2\$\$ round-trips', () {
      const md = r'$$E = mc^2$$';
      final doc = serializer.markdownToDocument(md);
      final node = doc.first as ParagraphNode;
      expect(node.getMetadataValue('blockType'), mathBlockAttribution);
      expect(node.text.toPlainText(), 'E = mc^2');
      expect(serializer.documentToMarkdown(doc), md);
    });

    test('multi-line math block round-trips with internal newlines', () {
      const md = '\$\$\n\\int_0^1 x dx = \\frac{1}{2}\n\$\$';
      final doc = serializer.markdownToDocument(md);
      final node = doc.first as ParagraphNode;
      expect(node.getMetadataValue('blockType'), mathBlockAttribution);
      expect(node.text.toPlainText(), r'\int_0^1 x dx = \frac{1}{2}');
      expect(serializer.documentToMarkdown(doc), md);
    });

    test('mermaid code block preserves the language tag (slice 4 path)', () {
      const md = '```mermaid\ngraph TD\n  A-->B\n```';
      final doc = serializer.markdownToDocument(md);
      final node = doc.first as ParagraphNode;
      expect(node.getMetadataValue('blockType'), codeAttribution);
      expect(node.getMetadataValue('language'), 'mermaid');
      expect(serializer.documentToMarkdown(doc), md);
    });

    test('paragraph, math, paragraph round-trip', () {
      const md = 'see equation:\n\n\$\$x = 1\$\$\n\nbelow.';
      final doc = serializer.markdownToDocument(md);
      expect(doc.toList(), hasLength(3));
      expect(serializer.documentToMarkdown(doc), md);
    });
  });

  group('SuperEditorSerializer pipe tables (D1 slice 7)', () {
    test('simple 2-column table round-trips byte-identical', () {
      const md = '| name | age |\n|---|---|\n| Alice | 30 |\n| Bob | 25 |';
      final doc = serializer.markdownToDocument(md);
      final node = doc.first as ParagraphNode;
      expect(node.getMetadataValue('blockType'), tableAttribution);
      expect(serializer.documentToMarkdown(doc), md);
    });

    test('table with alignment colons preserves them', () {
      const md = '| left | mid | right |\n|:---|:---:|---:|\n| a | b | c |';
      final doc = serializer.markdownToDocument(md);
      expect(serializer.documentToMarkdown(doc), md);
    });

    test('paragraph above and below a table', () {
      const md = 'intro\n\n| h |\n|---|\n| v |\n\noutro';
      final doc = serializer.markdownToDocument(md);
      expect(doc.toList(), hasLength(3));
      expect(serializer.documentToMarkdown(doc), md);
    });

    test('lone `|`-prefixed line without separator stays a paragraph', () {
      const md = '| not | a | table';
      final doc = serializer.markdownToDocument(md);
      final node = doc.first as ParagraphNode;
      expect(node.getMetadataValue('blockType'), isNot(tableAttribution));
      // No table attribution → treated as plain text.
    });
  });
}
