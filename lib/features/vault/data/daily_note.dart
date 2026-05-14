import 'dart:io';

import 'package:path/path.dart' as p;

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
      // Parse existing id from the frontmatter so the caller can
      // route to /editor/<ulid> without a fresh read of every file.
      final raw = await file.readAsString();
      final m = RegExp(r'^id:\s*([A-Z0-9]{26})', multiLine: true)
          .firstMatch(raw);
      final id = m?.group(1) ?? _ulids.generate();
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
