import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/vault/data/text_page_importer.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory vault;
  late Directory inputs;
  setUp(() async {
    vault = await Directory.systemTemp.createTemp('quill_text_import_');
    inputs = await Directory.systemTemp.createTemp('quill_text_input_');
  });
  tearDown(() async {
    try {
      await vault.delete(recursive: true);
    } catch (_) {}
    try {
      await inputs.delete(recursive: true);
    } catch (_) {}
  });

  test('plain .txt → page with generated frontmatter', () async {
    final src = File(p.join(inputs.path, 'notes.txt'));
    await src.writeAsString('Hello, world!\nLine two.\n');
    final summary = await TextPageImporter.importTo(src, vault);
    expect(summary.title, 'notes');
    expect(summary.relativePath, 'Inbox/notes.md');
    expect(summary.ulid.length, 26);
    final out =
        await File(p.join(vault.path, summary.relativePath)).readAsString();
    expect(out, contains('id: ${summary.ulid}'));
    expect(out, contains('title: notes'));
    expect(out, contains('imported_from: notes.txt'));
    expect(out, contains('Hello, world!'));
    expect(out, contains('Line two.'));
  });

  test('.md with existing id keeps the id', () async {
    final src = File(p.join(inputs.path, 'sample.md'));
    const existingUlid = '01HQ0V9R5N6E8L3P7Q8S9U2X4B';
    await src.writeAsString('''---
id: $existingUlid
title: My Page
---

Body content.
''');
    final summary = await TextPageImporter.importTo(src, vault);
    expect(summary.ulid, existingUlid);
    expect(summary.title, 'My Page');
    final out =
        await File(p.join(vault.path, summary.relativePath)).readAsString();
    expect(out, contains('id: $existingUlid'));
    expect(out, contains('title: My Page'));
    expect(out, contains('imported_from: sample.md'));
    expect(out, contains('Body content.'));
  });

  test('.md without id generates a fresh one', () async {
    final src = File(p.join(inputs.path, 'no_id.md'));
    await src.writeAsString('''---
title: ad-hoc
---

stuff
''');
    final summary = await TextPageImporter.importTo(src, vault);
    expect(summary.ulid.length, 26);
    final out =
        await File(p.join(vault.path, summary.relativePath)).readAsString();
    expect(out, contains('id: ${summary.ulid}'));
    expect(out, contains('title: ad-hoc'));
    expect(out, contains('imported_from: no_id.md'));
  });

  test('.markdown extension is also recognised as markdown', () async {
    final src = File(p.join(inputs.path, 'doc.markdown'));
    await src.writeAsString('# Hi\n\nbody');
    final summary = await TextPageImporter.importTo(src, vault);
    expect(summary.title, 'doc');
    final out =
        await File(p.join(vault.path, summary.relativePath)).readAsString();
    // body preserved verbatim
    expect(out, contains('# Hi'));
    expect(out, contains('body'));
  });

  test('targetFolder override lands the page elsewhere', () async {
    final src = File(p.join(inputs.path, 'a.txt'));
    await src.writeAsString('hello');
    final summary = await TextPageImporter.importTo(src, vault,
        targetFolder: 'Imports');
    expect(summary.relativePath, 'Imports/a.md');
    expect(
      await File(p.join(vault.path, 'Imports/a.md')).exists(),
      isTrue,
    );
  });
}
