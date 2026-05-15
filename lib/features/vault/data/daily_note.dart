import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/markdown/frontmatter_parser.dart';
import '../../../core/ulid/ulid_generator.dart';

/// Opens (or creates) today's daily note. Lands at
/// `<vault>/Daily/<YYYY-MM-DD>.md`. The file is created lazily —
/// callers can fire this from the command palette without worrying
/// about whether today's note exists yet.
class DailyNote {
  const DailyNote._();

  static const _ulids = UlidGenerator();

  /// Returns `(ulid, relativePath, alreadyExisted)`. The ULID is the
  /// existing page's id when the file was already there, or a freshly-
  /// generated one when this call creates it.
  static Future<DailyNoteResult> openTodaysNote(Directory vaultRoot,
      {DateTime? now}) async {
    final d = now ?? DateTime.now();
    final yyyy = d.year.toString().padLeft(4, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    final date = '$yyyy-$mm-$dd';
    final folder = Directory(p.join(vaultRoot.path, 'Daily'));
    await folder.create(recursive: true);
    final rel = p.join('Daily', '$date.md');
    final file = File(p.join(vaultRoot.path, rel));
    if (await file.exists()) {
      // Parse the existing frontmatter via the YAML-aware parser so
      // quoted IDs (`id: "01HX..."`) and IDs whose surrounding
      // whitespace differs from the strict-regex form still resolve.
      // A regex-grep previously only matched `id: <26-char-ulid>` at
      // line start; quoted or padded values silently fell through to
      // _ulids.generate(), so the caller routed to a freshly-minted
      // ULID that the indexer never produced — /editor/<ulid> 404'd.
      final raw = await file.readAsString();
      final parsed = FrontmatterParser.parse(raw);
      var id = parsed.frontmatter.id;
      if (id == null || id.isEmpty) {
        // No id at all — mint one AND persist it back so the indexer
        // sees the same ULID we just returned. Without the write-back
        // the indexer would generate its own (different) id on each
        // reindex, and navigation would fail.
        id = _ulids.generate();
        final patched = _injectId(raw, id);
        await file.writeAsString(patched);
      }
      return DailyNoteResult(
        ulid: id,
        relativePath: rel,
        alreadyExisted: true,
      );
    }
    final ulid = _ulids.generate();
    final buf = StringBuffer('---\n')
      ..writeln('id: $ulid')
      ..writeln('title: $date')
      ..writeln('created_at: $date')
      ..writeln('tags: [daily]')
      ..writeln('---')
      ..writeln()
      ..writeln('# $date')
      ..writeln()
      ..writeln('## Notes')
      ..writeln()
      ..writeln('## To do')
      ..writeln()
      ..writeln('- [ ] ');
    await file.writeAsString(buf.toString());
    return DailyNoteResult(
      ulid: ulid,
      relativePath: rel,
      alreadyExisted: false,
    );
  }
}

/// Insert `id: <ulid>` right after the opening `---` fence of an
/// existing markdown file. Falls back to prepending a complete
/// frontmatter block when the file has none.
String _injectId(String raw, String ulid) {
  final lines = raw.split('\n');
  if (lines.isNotEmpty && lines.first.trim() == '---') {
    // Insert immediately after the opening fence so the id is visible
    // before any other key — matches what fresh `_onCreatePage` writes.
    return [lines.first, 'id: $ulid', ...lines.skip(1)].join('\n');
  }
  // No frontmatter at all — prepend a minimal block and keep the
  // existing body verbatim.
  return '---\nid: $ulid\n---\n\n$raw';
}

class DailyNoteResult {
  const DailyNoteResult({
    required this.ulid,
    required this.relativePath,
    required this.alreadyExisted,
  });
  final String ulid;
  final String relativePath;
  final bool alreadyExisted;
}
