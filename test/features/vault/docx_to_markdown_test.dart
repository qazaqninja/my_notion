/// .docx is a ZIP. We mint a synthetic one in-memory with the `archive`
/// package so the test doesn't need a Word binary on disk.
library;

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/vault/data/docx_to_markdown.dart';

List<int> _mkDocx(String documentXml) {
  final archive = Archive()
    ..addFile(ArchiveFile(
        'word/document.xml', documentXml.length, documentXml.codeUnits));
  return ZipEncoder().encode(archive);
}

void main() {
  group('DocxToMarkdown.convert', () {
    test('plain paragraph round-trip', () {
      const xml = '''<?xml version="1.0"?>
<w:document xmlns:w="ns"><w:body>
<w:p><w:r><w:t>Hello world</w:t></w:r></w:p>
</w:body></w:document>''';
      final md = DocxToMarkdown.convert(_mkDocx(xml));
      expect(md, 'Hello world');
    });

    test('Heading1/2/3 styles → ATX', () {
      const xml = '''<w:document><w:body>
<w:p><w:pPr><w:pStyle w:val="Heading1"/></w:pPr><w:r><w:t>One</w:t></w:r></w:p>
<w:p><w:pPr><w:pStyle w:val="Heading2"/></w:pPr><w:r><w:t>Two</w:t></w:r></w:p>
<w:p><w:pPr><w:pStyle w:val="Heading3"/></w:pPr><w:r><w:t>Three</w:t></w:r></w:p>
</w:body></w:document>''';
      final md = DocxToMarkdown.convert(_mkDocx(xml));
      expect(md, contains('# One'));
      expect(md, contains('## Two'));
      expect(md, contains('### Three'));
    });

    test('bold + italic + strike inside a paragraph', () {
      const xml = '''<w:document><w:body>
<w:p>
  <w:r><w:t>plain </w:t></w:r>
  <w:r><w:rPr><w:b/></w:rPr><w:t>bold</w:t></w:r>
  <w:r><w:t> and </w:t></w:r>
  <w:r><w:rPr><w:i/></w:rPr><w:t>italic</w:t></w:r>
  <w:r><w:t> + </w:t></w:r>
  <w:r><w:rPr><w:strike/></w:rPr><w:t>gone</w:t></w:r>
</w:p>
</w:body></w:document>''';
      final md = DocxToMarkdown.convert(_mkDocx(xml));
      expect(md, contains('**bold**'));
      expect(md, contains('*italic*'));
      expect(md, contains('~~gone~~'));
    });

    test('numbered list ilvl → indented bullets', () {
      const xml = '''<w:document><w:body>
<w:p><w:pPr><w:numPr><w:ilvl w:val="0"/></w:numPr></w:pPr><w:r><w:t>top</w:t></w:r></w:p>
<w:p><w:pPr><w:numPr><w:ilvl w:val="1"/></w:numPr></w:pPr><w:r><w:t>nested</w:t></w:r></w:p>
</w:body></w:document>''';
      final md = DocxToMarkdown.convert(_mkDocx(xml));
      expect(md, contains('- top'));
      expect(md, contains('  - nested'));
    });

    test('empty paragraphs are dropped', () {
      const xml = '''<w:document><w:body>
<w:p><w:r><w:t>kept</w:t></w:r></w:p>
<w:p></w:p>
<w:p><w:r><w:t>after</w:t></w:r></w:p>
</w:body></w:document>''';
      final md = DocxToMarkdown.convert(_mkDocx(xml));
      // Two paragraphs separated by exactly one blank line.
      expect(md, equals('kept\n\nafter'));
    });

    test('tabs + breaks inside runs collapse to a space', () {
      const xml = '''<w:document><w:body>
<w:p><w:r><w:t>a</w:t><w:tab/><w:t>b</w:t><w:br/><w:t>c</w:t></w:r></w:p>
</w:body></w:document>''';
      final md = DocxToMarkdown.convert(_mkDocx(xml));
      expect(md, 'a b c');
    });

    test('missing document.xml → empty string', () {
      // ZIP with no document.xml
      final archive = Archive()
        ..addFile(ArchiveFile('other.txt', 4, 'noop'.codeUnits));
      final bytes = ZipEncoder().encode(archive);
      expect(DocxToMarkdown.convert(bytes), '');
    });

    test('non-zip bytes → empty string', () {
      expect(DocxToMarkdown.convert(const [0x00, 0x01, 0x02]), '');
    });
  });
}
