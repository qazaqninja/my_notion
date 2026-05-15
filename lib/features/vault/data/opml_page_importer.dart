import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/markdown/yaml_scalar.dart';
import '../../../core/text/strip_bom.dart';
import '../../../core/ulid/ulid_generator.dart';
import 'opml_to_markdown.dart';

/// Imports an `.opml` outline export into a Quill vault as a fresh
/// markdown page. Title is taken from the OPML `<head><title>` tag
/// (or the filename when absent); the body is rendered as a nested
/// bullet list via `OpmlToMarkdown.convert`.
class OpmlPageImporter {
  const OpmlPageImporter._();

  static const _ulids = UlidGenerator();

  static Future<ImportedOpmlSummary> importTo(
    File source,
    Directory vaultRoot, {
    String targetFolder = 'Inbox',
  }) async {
    final raw = stripBom(await source.readAsString());
    final body = OpmlToMarkdown.convert(raw);
    final fallback = p.basenameWithoutExtension(source.path);
    final title = OpmlToMarkdown.extractTitle(raw) ?? fallback;
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
    return ImportedOpmlSummary(
        ulid: ulid, relativePath: rel, title: title);
  }

  static String _safeFileName(String title) {
    var s = title.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '-');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (s.isEmpty) s = 'Imported outline';
    if (s.length > 100) s = s.substring(0, 100);
    return s;
  }

}

class ImportedOpmlSummary {
  const ImportedOpmlSummary({
    required this.ulid,
    required this.relativePath,
    required this.title,
  });
  final String ulid;
  final String relativePath;
  final String title;
}
