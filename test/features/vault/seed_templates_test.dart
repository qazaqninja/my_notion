import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/vault/data/seed_templates.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('quill_seed_templates_test_');
  });

  tearDown(() async {
    try {
      await tmp.delete(recursive: true);
    } catch (_) {}
  });

  test('install writes templates with fresh ULIDs and today as date', () async {
    final n = await const SeedTemplates().install(tmp);
    expect(n, greaterThan(0));
    final dir = Directory(p.join(tmp.path, 'Templates'));
    expect(await dir.exists(), isTrue);

    final files = await dir.list().toList();
    expect(files, hasLength(n));
    for (final f in files) {
      if (f is! File) continue;
      final body = await f.readAsString();
      expect(body, contains('id: '));
      // Every template's id should be a valid ULID (26 chars [0-9A-Z]).
      final idMatch =
          RegExp(r'^id: ([0-9A-Za-z]{26})', multiLine: true).firstMatch(body);
      expect(idMatch, isNotNull, reason: '${p.basename(f.path)} missing id');
      // Placeholders are replaced.
      expect(body, isNot(contains('__ULID__')));
      expect(body, isNot(contains('__DATE__')));
    }
  });

  test('install is idempotent — second call writes 0 files', () async {
    final first = await const SeedTemplates().install(tmp);
    final second = await const SeedTemplates().install(tmp);
    expect(first, greaterThan(0));
    expect(second, 0);
  });

  test('install picks distinct ULIDs across templates', () async {
    await const SeedTemplates().install(tmp);
    final dir = Directory(p.join(tmp.path, 'Templates'));
    final files = (await dir.list().toList()).whereType<File>().toList();
    final ulids = <String>{};
    for (final f in files) {
      final body = await f.readAsString();
      final m = RegExp(r'^id: ([0-9A-Za-z]{26})', multiLine: true)
          .firstMatch(body);
      if (m != null) ulids.add(m.group(1)!);
    }
    expect(ulids, isNotEmpty);
    expect(ulids.length, files.length);
  });
}
