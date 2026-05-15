import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/fs/unique_path.dart';
import '../../../core/markdown/frontmatter_parser.dart';
import '../../../core/markdown/yaml_scalar.dart';
import '../../../core/text/strip_bom.dart';
import '../../../core/ulid/ulid_generator.dart';
import '../domain/entities/frontmatter_entry.dart';

/// Imports a plain-text (.txt) or markdown (.md / .markdown) file into a
/// Quill vault as a fresh page. Plain-text files are wrapped in
/// frontmatter and placed verbatim in the body. Markdown files preserve
/// any existing frontmatter, only adding `id:` (when absent) and
/// `imported_from:`.
///
/// Land path: `<vaultRoot>/<targetFolder>/<safe-title>.md` (Inbox/ by
/// default). Returns the new ULID + relative path + title — callers
/// pipe these into a snackbar + reindex.
class TextPageImporter {
  const TextPageImporter._();

  static const _ulids = UlidGenerator();

  /// Read [source], detect plain-text vs markdown by extension, and
  /// write a new page. The vault's indexer must be re-run after this
  /// returns to surface the new page.
  static Future<ImportedTextSummary> importTo(
    File source,
    Directory vaultRoot, {
    String targetFolder = 'Inbox',
  }) async {
    final ext = p.extension(source.path).toLowerCase();
    final content = stripBom(await source.readAsString());
    final basename = p.basenameWithoutExtension(source.path);
    final imported = p.basename(source.path);
    if (ext == '.md' || ext == '.markdown') {
      return _importMarkdown(content, basename, imported, vaultRoot,
          targetFolder: targetFolder);
    }
    return _importPlainText(content, basename, imported, vaultRoot,
        targetFolder: targetFolder);
  }

  static Future<ImportedTextSummary> _importPlainText(
    String body,
    String fallbackTitle,
    String importedFrom,
    Directory vaultRoot, {
    required String targetFolder,
  }) async {
    final ulid = _ulids.generate();
    final title = fallbackTitle;
    final safe = _safeFileName(title);
    final folder = Directory(p.join(vaultRoot.path, targetFolder));
    await folder.create(recursive: true);
    final rel = await uniqueRelativePath(
        vaultRoot, p.join(targetFolder, '$safe.md'));
    final out = File(p.join(vaultRoot.path, rel));
    final frontmatter = '---\n'
        'id: $ulid\n'
        'title: ${yamlSafeScalar(title)}\n'
        'imported_from: ${yamlSafeScalar(importedFrom)}\n'
        '---\n\n';
    await out.writeAsString('$frontmatter${body.trimRight()}\n');
    return ImportedTextSummary(
        ulid: ulid, relativePath: rel, title: title);
  }

  static Future<ImportedTextSummary> _importMarkdown(
    String content,
    String fallbackTitle,
    String importedFrom,
    Directory vaultRoot, {
    required String targetFolder,
  }) async {
    final parsed = FrontmatterParser.parse(content);
    final entries = List<FrontmatterEntry>.from(parsed.frontmatter.entries);
    var ulid = parsed.frontmatter.get('id')?.toString().trim();
    if (ulid == null || ulid.isEmpty) {
      ulid = _ulids.generate();
      entries.insert(
        0,
        FrontmatterEntry(
          key: 'id',
          rawScalar: ulid,
          type: FrontmatterType.ulid,
          value: ulid,
        ),
      );
    }
    final title =
        parsed.frontmatter.get('title')?.toString() ?? fallbackTitle;
    // Always stamp imported_from so users can trace.
    final hasImportedFrom = entries.any((e) => e.key == 'imported_from');
    if (!hasImportedFrom) {
      entries.add(FrontmatterEntry(
        key: 'imported_from',
        rawScalar: yamlSafeScalar(importedFrom),
        type: FrontmatterType.text,
        value: importedFrom,
      ));
    }
    final safe = _safeFileName(title);
    final folder = Directory(p.join(vaultRoot.path, targetFolder));
    await folder.create(recursive: true);
    final rel = await uniqueRelativePath(
        vaultRoot, p.join(targetFolder, '$safe.md'));
    final out = File(p.join(vaultRoot.path, rel));
    // Build a fresh frontmatter block (we may have edited entries).
    final fmBuf = StringBuffer('---\n');
    for (final e in entries) {
      fmBuf.writeln('${e.key}: ${e.rawScalar}');
    }
    fmBuf.writeln('---');
    fmBuf.writeln();
    await out.writeAsString('$fmBuf${parsed.body.trimRight()}\n');
    return ImportedTextSummary(
        ulid: ulid, relativePath: rel, title: title);
  }

  static String _safeFileName(String title) {
    var s = title.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '-');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (s.isEmpty) s = 'Imported page';
    if (s.length > 100) s = s.substring(0, 100);
    return s;
  }

}

class ImportedTextSummary {
  const ImportedTextSummary({
    required this.ulid,
    required this.relativePath,
    required this.title,
  });
  final String ulid;
  final String relativePath;
  final String title;
}
