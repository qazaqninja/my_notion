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

  test('includes attachments/<file> so embedded media survives (M718)',
      () async {
    File(p.join(src.path, 'page.md'))
        .writeAsStringSync('![cover](attachments/01HX.png)\n');
    Directory(p.join(src.path, 'attachments')).createSync(recursive: true);
    File(p.join(src.path, 'attachments', '01HX.png'))
        .writeAsStringSync('PNG-bytes');
    File(p.join(src.path, 'attachments', '01HY.pdf'))
        .writeAsStringSync('PDF-bytes');
    // Stray top-level non-md file outside attachments/ should still
    // be skipped — only attachments/ binaries get carried over.
    File(p.join(src.path, 'scratch.png')).writeAsStringSync('x');

    final n = await const VaultExporter().export(src: src, dest: dest);
    expect(n, 3, reason: 'page + 2 attachments');
    expect(
        File(p.join(dest.path, 'attachments', '01HX.png')).existsSync(),
        isTrue);
    expect(
        File(p.join(dest.path, 'attachments', '01HY.pdf')).existsSync(),
        isTrue);
    expect(File(p.join(dest.path, 'scratch.png')).existsSync(), isFalse);
  });

  test('nested attachments/ folders also carry their files (M789)',
      () async {
    // A per-folder `Customers/attachments/logo.png` is a common
    // pattern: keep media co-located with the pages it embeds.
    // The old `segments.first == 'attachments'` check only kept
    // the top-level folder and silently dropped per-folder media.
    Directory(p.join(src.path, 'Customers')).createSync();
    File(p.join(src.path, 'Customers', 'page.md'))
        .writeAsStringSync('![logo](attachments/logo.png)\n');
    Directory(p.join(src.path, 'Customers', 'attachments'))
        .createSync(recursive: true);
    File(p.join(src.path, 'Customers', 'attachments', 'logo.png'))
        .writeAsStringSync('PNG-bytes');

    final n = await const VaultExporter().export(src: src, dest: dest);
    expect(n, 2,
        reason: 'page + nested attachment file should both export');
    expect(
        File(p.join(dest.path, 'Customers', 'attachments', 'logo.png'))
            .existsSync(),
        isTrue);
  });

  test('skips .trash/ contents (M718)', () async {
    File(p.join(src.path, 'live.md')).writeAsStringSync('live');
    Directory(p.join(src.path, '.trash', '2026-05')).createSync(recursive: true);
    File(p.join(src.path, '.trash', '2026-05', 'old.md'))
        .writeAsStringSync('old');

    final n = await const VaultExporter().export(src: src, dest: dest);
    expect(n, 1, reason: 'only the live page exports');
    expect(File(p.join(dest.path, 'live.md')).existsSync(), isTrue);
    expect(
        Directory(p.join(dest.path, '.trash')).existsSync(), isFalse);
  });
}
