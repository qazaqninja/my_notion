import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/vault/data/roam_page_importer.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory vault;
  late Directory inputs;
  setUp(() async {
    vault = await Directory.systemTemp.createTemp('quill_roam_import_');
    inputs = await Directory.systemTemp.createTemp('quill_roam_input_');
  });
  tearDown(() async {
    try {
      await vault.delete(recursive: true);
    } catch (_) {}
    try {
      await inputs.delete(recursive: true);
    } catch (_) {}
  });

  test('imports multiple pages with frontmatter + body', () async {
    final src = File(p.join(inputs.path, 'roam.json'));
    await src.writeAsString('''[
  {"title": "Alpha", "create-time": 1700000000000, "children": [
    {"string": "alpha note"}
  ]},
  {"title": "Beta", "children": [
    {"string": "beta", "children": [{"string":"deep"}]}
  ]}
]''');
    final summary = await RoamPageImporter.importTo(src, vault);
    expect(summary.pages, hasLength(2));
    expect(summary.folder, 'Roam');
    // Alpha
    final alpha = await File(p.join(vault.path, 'Roam/Alpha.md'))
        .readAsString();
    expect(alpha, contains('id: ${summary.pages[0].ulid}'));
    expect(alpha, contains('title: Alpha'));
    expect(alpha, contains('imported_from: roam.json'));
    expect(alpha, contains('created_at: 2023-11-14'));
    expect(alpha, contains('# Alpha'));
    expect(alpha, contains('- alpha note'));
    // Beta
    final beta = await File(p.join(vault.path, 'Roam/Beta.md'))
        .readAsString();
    expect(beta, contains('# Beta'));
    expect(beta, contains('- beta'));
    expect(beta, contains('  - deep'));
    expect(beta, isNot(contains('created_at:')));
  });

  test('targetFolder override lands pages elsewhere', () async {
    final src = File(p.join(inputs.path, 'in.json'));
    await src.writeAsString('[{"title":"X","children":[]}]');
    final summary = await RoamPageImporter.importTo(src, vault,
        targetFolder: 'Imports');
    expect(summary.folder, 'Imports');
    expect(summary.pages.single.relativePath, 'Imports/X.md');
  });

  test('empty JSON list → zero pages, no folder leftover', () async {
    final src = File(p.join(inputs.path, 'empty.json'));
    await src.writeAsString('[]');
    final summary = await RoamPageImporter.importTo(src, vault);
    expect(summary.pages, isEmpty);
  });
}
