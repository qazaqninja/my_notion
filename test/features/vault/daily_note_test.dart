import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/vault/data/daily_note.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory vault;
  setUp(() async {
    vault = await Directory.systemTemp.createTemp('quill_daily_');
  });
  tearDown(() async {
    try {
      await vault.delete(recursive: true);
    } catch (_) {}
  });

  test('first call creates Daily/<YYYY-MM-DD>.md with frontmatter',
      () async {
    final r = await DailyNote.openTodaysNote(
      vault,
      now: DateTime(2026, 5, 15),
    );
    expect(r.alreadyExisted, isFalse);
    expect(r.relativePath, 'Daily/2026-05-15.md');
    expect(r.ulid.length, 26);
    final body = await File(p.join(vault.path, r.relativePath))
        .readAsString();
    expect(body, contains('id: ${r.ulid}'));
    expect(body, contains('title: 2026-05-15'));
    expect(body, contains('tags: [daily]'));
    expect(body, contains('# 2026-05-15'));
    expect(body, contains('## Notes'));
    expect(body, contains('## To do'));
  });

  test('second call returns the same ULID + alreadyExisted=true',
      () async {
    final now = DateTime(2026, 5, 15);
    final first = await DailyNote.openTodaysNote(vault, now: now);
    final second = await DailyNote.openTodaysNote(vault, now: now);
    expect(second.ulid, first.ulid);
    expect(second.alreadyExisted, isTrue);
    expect(second.relativePath, first.relativePath);
  });

  test('different days create different files', () async {
    final a = await DailyNote.openTodaysNote(vault,
        now: DateTime(2026, 5, 15));
    final b = await DailyNote.openTodaysNote(vault,
        now: DateTime(2026, 5, 16));
    expect(a.relativePath, isNot(b.relativePath));
    expect(a.ulid, isNot(b.ulid));
  });

  test('externally-created daily note without id: gets one persisted (M772)',
      () async {
    // A user (or Obsidian, or a sync client) drops a daily file in
    // place with frontmatter that has no `id:`. The old regex-grep
    // would mint a fresh ULID on every call and never write it back —
    // /editor/<ulid> would 404 because the indexer's separately-minted
    // ULID never matches the one openTodaysNote returned.
    final folder = Directory(p.join(vault.path, 'Daily'));
    await folder.create(recursive: true);
    final file = File(p.join(folder.path, '2026-05-15.md'));
    await file.writeAsString(
      '---\ntitle: 2026-05-15\ntags: [daily]\n---\n\n# Things\n',
    );

    final first = await DailyNote.openTodaysNote(
      vault,
      now: DateTime(2026, 5, 15),
    );
    expect(first.alreadyExisted, isTrue);
    expect(first.ulid.length, 26);

    // The id was written back, not just returned in memory.
    final patched = await file.readAsString();
    expect(patched, contains('id: ${first.ulid}'),
        reason: 'ULID must be persisted into the file so the indexer agrees');
    expect(patched, contains('title: 2026-05-15'),
        reason: 'pre-existing frontmatter survives');
    expect(patched, contains('# Things'),
        reason: 'body content survives');

    // Calling again returns the SAME id (no second mint).
    final second = await DailyNote.openTodaysNote(
      vault,
      now: DateTime(2026, 5, 15),
    );
    expect(second.ulid, equals(first.ulid));
  });

  test('quoted id: in frontmatter resolves cleanly (M772)', () async {
    final folder = Directory(p.join(vault.path, 'Daily'));
    await folder.create(recursive: true);
    final file = File(p.join(folder.path, '2026-05-15.md'));
    // Quotes survive the YAML parser as part of the rawScalar — the
    // strict regex would have missed this and minted a fresh ULID.
    await file.writeAsString(
      '---\nid: "01HXFOOBARBAZQUXFOOBARBAZQ"\ntitle: 2026-05-15\n---\n',
    );

    final r = await DailyNote.openTodaysNote(
      vault,
      now: DateTime(2026, 5, 15),
    );
    expect(r.ulid, equals('01HXFOOBARBAZQUXFOOBARBAZQ'));
  });
}
