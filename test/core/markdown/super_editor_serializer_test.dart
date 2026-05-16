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

  group('SuperEditorSerializer image cards (D1 slice 8)', () {
    test('standalone ![alt](url) becomes an ImageNode', () {
      const md = '![sunset](attachments/sunset.jpg)';
      final doc = serializer.markdownToDocument(md);
      final node = doc.first as ImageNode;
      expect(node.altText, 'sunset');
      expect(node.imageUrl, 'attachments/sunset.jpg');
      expect(serializer.documentToMarkdown(doc), md);
    });

    test('image with empty alt text round-trips', () {
      const md = '![](attachments/x.png)';
      final doc = serializer.markdownToDocument(md);
      final node = doc.first as ImageNode;
      expect(node.altText, '');
      expect(node.imageUrl, 'attachments/x.png');
      expect(serializer.documentToMarkdown(doc), md);
    });

    test('paragraph + image + paragraph round-trip', () {
      const md = 'before\n\n![cat](cat.png)\n\nafter';
      final doc = serializer.markdownToDocument(md);
      final nodes = doc.toList();
      expect(nodes, hasLength(3));
      expect(nodes[1], isA<ImageNode>());
      expect(serializer.documentToMarkdown(doc), md);
    });

    test('inline image inside a paragraph stays as raw text (deferred to '
        'inline-marks pass)', () {
      const md = 'See ![logo](logo.png) inline.';
      final doc = serializer.markdownToDocument(md);
      // Whole line is a paragraph — not standalone image.
      expect(doc.first, isA<ParagraphNode>());
      expect((doc.first as ParagraphNode).text.toPlainText(),
          'See ![logo](logo.png) inline.');
    });
  });

  group('SuperEditorSerializer file attachment cards (D1 slice 9)', () {
    test('![report](docs/report.pdf) → file attachment, not image', () {
      const md = '![report](docs/report.pdf)';
      final doc = serializer.markdownToDocument(md);
      final node = doc.first;
      expect(node, isA<ParagraphNode>());
      expect(
        (node as ParagraphNode).getMetadataValue('blockType'),
        fileAttachmentAttribution,
      );
      expect(node.getMetadataValue('label'), 'report');
      expect(node.getMetadataValue('path'), 'docs/report.pdf');
      expect(serializer.documentToMarkdown(doc), md);
    });

    test('mp4 video → file attachment', () {
      const md = '![demo](attachments/demo.mp4)';
      final doc = serializer.markdownToDocument(md);
      expect(doc.first, isA<ParagraphNode>());
      expect(
        (doc.first as ParagraphNode).getMetadataValue('blockType'),
        fileAttachmentAttribution,
      );
      expect(serializer.documentToMarkdown(doc), md);
    });

    test('mp3 audio → file attachment', () {
      const md = '![song](attachments/song.mp3)';
      final doc = serializer.markdownToDocument(md);
      expect(
        (doc.first as ParagraphNode).getMetadataValue('blockType'),
        fileAttachmentAttribution,
      );
      expect(serializer.documentToMarkdown(doc), md);
    });

    test('zip and other extensions → file attachment', () {
      for (final ext in const ['zip', 'tar', 'gz', 'docx', 'xlsx', 'ppt']) {
        final md = '![file](thing.$ext)';
        final doc = serializer.markdownToDocument(md);
        expect(
          (doc.first as ParagraphNode).getMetadataValue('blockType'),
          fileAttachmentAttribution,
          reason: 'expected file attachment for .$ext',
        );
        expect(serializer.documentToMarkdown(doc), md);
      }
    });

    test('image extensions stay ImageNode (svg, webp, heic, jpeg)', () {
      for (final ext in const ['svg', 'webp', 'heic', 'jpeg']) {
        final md = '![pic](pic.$ext)';
        final doc = serializer.markdownToDocument(md);
        expect(
          doc.first,
          isA<ImageNode>(),
          reason: 'expected ImageNode for .$ext',
        );
        expect(serializer.documentToMarkdown(doc), md);
      }
    });

    test('mixed image + file attachment in same document', () {
      const md =
          '![logo](logo.png)\n\n![spec](spec.pdf)\n\nthird paragraph';
      final doc = serializer.markdownToDocument(md);
      final nodes = doc.toList();
      expect(nodes[0], isA<ImageNode>());
      expect(nodes[1], isA<ParagraphNode>());
      expect(
        (nodes[1] as ParagraphNode).getMetadataValue('blockType'),
        fileAttachmentAttribution,
      );
      expect(nodes[2], isA<ParagraphNode>());
      expect(serializer.documentToMarkdown(doc), md);
    });
  });

  group('SuperEditorSerializer bookmark cards (D1 slice 10)', () {
    test('standalone https URL → bookmark paragraph', () {
      const md = 'https://example.com';
      final doc = serializer.markdownToDocument(md);
      final node = doc.first as ParagraphNode;
      expect(node.getMetadataValue('blockType'), bookmarkAttribution);
      expect(node.text.toPlainText(), 'https://example.com');
      expect(serializer.documentToMarkdown(doc), md);
    });

    test('http (non-secure) also recognized', () {
      const md = 'http://localhost:8080/api';
      final doc = serializer.markdownToDocument(md);
      expect(
        (doc.first as ParagraphNode).getMetadataValue('blockType'),
        bookmarkAttribution,
      );
      expect(serializer.documentToMarkdown(doc), md);
    });

    test('URL inside a sentence stays a regular paragraph', () {
      const md = 'See https://example.com for details.';
      final doc = serializer.markdownToDocument(md);
      final node = doc.first as ParagraphNode;
      expect(node.getMetadataValue('blockType'), isNot(bookmarkAttribution));
      expect(node.text.toPlainText(),
          'See https://example.com for details.');
    });

    test('paragraph, bookmark, paragraph round-trip', () {
      const md =
          'Reference:\n\nhttps://docs.flutter.dev/perf\n\nis useful.';
      final doc = serializer.markdownToDocument(md);
      expect(doc.toList(), hasLength(3));
      expect(serializer.documentToMarkdown(doc), md);
    });
  });

  group('SuperEditorSerializer wikilink cards (D1 slices 11+12)', () {
    const ulid = '01HX0V0000000000000000000A';

    test('standalone [[ULID]] → sub-page card', () {
      final md = '[[$ulid]]';
      final doc = serializer.markdownToDocument(md);
      final node = doc.first as ParagraphNode;
      expect(node.getMetadataValue('blockType'), subPageAttribution);
      expect(node.text.toPlainText(), '[[$ulid]]');
      expect(serializer.documentToMarkdown(doc), md);
    });

    test('[[ULID#anchor]] preserves the anchor', () {
      final md = '[[$ulid#section-2]]';
      final doc = serializer.markdownToDocument(md);
      final node = doc.first as ParagraphNode;
      expect(node.getMetadataValue('blockType'), subPageAttribution);
      expect(node.text.toPlainText(), '[[$ulid#section-2]]');
      expect(serializer.documentToMarkdown(doc), md);
    });

    test('standalone ![[ULID]] → transclusion card', () {
      final md = '![[$ulid]]';
      final doc = serializer.markdownToDocument(md);
      final node = doc.first as ParagraphNode;
      expect(node.getMetadataValue('blockType'), transclusionAttribution);
      expect(node.text.toPlainText(), '![[$ulid]]');
      expect(serializer.documentToMarkdown(doc), md);
    });

    test('inline [[ULID]] inside a paragraph stays raw text', () {
      final md = 'See [[$ulid]] for details.';
      final doc = serializer.markdownToDocument(md);
      final node = doc.first as ParagraphNode;
      expect(node.getMetadataValue('blockType'), isNot(subPageAttribution));
    });

    test('paragraph + sub-page + transclusion + paragraph round-trip', () {
      final md =
          'before\n\n[[$ulid]]\n\n![[$ulid]]\n\nafter';
      final doc = serializer.markdownToDocument(md);
      final nodes = doc.toList();
      expect(nodes, hasLength(4));
      expect(
        (nodes[1] as ParagraphNode).getMetadataValue('blockType'),
        subPageAttribution,
      );
      expect(
        (nodes[2] as ParagraphNode).getMetadataValue('blockType'),
        transclusionAttribution,
      );
      expect(serializer.documentToMarkdown(doc), md);
    });
  });

  group('SuperEditorSerializer column fences (D1 slice 13)', () {
    test('two-column layout round-trips byte-identical', () {
      const md = ':::cols\n'
          ':::col\n'
          'left content\n'
          ':::\n'
          ':::col\n'
          'right content\n'
          ':::\n'
          ':::';
      final doc = serializer.markdownToDocument(md);
      final node = doc.first as ParagraphNode;
      expect(node.getMetadataValue('blockType'), columnsAttribution);
      expect(serializer.documentToMarkdown(doc), md);
    });

    test('column layout with multiple lines per column', () {
      const md = ':::cols\n'
          ':::col\n'
          'line one\n'
          'line two\n'
          ':::\n'
          ':::col\n'
          'line A\n'
          'line B\n'
          ':::\n'
          ':::';
      final doc = serializer.markdownToDocument(md);
      expect(serializer.documentToMarkdown(doc), md);
    });

    test('paragraph + column layout + paragraph round-trip', () {
      const md = 'before\n\n'
          ':::cols\n'
          ':::col\n'
          'a\n'
          ':::\n'
          ':::col\n'
          'b\n'
          ':::\n'
          ':::\n\n'
          'after';
      final doc = serializer.markdownToDocument(md);
      expect(doc.toList(), hasLength(3));
      expect(serializer.documentToMarkdown(doc), md);
    });
  });

  group('SuperEditorSerializer meta + button blocks (D1 slices 14+15)', () {
    test('[breadcrumb] → breadcrumb paragraph', () {
      const md = '[breadcrumb]';
      final doc = serializer.markdownToDocument(md);
      final node = doc.first as ParagraphNode;
      expect(node.getMetadataValue('blockType'), breadcrumbAttribution);
      expect(node.text.toPlainText(), '[breadcrumb]');
      expect(serializer.documentToMarkdown(doc), md);
    });

    test('[[breadcrumb]] (alternate syntax) also recognized', () {
      const md = '[[breadcrumb]]';
      final doc = serializer.markdownToDocument(md);
      final node = doc.first as ParagraphNode;
      expect(node.getMetadataValue('blockType'), breadcrumbAttribution);
      expect(serializer.documentToMarkdown(doc), md);
    });

    test('[toc] → toc paragraph', () {
      const md = '[toc]';
      final doc = serializer.markdownToDocument(md);
      final node = doc.first as ParagraphNode;
      expect(node.getMetadataValue('blockType'), tocAttribution);
      expect(serializer.documentToMarkdown(doc), md);
    });

    test(':::button fence round-trips with multi-line body', () {
      const md = ':::button\n'
          'action: url\n'
          'url: https://example.com\n'
          'label: Open\n'
          ':::';
      final doc = serializer.markdownToDocument(md);
      final node = doc.first as ParagraphNode;
      expect(node.getMetadataValue('blockType'), buttonAttribution);
      expect(serializer.documentToMarkdown(doc), md);
    });

    test('paragraph + breadcrumb + toc + button round-trip', () {
      const md = 'intro\n\n[breadcrumb]\n\n[toc]\n\n'
          ':::button\n'
          'label: Click\n'
          ':::\n\n'
          'end';
      final doc = serializer.markdownToDocument(md);
      expect(doc.toList(), hasLength(5));
      expect(serializer.documentToMarkdown(doc), md);
    });
  });

  group('SuperEditorSerializer inline marks — bold + code (D1 slice 16)', () {
    test('**bold** wraps a bold attribution span', () {
      const md = 'hello **world** today';
      final doc = serializer.markdownToDocument(md);
      final node = doc.first as ParagraphNode;
      expect(node.text.toPlainText(), 'hello world today');
      // 'world' starts at index 6 (after 'hello '), runs 5 chars to
      // index 10. Bold attribution must cover that exact range.
      expect(node.text.getAllAttributionsAt(6), contains(boldAttribution));
      expect(node.text.getAllAttributionsAt(10), contains(boldAttribution));
      expect(node.text.getAllAttributionsAt(5), isNot(contains(boldAttribution)));
      expect(node.text.getAllAttributionsAt(11), isNot(contains(boldAttribution)));
      expect(serializer.documentToMarkdown(doc), md);
    });

    test('multiple bold spans in one paragraph', () {
      const md = '**hi** there **friend**';
      final doc = serializer.markdownToDocument(md);
      expect((doc.first as ParagraphNode).text.toPlainText(),
          'hi there friend');
      expect(serializer.documentToMarkdown(doc), md);
    });

    test('`inline code` wraps a code attribution span', () {
      const md = 'try `flutter pub get` first';
      final doc = serializer.markdownToDocument(md);
      final node = doc.first as ParagraphNode;
      expect(node.text.toPlainText(), 'try flutter pub get first');
      expect(node.text.getAllAttributionsAt(4), contains(codeAttribution));
      expect(serializer.documentToMarkdown(doc), md);
    });

    test('bold + code in same paragraph', () {
      const md = '**bold** and `code`';
      final doc = serializer.markdownToDocument(md);
      expect((doc.first as ParagraphNode).text.toPlainText(),
          'bold and code');
      expect(serializer.documentToMarkdown(doc), md);
    });

    test('inline code suppresses bold marker emission inside the code run', () {
      // If a code span coincides with a bold attribution, we emit the
      // backticks but suppress the asterisks so the source is clean.
      final doc = MutableDocument(nodes: [
        ParagraphNode(
          id: '1',
          text: AttributedText('a'),
        ),
      ]);
      final p = doc.first as ParagraphNode;
      // Mark the whole character as both bold and code.
      p.text.addAttribution(boldAttribution, const SpanRange(0, 0));
      p.text.addAttribution(codeAttribution, const SpanRange(0, 0));
      expect(serializer.documentToMarkdown(doc), '`a`');
    });

    test('plain text without marks round-trips byte-identical', () {
      const md = 'just plain prose with no marks at all.';
      final doc = serializer.markdownToDocument(md);
      expect(serializer.documentToMarkdown(doc), md);
    });
  });

  group('SuperEditorSerializer inline marks — italic + strike (D1 slice 17)',
      () {
    test('*italic* round-trips with italicsAttribution', () {
      const md = 'do *not* go';
      final doc = serializer.markdownToDocument(md);
      final node = doc.first as ParagraphNode;
      expect(node.text.toPlainText(), 'do not go');
      expect(node.text.getAllAttributionsAt(3), contains(italicsAttribution));
      expect(serializer.documentToMarkdown(doc), md);
    });

    test('~~strike~~ round-trips with strikethroughAttribution', () {
      const md = '~~deleted~~ kept';
      final doc = serializer.markdownToDocument(md);
      final node = doc.first as ParagraphNode;
      expect(node.text.toPlainText(), 'deleted kept');
      expect(
        node.text.getAllAttributionsAt(0),
        contains(strikethroughAttribution),
      );
      expect(serializer.documentToMarkdown(doc), md);
    });

    test('bold + italic + strike in one paragraph', () {
      const md = '**bold** *italic* ~~strike~~';
      final doc = serializer.markdownToDocument(md);
      expect((doc.first as ParagraphNode).text.toPlainText(),
          'bold italic strike');
      expect(serializer.documentToMarkdown(doc), md);
    });

    test('bold takes priority over italic for `**X**`', () {
      const md = '**all bold** and *just italic*';
      final doc = serializer.markdownToDocument(md);
      final node = doc.first as ParagraphNode;
      // First 8 chars 'all bold' must have bold attribution.
      expect(node.text.getAllAttributionsAt(0), contains(boldAttribution));
      expect(
        node.text.getAllAttributionsAt(0),
        isNot(contains(italicsAttribution)),
      );
      expect(serializer.documentToMarkdown(doc), md);
    });

    test('multiple italic runs', () {
      const md = '*a* and *b* and *c*';
      final doc = serializer.markdownToDocument(md);
      expect((doc.first as ParagraphNode).text.toPlainText(), 'a and b and c');
      expect(serializer.documentToMarkdown(doc), md);
    });
  });

  group('SuperEditorSerializer inline marks — underline (D1 slice 18)', () {
    test('<u>X</u> round-trips with underlineAttribution', () {
      const md = 'click <u>here</u> now';
      final doc = serializer.markdownToDocument(md);
      final node = doc.first as ParagraphNode;
      expect(node.text.toPlainText(), 'click here now');
      expect(node.text.getAllAttributionsAt(6), contains(underlineAttribution));
      expect(node.text.getAllAttributionsAt(9), contains(underlineAttribution));
      expect(node.text.getAllAttributionsAt(5),
          isNot(contains(underlineAttribution)));
      expect(serializer.documentToMarkdown(doc), md);
    });

    test('underline combines with bold in the same span', () {
      const md = '<u>**both bold and underlined**</u>';
      final doc = serializer.markdownToDocument(md);
      final node = doc.first as ParagraphNode;
      expect(node.text.getAllAttributionsAt(0), contains(boldAttribution));
      expect(node.text.getAllAttributionsAt(0), contains(underlineAttribution));
      expect(serializer.documentToMarkdown(doc), md);
    });

    test('two separate underline runs', () {
      const md = '<u>first</u> and <u>second</u>';
      final doc = serializer.markdownToDocument(md);
      expect((doc.first as ParagraphNode).text.toPlainText(),
          'first and second');
      expect(serializer.documentToMarkdown(doc), md);
    });
  });

  group('SuperEditorSerializer inline marks — highlight (D1 slice 19)', () {
    test('==X== round-trips with highlightAttribution', () {
      const md = 'pay ==attention== here';
      final doc = serializer.markdownToDocument(md);
      final node = doc.first as ParagraphNode;
      expect(node.text.toPlainText(), 'pay attention here');
      expect(node.text.getAllAttributionsAt(4), contains(highlightAttribution));
      expect(serializer.documentToMarkdown(doc), md);
    });

    test('<mark>X</mark> parses to highlight, serialises as canonical ==X==', () {
      const md = 'this is <mark>marked</mark> text';
      final doc = serializer.markdownToDocument(md);
      final node = doc.first as ParagraphNode;
      expect(node.text.toPlainText(), 'this is marked text');
      expect(node.text.getAllAttributionsAt(8), contains(highlightAttribution));
      // Canonical output uses the Pandoc form.
      expect(serializer.documentToMarkdown(doc),
          'this is ==marked== text');
    });

    test('==X== composes with bold (**==X==**)', () {
      const md = '**==loud and important==**';
      final doc = serializer.markdownToDocument(md);
      final node = doc.first as ParagraphNode;
      expect(node.text.getAllAttributionsAt(0), contains(boldAttribution));
      expect(node.text.getAllAttributionsAt(0), contains(highlightAttribution));
      expect(serializer.documentToMarkdown(doc), md);
    });
  });

  group('SuperEditorSerializer inline marks — sub/sup (D1 slice 20)', () {
    test('~H2O~ → subscriptAttribution', () {
      const md = 'water is ~H2O~ technically';
      final doc = serializer.markdownToDocument(md);
      final node = doc.first as ParagraphNode;
      expect(node.text.toPlainText(), 'water is H2O technically');
      expect(node.text.getAllAttributionsAt(9), contains(subscriptAttribution));
      expect(serializer.documentToMarkdown(doc), md);
    });

    test('^X^ → superscriptAttribution', () {
      const md = 'e=mc^2^';
      final doc = serializer.markdownToDocument(md);
      final node = doc.first as ParagraphNode;
      expect(node.text.toPlainText(), 'e=mc2');
      expect(node.text.getAllAttributionsAt(4),
          contains(superscriptAttribution));
      expect(serializer.documentToMarkdown(doc), md);
    });

    test('~~strike~~ wins over single-tilde subscript on the same run', () {
      const md = '~~strike~~ but ~sub~';
      final doc = serializer.markdownToDocument(md);
      final node = doc.first as ParagraphNode;
      expect(node.text.toPlainText(), 'strike but sub');
      // 'strike' has strike, not subscript.
      expect(node.text.getAllAttributionsAt(0),
          contains(strikethroughAttribution));
      expect(node.text.getAllAttributionsAt(0),
          isNot(contains(subscriptAttribution)));
      // 'sub' has subscript.
      expect(node.text.getAllAttributionsAt(11),
          contains(subscriptAttribution));
      expect(serializer.documentToMarkdown(doc), md);
    });

    test('whitespace inside ~ ~ disqualifies subscript match', () {
      const md = 'try ~not sub~ here';
      final doc = serializer.markdownToDocument(md);
      final node = doc.first as ParagraphNode;
      // Tildes stay literal because of internal whitespace.
      expect(node.text.toPlainText(), 'try ~not sub~ here');
      expect(serializer.documentToMarkdown(doc), md);
    });
  });

  group('SuperEditorSerializer inline color spans (D1 slice 21)', () {
    test('<span style="color:red">X</span> round-trips byte-identical '
        'in paragraph text', () {
      const md = 'this is <span style="color:red">red</span> text';
      final doc = serializer.markdownToDocument(md);
      // Slice 21 keeps the raw HTML span in the paragraph text — the
      // existing renderer interprets it. Future slice promotes to a
      // StyleSpanAttribution for native super_editor styling.
      expect((doc.first as ParagraphNode).text.toPlainText(), md);
      expect(serializer.documentToMarkdown(doc), md);
    });

    test('combined color + background-color span round-trips', () {
      const md =
          'pop <span style="color:white;background-color:black">inverse</span> here';
      final doc = serializer.markdownToDocument(md);
      expect(serializer.documentToMarkdown(doc), md);
    });

    test('color span composes with bold prefix/suffix outside the tag', () {
      const md = '**bold start** then <span style="color:blue">blue</span>';
      final doc = serializer.markdownToDocument(md);
      // The bold prefix is still a real attribution.
      final node = doc.first as ParagraphNode;
      expect(node.text.getAllAttributionsAt(0), contains(boldAttribution));
      // The color span is raw text — no `colorAttribution`.
      expect(serializer.documentToMarkdown(doc), md);
    });
  });

  group('SuperEditorSerializer inline chips — wikilink + date (D1 slice 22)',
      () {
    const ulid = '01HX0V0000000000000000000A';

    test('inline [[ULID]] mid-paragraph attaches inlineWikilinkAttribution', () {
      final md = 'See [[$ulid]] for the design doc.';
      final doc = serializer.markdownToDocument(md);
      final node = doc.first as ParagraphNode;
      // Body text is unchanged.
      expect(node.text.toPlainText(), md);
      // 'See ' is 4 chars; the wikilink starts at index 4 and runs 30
      // chars (`[[` + 26 ULID + `]]`).
      expect(node.text.getAllAttributionsAt(4),
          contains(inlineWikilinkAttribution));
      expect(node.text.getAllAttributionsAt(33),
          contains(inlineWikilinkAttribution));
      expect(node.text.getAllAttributionsAt(3),
          isNot(contains(inlineWikilinkAttribution)));
      expect(serializer.documentToMarkdown(doc), md);
    });

    test('inline [[ULID#anchor]] keeps the anchor in the chip span', () {
      final md = 'jump to [[$ulid#section]] now';
      final doc = serializer.markdownToDocument(md);
      final node = doc.first as ParagraphNode;
      expect(
        node.text.getAllAttributionsAt(8),
        contains(inlineWikilinkAttribution),
      );
      expect(serializer.documentToMarkdown(doc), md);
    });

    test('inline @YYYY-MM-DD attaches inlineDateAttribution', () {
      const md = 'meeting @2026-05-17 in the morning';
      final doc = serializer.markdownToDocument(md);
      final node = doc.first as ParagraphNode;
      // 'meeting ' is 8 chars; the date pill is 11 chars long.
      expect(node.text.getAllAttributionsAt(8),
          contains(inlineDateAttribution));
      expect(node.text.getAllAttributionsAt(18),
          contains(inlineDateAttribution));
      expect(serializer.documentToMarkdown(doc), md);
    });

    test('two date pills in the same paragraph', () {
      const md = 'between @2026-05-17 and @2026-06-01';
      final doc = serializer.markdownToDocument(md);
      expect(serializer.documentToMarkdown(doc), md);
    });

    test('standalone [[ULID]] still goes to the block-level sub-page path '
        '(slice 11 contract still holds)', () {
      final md = '[[$ulid]]';
      final doc = serializer.markdownToDocument(md);
      final node = doc.first as ParagraphNode;
      // Block-level attribution wins for standalone line.
      expect(node.getMetadataValue('blockType'), subPageAttribution);
      // No conflicting inline attribution either.
      expect(node.text.getAllAttributionsAt(0),
          isNot(contains(inlineWikilinkAttribution)));
    });
  });
}
