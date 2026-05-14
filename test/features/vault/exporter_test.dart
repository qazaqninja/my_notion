import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/vault/data/exporter.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tmp;
  late Directory src;
  late Directory dest;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('quill_exporter_test_');
    src = Directory(p.join(tmp.path, 'src'))..createSync();
    dest = Directory(p.join(tmp.path, 'dest'));
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  test('copies every .md and .database.yaml preserving paths', () async {
    File(p.join(src.path, 'Inbox.md')).writeAsStringSync('# Inbox\n');
    Directory(p.join(src.path, 'Customers')).createSync();
    File(p.join(src.path, 'Customers', '.database.yaml')).writeAsStringSync('id: 01H\n');
    File(p.join(src.path, 'Customers', 'Acme.md')).writeAsStringSync('# Acme\n');
    File(p.join(src.path, 'image.png')).writeAsStringSync('binary');

    final n = await const VaultExporter().export(src: src, dest: dest);
    expect(n, 3);
    expect(File(p.join(dest.path, 'Inbox.md')).existsSync(), isTrue);
    expect(File(p.join(dest.path, 'Customers', '.database.yaml')).existsSync(), isTrue);
    expect(File(p.join(dest.path, 'Customers', 'Acme.md')).existsSync(), isTrue);
    expect(File(p.join(dest.path, 'image.png')).existsSync(), isFalse);
  });

  test('skips .git and node_modules', () async {
    File(p.join(src.path, 'a.md')).writeAsStringSync('a');
    Directory(p.join(src.path, '.git', 'refs')).createSync(recursive: true);
    File(p.join(src.path, '.git', 'refs', 'b.md')).writeAsStringSync('b');
    Directory(p.join(src.path, 'node_modules', 'pkg')).createSync(recursive: true);
    File(p.join(src.path, 'node_modules', 'pkg', 'c.md')).writeAsStringSync('c');

    final n = await const VaultExporter().export(src: src, dest: dest);
    expect(n, 1);
  });

  test('byte-identical copy', () async {
    const original = '---\nid: 01HX\ntitle: T\n---\n\n# Body\n';
    File(p.join(src.path, 'x.md')).writeAsStringSync(original);
    await const VaultExporter().export(src: src, dest: dest);
    expect(File(p.join(dest.path, 'x.md')).readAsStringSync(), original);
  });
}
