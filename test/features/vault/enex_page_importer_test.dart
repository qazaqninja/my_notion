import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/vault/data/enex_page_importer.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory vault;
  late Directory inputs;
  setUp(() async {
    vault = await Directory.systemTemp.createTemp('quill_enex_import_');
    inputs = await Directory.systemTemp.createTemp('quill_enex_input_');
  });
  tearDown(() async {
    try {
      await vault.delete(recursive: true);
    } catch (_) {}
    try {
      await inputs.delete(recursive: true);
    } catch (_) {}
  });

  test('imports notes with tags + dates + xhtml body', () async {
    final src = File(p.join(inputs.path, 'notebook.enex'));
    await src.writeAsString('''<?xml version="1.0" encoding="UTF-8"?>
<en-export>
<note>
  <title>First Note</title>
  <created>20250607T123456Z</created>
  <updated>20250608T100000Z</updated>
  <tag>research</tag>
  <tag>archive</tag>
  <content><![CDATA[<?xml version="1.0"?><en-note><h1>Hello</h1><p>Body <strong>bold</strong>.</p></en-note>]]></content>
</note>
<note>
  <title>Second</title>
  <content><![CDATA[<en-note><p>quick</p></en-note>]]></content>
</note>
</en-export>
''');
    final summary = await EnexPageImporter.importTo(src, vault);
    expect(summary.notes.length, 2);
    final f = await File(p.join(vault.path, 'Evernote/First Note.md'))
        .readAsString();
    expect(f, contains('title: First Note'));
    expect(f, contains('tags: [research, archive]'));
    expect(f, contains('created_at: 2025-06-07'));
    expect(f, contains('updated: 2025-06-08'));
    expect(f, contains('imported_from: notebook.enex'));
    expect(f, contains('# Hello'));
    expect(f, contains('**bold**'));
    // Second note: minimal frontmatter (no tags, no dates), preserved body.
    final s = await File(p.join(vault.path, 'Evernote/Second.md'))
        .readAsString();
    expect(s, contains('title: Second'));
    expect(s, isNot(contains('tags:')));
    expect(s, isNot(contains('created_at:')));
    expect(s, contains('quick'));
  });

  test('duplicate titles get a suffix', () async {
    final src = File(p.join(inputs.path, 'dup.enex'));
    await src.writeAsString('''<en-export>
<note><title>Same</title><content><![CDATA[<en-note>a</en-note>]]></content></note>
<note><title>Same</title><content><![CDATA[<en-note>b</en-note>]]></content></note>
</en-export>
''');
    final summary = await EnexPageImporter.importTo(src, vault);
    expect(summary.notes.length, 2);
    final names = summary.notes.map((n) => p.basename(n.relativePath));
    expect(names, equals(['Same.md', 'Same (2).md']));
  });

  test('targetFolder override', () async {
    final src = File(p.join(inputs.path, 'small.enex'));
    await src.writeAsString(
        '<en-export><note><title>X</title><content><![CDATA[<en-note>y</en-note>]]></content></note></en-export>');
    final summary = await EnexPageImporter.importTo(src, vault,
        targetFolder: 'Imports');
    expect(summary.folder, 'Imports');
    expect(summary.notes.single.relativePath, 'Imports/X.md');
  });

  test('missing en-note wrapper still imports the content', () async {
    final src = File(p.join(inputs.path, 'bare.enex'));
    await src.writeAsString('''<en-export>
<note>
  <title>Bare</title>
  <content><![CDATA[<p>just plain xhtml</p>]]></content>
</note>
</en-export>
''');
    await EnexPageImporter.importTo(src, vault);
    final body = await File(p.join(vault.path, 'Evernote/Bare.md'))
        .readAsString();
    expect(body, contains('just plain xhtml'));
  });
}
