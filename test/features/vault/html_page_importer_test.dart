import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/vault/data/html_page_importer.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory vault;
  late Directory inputs;
  setUp(() async {
    vault = await Directory.systemTemp.createTemp('quill_html_import_');
    inputs = await Directory.systemTemp.createTemp('quill_html_input_');
  });
  tearDown(() async {
    try {
      await vault.delete(recursive: true);
    } catch (_) {}
    try {
      await inputs.delete(recursive: true);
    } catch (_) {}
  });

  test('imports an HTML page with explicit <title>', () async {
    final src = File(p.join(inputs.path, 'page.html'));
    await src.writeAsString('''
<html>
<head><title>My Imported Page</title></head>
<body>
<h1>Hello</h1>
<p>this is a paragraph with <strong>emphasis</strong>.</p>
<ul><li>one</li><li>two</li></ul>
</body>
</html>
''');
    final summary = await HtmlPageImporter.importTo(src, vault);
    expect(summary.title, equals('My Imported Page'));
    expect(summary.relativePath, equals('Inbox/My Imported Page.md'));
    expect(summary.ulid.length, 26);
    final out = await File(p.join(vault.path, summary.relativePath))
        .readAsString();
    expect(out, contains('id: ${summary.ulid}'));
    expect(out, contains('title: My Imported Page'));
    expect(out, contains('imported_from: page.html'));
    expect(out, contains('# Hello'));
    expect(out, contains('**emphasis**'));
    expect(out, contains('- one'));
    expect(out, contains('- two'));
  });

  test('falls back to filename when title tag is missing', () async {
    final src = File(p.join(inputs.path, 'untitled.html'));
    await src.writeAsString('<html><body><p>body</p></body></html>');
    final summary = await HtmlPageImporter.importTo(src, vault);
    expect(summary.title, equals('untitled'));
    expect(summary.relativePath, equals('Inbox/untitled.md'));
  });

  test('sanitizes title for filesystem-unsafe characters', () async {
    final src = File(p.join(inputs.path, 'whatever.html'));
    await src.writeAsString(
        '<html><head><title>A / B : C</title></head><body><p>x</p></body></html>');
    final summary = await HtmlPageImporter.importTo(src, vault);
    expect(summary.title, equals('A / B : C')); // title preserved
    // filename has illegal chars replaced
    expect(summary.relativePath, equals('Inbox/A - B - C.md'));
  });

  test('targetFolder override lands the page elsewhere', () async {
    final src = File(p.join(inputs.path, 'a.html'));
    await src.writeAsString(
        '<html><head><title>X</title></head><body><p>x</p></body></html>');
    final summary =
        await HtmlPageImporter.importTo(src, vault, targetFolder: 'Imports');
    expect(summary.relativePath, equals('Imports/X.md'));
    expect(
      await File(p.join(vault.path, 'Imports/X.md')).exists(),
      isTrue,
    );
  });
}
