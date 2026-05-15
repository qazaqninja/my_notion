import 'package:file/memory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/core/ulid/ulid_generator.dart';
import 'package:my_notion/features/vault/data/datasources/vault_fs_datasource.dart';

const _northwindMd = '''---
id: 01HX0V9R5N6E8L3P7Q8S9U2X4B
title: Northwind
stage: expanding
arr: 420000
owner: Diego
---

# Northwind

Body here.
''';

const _acmecoMd = '''---
id: 01HX0V8Q3M4D7K2N9P6R5T8W1A
title: Acmeco
stage: closed-won
---

# Acmeco

Mid-market customer.
''';

const _untitledMd = '# Untitled\n\nBody only, no frontmatter.\n';

void main() {
  late MemoryFileSystem fs;
  late VaultFsDatasource ds;

  setUp(() {
    fs = MemoryFileSystem.test();
    fs.directory('/vault').createSync();
    ds = VaultFsDatasource(ulids: const UlidGenerator(), fs: fs);
  });

  group('scan', () {
    test('walks recursively and emits one Page per .md', () async {
      fs.file('/vault/Northwind.md').writeAsStringSync(_northwindMd);
      fs.directory('/vault/Operations/Customers').createSync(recursive: true);
      fs.file('/vault/Operations/Customers/Acmeco.md').writeAsStringSync(_acmecoMd);
      fs.file('/vault/Untitled.md').writeAsStringSync(_untitledMd);

      final pages = await ds.scan(fs.directory('/vault')).toList();
      expect(pages, hasLength(3));
      expect(pages.map((p) => p.title).toSet(), {'Northwind', 'Acmeco', 'Untitled'});
    });

    test('skips ignored directories (.git, .obsidian, node_modules)', () async {
      fs.file('/vault/keep.md').writeAsStringSync(_northwindMd);
      fs.directory('/vault/.git/refs').createSync(recursive: true);
      fs.file('/vault/.git/refs/file.md').writeAsStringSync('# Hidden');
      fs.directory('/vault/.obsidian').createSync();
      fs.file('/vault/.obsidian/note.md').writeAsStringSync('# Ignored');
      fs.directory('/vault/node_modules/pkg').createSync(recursive: true);
      fs.file('/vault/node_modules/pkg/readme.md').writeAsStringSync('# Skip');

      final pages = await ds.scan(fs.directory('/vault')).toList();
      expect(pages, hasLength(1));
      expect(pages.first.title, 'Northwind');
    });

    test('skips non-.md files', () async {
      fs.file('/vault/page.md').writeAsStringSync(_northwindMd);
      fs.file('/vault/.DS_Store').writeAsStringSync('binary');
      fs.file('/vault/image.png').writeAsStringSync('binary');
      fs.file('/vault/notes.txt').writeAsStringSync('text');

      final pages = await ds.scan(fs.directory('/vault')).toList();
      expect(pages, hasLength(1));
    });

    test('one malformed file is skipped, others survive (M712)', () async {
      // Yaml `loadYaml` throws on conflicting flow markers. Without
      // M712's try/catch wrapper around readOne, the very first scan
      // of this vault would have thrown and the user would see zero
      // pages even though good.md and another.md are perfectly valid.
      fs.file('/vault/good.md').writeAsStringSync(_northwindMd);
      fs.file('/vault/broken.md').writeAsStringSync(
        '---\nkey: [unclosed bracket, no terminator\nmore: stuff\n---\nbody\n',
      );
      fs.file('/vault/another.md').writeAsStringSync(_acmecoMd);

      // Should not throw — scan yields the two valid pages and logs
      // the broken one.
      final pages = await ds.scan(fs.directory('/vault')).toList();
      // The valid pages must still surface.
      final titles = pages.map((p) => p.title).toSet();
      expect(titles, contains('Northwind'),
          reason: 'good page must be indexed');
      expect(titles, contains('Acmeco'),
          reason: 'second good page must be indexed');
    });
  });

  group('readOne', () {
    test('extracts title and ULID from frontmatter', () async {
      fs.file('/vault/Northwind.md').writeAsStringSync(_northwindMd);
      final page = await ds.readOne(
        fs.file('/vault/Northwind.md'),
        vaultRoot: fs.directory('/vault'),
      );
      expect(page.ulid, '01HX0V9R5N6E8L3P7Q8S9U2X4B');
      expect(page.title, 'Northwind');
      expect(page.relativePath, 'Northwind.md');
    });

    test('falls back to filename title when no frontmatter', () async {
      fs.file('/vault/my-thoughts.md').writeAsStringSync(_untitledMd);
      final page = await ds.readOne(
        fs.file('/vault/my-thoughts.md'),
        vaultRoot: fs.directory('/vault'),
      );
      expect(page.title, 'my-thoughts');
      // ULID is generated on the fly when missing — present but unique.
      expect(page.ulid, hasLength(26));
    });

    test('computes relativePath from vault root', () async {
      fs.directory('/vault/A/B').createSync(recursive: true);
      fs.file('/vault/A/B/page.md').writeAsStringSync(_northwindMd);
      final page = await ds.readOne(
        fs.file('/vault/A/B/page.md'),
        vaultRoot: fs.directory('/vault'),
      );
      expect(page.relativePath, 'A/B/page.md');
    });
  });

  group('write', () {
    test('round-trips Northwind byte-identical when frontmatter untouched', () async {
      fs.file('/vault/Northwind.md').writeAsStringSync(_northwindMd);
      final page = await ds.readOne(
        fs.file('/vault/Northwind.md'),
        vaultRoot: fs.directory('/vault'),
      );
      await ds.write(page, vaultRoot: fs.directory('/vault'));
      final reread = fs.file('/vault/Northwind.md').readAsStringSync();
      expect(reread, equals(_northwindMd));
    });

    test('preserves frontmatter key order after a body edit', () async {
      fs.file('/vault/Northwind.md').writeAsStringSync(_northwindMd);
      final page = await ds.readOne(
        fs.file('/vault/Northwind.md'),
        vaultRoot: fs.directory('/vault'),
      );
      final edited = page.copyWith(body: '\n# Northwind\n\nEdited body.\n');
      await ds.write(edited, vaultRoot: fs.directory('/vault'));
      final reread = fs.file('/vault/Northwind.md').readAsStringSync();
      // YAML block is unchanged because it came from rawYaml.
      expect(reread.startsWith(_northwindMd.split('---\n')[1]), false);
      expect(reread, startsWith('---\nid: 01HX0V9R5N6E8L3P7Q8S9U2X4B'));
      expect(reread, contains('Edited body.'));
    });

    test('atomic write: never leaves a partial file on failure', () async {
      fs.file('/vault/page.md').writeAsStringSync(_northwindMd);
      final page = await ds.readOne(
        fs.file('/vault/page.md'),
        vaultRoot: fs.directory('/vault'),
      );
      await ds.write(page, vaultRoot: fs.directory('/vault'));
      // No tmp files left behind.
      final entries = fs.directory('/vault').listSync().map((e) => e.basename).toList();
      expect(entries, equals(['page.md']));
    });
  });
}
