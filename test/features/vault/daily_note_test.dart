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
}
