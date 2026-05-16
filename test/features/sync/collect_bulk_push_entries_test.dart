import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/sync/domain/usecases/collect_bulk_push_entries.dart';
import 'package:my_notion/features/vault/domain/entities/vault_tree.dart';
import 'package:path/path.dart' as p;

/// E32 — walks a fake vault tree and asserts the helper materializes
/// one entry per file with the correct sha256.
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('quill_bulk_push_');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  String sha256Of(String s) => sha256.convert(utf8.encode(s)).toString();

  test('emits one entry per VaultFile with the file body + sha256', () async {
    await File(p.join(tempDir.path, 'a.md')).writeAsString('# a\n');
    await Directory(p.join(tempDir.path, 'sub')).create();
    await File(p.join(tempDir.path, 'sub/b.md')).writeAsString('# b\n');

    const tree = VaultTree(topLevel: [
      VaultFile(name: 'a.md', relativePath: 'a.md', ulid: 'A'),
      VaultFolder(name: 'sub', relativePath: 'sub', children: [
        VaultFile(name: 'b.md', relativePath: 'sub/b.md', ulid: 'B'),
      ]),
    ]);

    final entries = await collectBulkPushEntries(
      tree: tree,
      vaultRoot: tempDir.path,
    );

    expect(entries.length, 2);

    final a = entries.firstWhere((e) => e.relpath == 'a.md');
    expect(a.body, '# a\n');
    expect(a.sha256, sha256Of('# a\n'));

    final b = entries.firstWhere((e) => e.relpath == 'sub/b.md');
    expect(b.body, '# b\n');
    expect(b.sha256, sha256Of('# b\n'));
  });

  test('skips files that fail to read (no aborting)', () async {
    // Only one of two files actually exists on disk.
    await File(p.join(tempDir.path, 'exists.md')).writeAsString('hi\n');

    const tree = VaultTree(topLevel: [
      VaultFile(name: 'exists.md', relativePath: 'exists.md', ulid: 'X'),
      VaultFile(name: 'missing.md', relativePath: 'missing.md', ulid: 'Y'),
    ]);

    final entries = await collectBulkPushEntries(
      tree: tree,
      vaultRoot: tempDir.path,
    );

    expect(entries.length, 1);
    expect(entries.single.relpath, 'exists.md');
  });

  test('empty tree → empty list', () async {
    final entries = await collectBulkPushEntries(
      tree: VaultTree.empty,
      vaultRoot: tempDir.path,
    );
    expect(entries, isEmpty);
  });
}
