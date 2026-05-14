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
}
