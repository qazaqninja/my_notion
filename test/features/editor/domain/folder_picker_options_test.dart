import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/editor/domain/folder_picker_options.dart';
import 'package:my_notion/features/vault/domain/entities/vault_tree.dart';

VaultFile _file(String name, String relPath) => VaultFile(
      name: name,
      relativePath: relPath,
      ulid: '01HX${relPath.hashCode.toRadixString(16).padLeft(8, '0')}',
    );

VaultFolder _folder(
  String name,
  String relPath, {
  List<VaultNode> children = const [],
}) =>
    VaultFolder(name: name, relativePath: relPath, children: children);

void main() {
  group('currentFolderOf', () {
    test('top-level file lives in the vault root (empty string)', () {
      expect(currentFolderOf('Welcome.md'), '');
    });

    test('single-folder file returns the parent folder name', () {
      expect(currentFolderOf('Inbox/today.md'), 'Inbox');
    });

    test('nested file returns the full parent path', () {
      expect(currentFolderOf('Projects/2026/q1.md'), 'Projects/2026');
    });

    test('empty input returns empty (no slashes)', () {
      // Defensive: never throw if upstream hands us an empty
      // relativePath.
      expect(currentFolderOf(''), '');
    });
  });

  group('collectVaultFolders', () {
    test('empty tree returns an empty list', () {
      expect(collectVaultFolders(VaultTree.empty), <String>[]);
    });

    test('top-level folders are listed in alphabetical order', () {
      final tree = VaultTree(topLevel: [
        _folder('Zebra', 'Zebra'),
        _folder('Apple', 'Apple'),
        _file('top.md', 'top.md'),
        _folder('Mango', 'Mango'),
      ]);
      expect(collectVaultFolders(tree), ['Apple', 'Mango', 'Zebra']);
    });

    test('nested folders are walked and listed by full path', () {
      // Three-deep nesting; the helper should emit every folder it
      // visits, not just the leaves.
      final tree = VaultTree(topLevel: [
        _folder('Projects', 'Projects', children: [
          _folder('2026', 'Projects/2026', children: [
            _folder('q1', 'Projects/2026/q1', children: [
              _file('roadmap.md', 'Projects/2026/q1/roadmap.md'),
            ]),
          ]),
        ]),
      ]);
      expect(collectVaultFolders(tree), [
        'Projects',
        'Projects/2026',
        'Projects/2026/q1',
      ]);
    });

    test('files at every level are skipped', () {
      final tree = VaultTree(topLevel: [
        _file('readme.md', 'readme.md'),
        _folder('Inbox', 'Inbox', children: [
          _file('today.md', 'Inbox/today.md'),
        ]),
      ]);
      expect(collectVaultFolders(tree), ['Inbox']);
    });

    test('duplicate folder relativePaths collapse to one entry', () {
      // Belt + braces: if the tree ever emits the same path twice
      // (e.g. drift fixture quirk) we still hand a unique list to the
      // chooser.
      final tree = VaultTree(topLevel: [
        _folder('A', 'A'),
        _folder('A', 'A'),
      ]);
      expect(collectVaultFolders(tree), ['A']);
    });

    test('result is alphabetically sorted across nesting levels', () {
      final tree = VaultTree(topLevel: [
        _folder('Zebra', 'Zebra', children: [
          _folder('Aardvark', 'Zebra/Aardvark'),
        ]),
        _folder('Apple', 'Apple'),
      ]);
      expect(collectVaultFolders(tree), [
        'Apple',
        'Zebra',
        'Zebra/Aardvark',
      ]);
    });
  });
}
