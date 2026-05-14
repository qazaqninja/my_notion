import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/vault/data/opml_page_importer.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory vault;
  late Directory inputs;
  setUp(() async {
    vault = await Directory.systemTemp.createTemp('quill_opml_import_');
    inputs = await Directory.systemTemp.createTemp('quill_opml_input_');
  });
  tearDown(() async {
    try {
      await vault.delete(recursive: true);
    } catch (_) {}
    try {
      await inputs.delete(recursive: true);
    } catch (_) {}
  });

  test('imports a Workflowy-shaped OPML outline', () async {
    final src = File(p.join(inputs.path, 'plan.opml'));
    await src.writeAsString('''
<opml version="2.0">
<head><title>My Plan</title></head>
<body>
  <outline text="Q1">
    <outline text="onboarding">
      <outline text="readme"/>
    </outline>
  </outline>
  <outline text="Q2"/>
</body>
</opml>
''');
    final summary = await OpmlPageImporter.importTo(src, vault);
    expect(summary.title, 'My Plan');
    expect(summary.relativePath, 'Inbox/My Plan.md');
    expect(summary.ulid.length, 26);
    final out = await File(p.join(vault.path, summary.relativePath))
        .readAsString();
    expect(out, contains('id: ${summary.ulid}'));
    expect(out, contains('title: My Plan'));
    expect(out, contains('imported_from: plan.opml'));
    expect(out, contains('- Q1'));
    expect(out, contains('  - onboarding'));
    expect(out, contains('    - readme'));
    expect(out, contains('- Q2'));
  });

  test('falls back to filename when title is missing', () async {
    final src = File(p.join(inputs.path, 'notes.opml'));
    await src.writeAsString(
        '<opml><body><outline text="x"/></body></opml>');
    final summary = await OpmlPageImporter.importTo(src, vault);
    expect(summary.title, 'notes');
    expect(summary.relativePath, 'Inbox/notes.md');
  });

  test('targetFolder override lands the page elsewhere', () async {
    final src = File(p.join(inputs.path, 'a.opml'));
    await src.writeAsString(
        '<opml><head><title>X</title></head><body><outline text="y"/></body></opml>');
    final summary = await OpmlPageImporter.importTo(src, vault,
        targetFolder: 'Imports');
    expect(summary.relativePath, 'Imports/X.md');
  });
}
