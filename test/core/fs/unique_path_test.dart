import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/core/fs/unique_path.dart';
import 'package:path/path.dart' as p;

/// Tests for `uniqueRelativePath`, the disambiguation helper that
/// prevents the atomic tmp→rename in `VaultFsDatasource` from
/// silently overwriting an existing markdown page at the same
/// destination path.
///
/// Mirrors the lib-tree layout (FS-04 / TS-01).
void main() {
  late Directory vault;

  setUp(() async {
    vault = await Directory.systemTemp.createTemp('quill_unique_');
  });

  tearDown(() async {
    if (await vault.exists()) {
      await vault.delete(recursive: true);
    }
  });

  group('uniqueRelativePath — no collision', () {
    test('returns the requested path verbatim when nothing exists', () async {
      final out = await uniqueRelativePath(vault, 'Notes.md');
      expect(out, 'Notes.md');
    });

    test('preserves nested folder paths', () async {
      final out = await uniqueRelativePath(
          vault, 'Inbox/Quick capture.md',);
      expect(out, 'Inbox/Quick capture.md');
    });

    test('handles markdown extension at the root', () async {
      final out = await uniqueRelativePath(vault, 'README.md');
      expect(out, 'README.md');
    });
  });

  group('uniqueRelativePath — single collision', () {
    test('appends ` (2)` when one file exists', () async {
      await File(p.join(vault.path, 'Notes.md'))
          .writeAsString('first');
      final out = await uniqueRelativePath(vault, 'Notes.md');
      expect(out, 'Notes (2).md');
    });

    test('inserts ` (2)` before the extension, not after', () async {
      await File(p.join(vault.path, 'Page.md')).writeAsString('x');
      final out = await uniqueRelativePath(vault, 'Page.md');
      // Sanity: the dot stays between basename and .md, not at the end.
      expect(out.endsWith('.md'), true);
      expect(out, 'Page (2).md');
    });

    test('preserves folder portion on collision', () async {
      final dir = Directory(p.join(vault.path, 'Inbox'));
      await dir.create();
      await File(p.join(dir.path, 'Note.md')).writeAsString('a');
      final out = await uniqueRelativePath(vault, 'Inbox/Note.md');
      expect(out, p.join('Inbox', 'Note (2).md'));
    });
  });

  group('uniqueRelativePath — multiple collisions', () {
    test('climbs the (N) counter past 2', () async {
      await File(p.join(vault.path, 'X.md')).writeAsString('a');
      await File(p.join(vault.path, 'X (2).md')).writeAsString('b');
      await File(p.join(vault.path, 'X (3).md')).writeAsString('c');
      final out = await uniqueRelativePath(vault, 'X.md');
      expect(out, 'X (4).md');
    });

    test('finds the first free slot, skipping occupied ones', () async {
      // Create X.md, X (2).md, but leave X (3).md open. The helper
      // should find (3) without bumping past it.
      await File(p.join(vault.path, 'Y.md')).writeAsString('a');
      await File(p.join(vault.path, 'Y (2).md')).writeAsString('b');
      final out = await uniqueRelativePath(vault, 'Y.md');
      expect(out, 'Y (3).md');
    });
  });

  group('uniqueRelativePath — file extension handling', () {
    test('files without extensions still disambiguate', () async {
      await File(p.join(vault.path, 'NoExt')).writeAsString('a');
      final out = await uniqueRelativePath(vault, 'NoExt');
      expect(out, 'NoExt (2)');
    });

    test('multi-dot extensions keep only the trailing piece', () async {
      // p.extension('archive.tar.gz') == '.gz'. The helper splits
      // on the trailing extension only — this matches the documented
      // package:path behaviour.
      await File(p.join(vault.path, 'archive.tar.gz'))
          .writeAsString('a');
      final out = await uniqueRelativePath(vault, 'archive.tar.gz');
      expect(out, 'archive.tar (2).gz');
    });
  });
}
