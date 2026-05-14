import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/editor/data/comments_service.dart';

void main() {
  late Directory tmp;
  const svc = CommentsService();
  const pageUlid = '01HXYZABCDEFGHJKMNPQRSTVWX';

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('quill_comments_test_');
  });

  tearDown(() async {
    try {
      await tmp.delete(recursive: true);
    } catch (_) {}
  });

  test('list returns empty when no sidecar exists', () async {
    final r = await svc.list(tmp, pageUlid);
    expect(r, isEmpty);
  });

  test('add creates sidecar + persists entry', () async {
    await svc.add(tmp, pageUlid, author: 'Alice', body: 'first thought');
    final r = await svc.list(tmp, pageUlid);
    expect(r, hasLength(1));
    expect(r.single.author, 'Alice');
    expect(r.single.body, 'first thought');
    expect(r.single.resolved, isFalse);
    expect(r.single.id, isNotEmpty);
  });

  test('add appends + preserves order', () async {
    await svc.add(tmp, pageUlid, author: 'A', body: 'one');
    await svc.add(tmp, pageUlid, author: 'B', body: 'two');
    await svc.add(tmp, pageUlid, author: 'C', body: 'three');
    final r = await svc.list(tmp, pageUlid);
    expect(r.map((c) => c.body), ['one', 'two', 'three']);
  });

  test('setResolved toggles flag without losing other entries', () async {
    await svc.add(tmp, pageUlid, author: 'A', body: 'one');
    await svc.add(tmp, pageUlid, author: 'B', body: 'two');
    final mid = (await svc.list(tmp, pageUlid))[1];
    await svc.setResolved(tmp, pageUlid, mid.id, true);
    final after = await svc.list(tmp, pageUlid);
    expect(after.first.resolved, isFalse);
    expect(after[1].resolved, isTrue);
    expect(after[1].body, 'two');
  });

  test('delete removes a single entry', () async {
    await svc.add(tmp, pageUlid, author: 'A', body: 'one');
    await svc.add(tmp, pageUlid, author: 'B', body: 'two');
    final first = (await svc.list(tmp, pageUlid)).first;
    await svc.delete(tmp, pageUlid, first.id);
    final after = await svc.list(tmp, pageUlid);
    expect(after, hasLength(1));
    expect(after.single.body, 'two');
  });

  test('delete of last entry removes the sidecar file', () async {
    await svc.add(tmp, pageUlid, author: 'A', body: 'one');
    final only = (await svc.list(tmp, pageUlid)).single;
    await svc.delete(tmp, pageUlid, only.id);
    expect(await svc.list(tmp, pageUlid), isEmpty);
    expect(
      await File('${tmp.path}/.quill/comments/$pageUlid.yaml').exists(),
      isFalse,
    );
  });

  test('quotes in bodies survive round-trip', () async {
    await svc.add(tmp, pageUlid,
        author: 'A', body: 'has "double" and \\ backslash');
    final r = await svc.list(tmp, pageUlid);
    expect(r.single.body, 'has "double" and \\ backslash');
  });

  group('block-level comments', () {
    const blockA = '01HZBLOCKAAAAAAAAAAAAAAAAA';
    const blockB = '01HZBLOCKBBBBBBBBBBBBBBBBB';

    test('add with blockId persists it', () async {
      await svc.add(tmp, pageUlid,
          author: 'Alice', body: 'about block A', blockId: blockA);
      final r = (await svc.list(tmp, pageUlid)).single;
      expect(r.blockId, blockA);
      expect(r.body, 'about block A');
    });

    test('listForBlock filters by blockId', () async {
      await svc.add(tmp, pageUlid, author: 'A', body: 'page-level');
      await svc.add(tmp, pageUlid,
          author: 'A', body: 'on A', blockId: blockA);
      await svc.add(tmp, pageUlid,
          author: 'A', body: 'on B', blockId: blockB);
      await svc.add(tmp, pageUlid,
          author: 'A', body: 'on A again', blockId: blockA);
      final onA = await svc.listForBlock(tmp, pageUlid, blockA);
      expect(onA.map((c) => c.body), ['on A', 'on A again']);
      final onB = await svc.listForBlock(tmp, pageUlid, blockB);
      expect(onB.single.body, 'on B');
      final pageLevel = (await svc.list(tmp, pageUlid))
          .where((c) => c.blockId == null)
          .toList();
      expect(pageLevel.single.body, 'page-level');
    });

    test('blockId survives save/load round-trip', () async {
      await svc.add(tmp, pageUlid,
          author: 'A', body: 'first', blockId: blockA);
      await svc.add(tmp, pageUlid, author: 'A', body: 'second'); // no blockId
      final reloaded = await svc.list(tmp, pageUlid);
      expect(reloaded.first.blockId, blockA);
      expect(reloaded[1].blockId, isNull);
    });

    test('old sidecars without block_id still load (back-compat)',
        () async {
      // Hand-write a sidecar that pre-dates the block-id field.
      final f =
          File('${tmp.path}/.quill/comments/$pageUlid.yaml');
      await f.parent.create(recursive: true);
      await f.writeAsString('''
- id: 01HZOLD000000000000000000A
  author: "Bob"
  at: 2026-01-01T00:00:00.000Z
  body: "ancient comment"
''');
      final r = (await svc.list(tmp, pageUlid)).single;
      expect(r.body, 'ancient comment');
      expect(r.blockId, isNull);
    });
  });
}
