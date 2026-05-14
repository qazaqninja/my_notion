import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/ulid/ulid_generator.dart';
import 'roam_to_markdown.dart';

/// Imports a Roam Research JSON export into a Quill vault — one .md
/// page per top-level entry. Each page lands under
/// `<vaultRoot>/Roam/<safe-title>.md` (or [targetFolder]) with
/// frontmatter id / title / imported_from / created_at.
class RoamPageImporter {
  const RoamPageImporter._();

  static const _ulids = UlidGenerator();

  static Future<RoamImportSummary> importTo(
    File source,
    Directory vaultRoot, {
    String targetFolder = 'Roam',
  }) async {
    final raw = await source.readAsString();
    final pages = RoamToMarkdown.convert(raw);
    final folder = Directory(p.join(vaultRoot.path, targetFolder));
    await folder.create(recursive: true);
    final imported = p.basename(source.path);
    final written = <ImportedRoamPage>[];
    for (final page in pages) {
      final ulid = _ulids.generate();
      final safe = _safeFileName(page.title);
      final rel = p.join(targetFolder, '$safe.md');
      final out = File(p.join(vaultRoot.path, rel));
      final createdAt = page.createdAtMs != null
          ? DateTime.fromMillisecondsSinceEpoch(page.createdAtMs!, isUtc: true)
              .toIso8601String()
              .substring(0, 10)
          : null;
      final fmBuf = StringBuffer('---\n');
      fmBuf.writeln('id: $ulid');
      fmBuf.writeln('title: ${_yamlString(page.title)}');
      fmBuf.writeln('imported_from: ${_yamlString(imported)}');
      if (createdAt != null) fmBuf.writeln('created_at: $createdAt');
      fmBuf.writeln('---');
      fmBuf.writeln();
      await out.writeAsString('${fmBuf.toString()}${page.body.trim()}\n');
      written.add(ImportedRoamPage(
        ulid: ulid,
        relativePath: rel,
        title: page.title,
      ));
    }
    return RoamImportSummary(folder: targetFolder, pages: written);
  }

  static String _safeFileName(String title) {
    var s = title.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '-');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (s.isEmpty) s = 'Imported page';
    if (s.length > 100) s = s.substring(0, 100);
    return s;
  }

  static String _yamlString(String value) {
    if (RegExp(r'''[#:>\[\]\{\}\|"'`%@&!*]''').hasMatch(value)) {
      return '"${value.replaceAll('"', r'\"')}"';
    }
    return value;
  }
}

class ImportedRoamPage {
  const ImportedRoamPage({
    required this.ulid,
    required this.relativePath,
    required this.title,
  });
  final String ulid;
  final String relativePath;
  final String title;
}

class RoamImportSummary {
  const RoamImportSummary({required this.folder, required this.pages});
  final String folder;
  final List<ImportedRoamPage> pages;
}
