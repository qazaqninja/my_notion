import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/vault/data/docx_page_importer.dart';
import 'package:path/path.dart' as p;

List<int> _mkDocx(String documentXml) {
  final archive = Archive()
    ..addFile(ArchiveFile(
        'word/document.xml', documentXml.length, documentXml.codeUnits));
  return ZipEncoder().encode(archive);
}

void main() {
  late Directory vault;
  late Directory inputs;
  setUp(() async {
    vault = await Directory.systemTemp.createTemp('quill_docx_import_');
    inputs = await Directory.systemTemp.createTemp('quill_docx_input_');
  });
  tearDown(() async {
    try {
      await vault.delete(recursive: true);
    } catch (_) {}
    try {
      await inputs.delete(recursive: true);
    } catch (_) {}
  });

  test('imports a docx into Inbox with frontmatter', () async {
    const xml = '''<w:document><w:body>
<w:p><w:pPr><w:pStyle w:val="Heading1"/></w:pPr><w:r><w:t>My Doc</w:t></w:r></w:p>
<w:p><w:r><w:t>Body paragraph.</w:t></w:r></w:p>
</w:body></w:document>''';
    final src = File(p.join(inputs.path, 'specs.docx'));
    await src.writeAsBytes(_mkDocx(xml));
    final summary = await DocxPageImporter.importTo(src, vault);
    expect(summary.title, 'specs');
    expect(summary.relativePath, 'Inbox/specs.md');
    final body = await File(p.join(vault.path, summary.relativePath))
        .readAsString();
    expect(body, contains('id: ${summary.ulid}'));
    expect(body, contains('title: specs'));
    expect(body, contains('imported_from: specs.docx'));
    expect(body, contains('# My Doc'));
    expect(body, contains('Body paragraph.'));
  });

  test('targetFolder override', () async {
    final src = File(p.join(inputs.path, 'q.docx'));
    await src.writeAsBytes(_mkDocx(
        '<w:document><w:body><w:p><w:r><w:t>x</w:t></w:r></w:p></w:body></w:document>'));
    final summary =
        await DocxPageImporter.importTo(src, vault, targetFolder: 'Imports');
    expect(summary.relativePath, 'Imports/q.md');
  });
}
