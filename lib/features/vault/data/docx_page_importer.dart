import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/markdown/yaml_scalar.dart';
import '../../../core/ulid/ulid_generator.dart';
import 'docx_to_markdown.dart';

/// Imports a Word .docx file into a Quill vault as a single page.
/// Reads bytes, unzips, converts the body via `DocxToMarkdown.convert`,
/// and writes `<vault>/Inbox/<safe-title>.md` with frontmatter id /
/// title (basename) / imported_from.
class DocxPageImporter {
  const DocxPageImporter._();

  static const _ulids = UlidGenerator();

  static Future<ImportedDocxSummary> importTo(
    File source,
    Directory vaultRoot, {
    String targetFolder = 'Inbox',
  }) async {
    final bytes = await source.readAsBytes();
    final body = DocxToMarkdown.convert(bytes);
    final title = p.basenameWithoutExtension(source.path);
    final ulid = _ulids.generate();
    final safe = _safeFileName(title);
    final folder = Directory(p.join(vaultRoot.path, targetFolder));
    await folder.create(recursive: true);
    final rel = p.join(targetFolder, '$safe.md');
    final out = File(p.join(vaultRoot.path, rel));
    final imported = p.basename(source.path);
    final fm = '---\n'
        'id: $ulid\n'
        'title: ${yamlSafeScalar(title)}\n'
        'imported_from: ${yamlSafeScalar(imported)}\n'
        '---\n\n';
    await out.writeAsString('$fm${body.trim()}\n');
    return ImportedDocxSummary(
        ulid: ulid, relativePath: rel, title: title);
  }

  static String _safeFileName(String title) {
    var s = title.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '-');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (s.isEmpty) s = 'Imported document';
    if (s.length > 100) s = s.substring(0, 100);
    return s;
  }

}

class ImportedDocxSummary {
  const ImportedDocxSummary({
    required this.ulid,
    required this.relativePath,
    required this.title,
  });
  final String ulid;
  final String relativePath;
  final String title;
}
