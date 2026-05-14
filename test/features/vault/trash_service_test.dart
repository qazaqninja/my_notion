import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/vault/data/trash_service.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tmp;
  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('quill_trash_svc_');
  });
  tearDown(() async {
    try {
      await tmp.delete(recursive: true);
    } catch (_) {}
  });

  test('list returns [] when .trash is absent', () async {
    final items = await const TrashService().list(tmp);
    expect(items, isEmpty);
  });

  test('list reads frontmatter title + ulid from each .trash/<bucket>/*.md',
      () async {
    final bucket = Directory(p.join(tmp.path, '.trash', '2026-05'));
    await bucket.create(recursive: true);
    await File(p.join(bucket.path, 'first.md')).writeAsString(
      '---\nid: 01HX0V9R5N6E8L3P7Q8S9U2X4B\ntitle: First\n---\nbody\n',
    );
    await File(p.join(bucket.path, 'second.md')).writeAsString(
      '---\nid: 01HX0VEY5T6K7R9X4Y8Z0A3D4G\ntitle: Second\n---\nbody\n',
    );

    final items = await const TrashService().list(tmp);
    expect(items, hasLength(2));
    expect(items.map((i) => i.title).toSet(), equals({'First', 'Second'}));
    expect(items.map((i) => i.bucket).toSet(), equals({'2026-05'}));
  });

  test('restore moves the file back to vault root and avoids collisions',
      () async {
    final bucket = Directory(p.join(tmp.path, '.trash', '2026-05'));
    await bucket.create(recursive: true);
    final src = File(p.join(bucket.path, 'note.md'));
    await src.writeAsString('---\ntitle: Note\n---\n');
    // Pre-existing collision at vault root.
    await File(p.join(tmp.path, 'note.md')).writeAsString('original');

    final items = await const TrashService().list(tmp);
    final restored = await const TrashService().restore(items.first, tmp);
    expect(p.basename(restored), equals('note-restored-1.md'));
    expect(await File(restored).exists(), isTrue);
    expect(await src.exists(), isFalse);
  });

  test('deleteForever removes the file', () async {
    final bucket = Directory(p.join(tmp.path, '.trash', '2026-05'));
    await bucket.create(recursive: true);
    final f = File(p.join(bucket.path, 'gone.md'));
    await f.writeAsString('---\ntitle: Gone\n---\n');

    final items = await const TrashService().list(tmp);
    final ok = await const TrashService().deleteForever(items.first);
    expect(ok, isTrue);
    expect(await f.exists(), isFalse);
  });
}
