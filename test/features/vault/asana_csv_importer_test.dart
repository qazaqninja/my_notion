import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/vault/data/asana_csv_importer.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory vault;
  late Directory inputs;
  setUp(() async {
    vault = await Directory.systemTemp.createTemp('quill_asana_import_');
    inputs = await Directory.systemTemp.createTemp('quill_asana_input_');
  });
  tearDown(() async {
    try {
      await vault.delete(recursive: true);
    } catch (_) {}
    try {
      await inputs.delete(recursive: true);
    } catch (_) {}
  });

  test('recognises Asana column conventions', () async {
    final src = File(p.join(inputs.path, 'asana export.csv'));
    await src.writeAsString('''Name,Section/Column,Tags,Due Date,Notes
"task one","To Do","urgent, backend",2026-06-01,"first task notes"
"task two","Doing","",2026-06-08,"second task notes"
"task three","Done","frontend",,
''');
    final summary = await AsanaCsvImporter.importTo(src, vault);
    expect(summary.tasks.length, 3);
    final schema = await File(
            p.join(vault.path, summary.folder, '.database.yaml'))
        .readAsString();
    // Title column is always 'title'; Section/Column becomes 'status'
    // (a select with the discovered options); Tags is a multi.
    expect(schema, contains('  title:'));
    expect(schema, contains('  status:'));
    expect(schema, contains('    type: select'));
    expect(schema, contains('To Do'));
    expect(schema, contains('Doing'));
    expect(schema, contains('Done'));
    expect(schema, contains('  tags:'));
    expect(schema, contains('    type: multi'));
    expect(schema, contains('  due_date:'));
    expect(schema, contains('    type: date'));
    expect(schema, contains('group_by: status'));
    // First task body should be the notes.
    final t1 = await File(
            p.join(vault.path, summary.folder, 'task one.md'))
        .readAsString();
    expect(t1, contains('title: task one'));
    expect(t1, contains('status: To Do'));
    expect(t1, contains('tags: [urgent, backend]'));
    expect(t1, contains('due_date: 2026-06-01'));
    expect(t1, contains('first task notes'));
  });

  test('falls back to text for unknown columns', () async {
    final src = File(p.join(inputs.path, 'export.csv'));
    await src.writeAsString('''Name,Custom Field
"task","whatever"
''');
    final summary = await AsanaCsvImporter.importTo(src, vault);
    final schema = await File(
            p.join(vault.path, summary.folder, '.database.yaml'))
        .readAsString();
    expect(schema, contains('  custom_field:'));
    expect(schema, contains('    type: text'));
  });

  test('drops rows whose Name is empty', () async {
    final src = File(p.join(inputs.path, 'mixed.csv'));
    await src.writeAsString('''Name,Notes
"keep","content"
"","stray"
''');
    final summary = await AsanaCsvImporter.importTo(src, vault);
    expect(summary.tasks.length, 1);
    expect(summary.tasks.single.title, 'keep');
  });
}
