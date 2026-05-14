import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/ulid/ulid_generator.dart';
import 'html_to_markdown.dart';

/// Imports an .html / .htm file into a Quill vault as a fresh page.
/// Walks `HtmlToMarkdown.convert` on the body, derives a title from
/// the `title` tag (or the filename when missing), and writes:
///
///   `vaultRoot/Inbox/safe-title.md`
///
/// with frontmatter (id, title, imported_from). Returns the relative
/// path the page was written to. The vault's indexer must be re-run
/// after import to surface the new page.
class HtmlPageImporter {
  const HtmlPageImporter._();

  static const _ulids = UlidGenerator();

  static Future<ImportedPageSummary> importTo(
    File source,
    Directory vaultRoot, {
    String targetFolder = 'Inbox',
  }) async {
    final html = await source.readAsString();
    final body = HtmlToMarkdown.convert(html);
    final fallbackTitle = p.basenameWithoutExtension(source.path);
    final title = HtmlToMarkdown.extractTitle(html) ?? fallbackTitle;
    final ulid = _ulids.generate();
    final safe = _safeFileName(title);
    final folder = Directory(p.join(vaultRoot.path, targetFolder));
    await folder.create(recursive: true);
    final rel = p.join(targetFolder, '$safe.md');
    final out = File(p.join(vaultRoot.path, rel));
    final imported = p.basename(source.path);
    final frontmatter = '---\n'
        'id: $ulid\n'
        'title: ${_yamlString(title)}\n'
        'imported_from: ${_yamlString(imported)}\n'
        '---\n\n';
    await out.writeAsString('$frontmatter$body');
    return ImportedPageSummary(
      ulid: ulid,
      relativePath: rel,
      title: title,
    );
  }

  /// Strip filesystem-unsafe characters and clamp length so the
  /// resulting file name is portable.
  static String _safeFileName(String title) {
    var s = title.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '-');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (s.isEmpty) s = 'Imported page';
    if (s.length > 100) s = s.substring(0, 100);
    return s;
  }

  /// Quote the value if it contains a YAML-significant character, else
  /// emit it bare. Keeps frontmatter readable for simple cases.
  static String _yamlString(String value) {
    if (RegExp(r'''[#:>\[\]\{\}\|"'`%@&!*]''').hasMatch(value)) {
      return '"${value.replaceAll('"', r'\"')}"';
    }
    return value;
  }
}

class ImportedPageSummary {
  const ImportedPageSummary({
    required this.ulid,
    required this.relativePath,
    required this.title,
  });
  final String ulid;
  final String relativePath;
  final String title;
}
