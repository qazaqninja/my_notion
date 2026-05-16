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
}
