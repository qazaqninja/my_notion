import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/vault/data/trello_database_importer.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory vault;
  late Directory inputs;
  setUp(() async {
    vault = await Directory.systemTemp.createTemp('quill_trello_import_');
    inputs = await Directory.systemTemp.createTemp('quill_trello_input_');
  });
  tearDown(() async {
    try {
      await vault.delete(recursive: true);
    } catch (_) {}
    try {
      await inputs.delete(recursive: true);
    } catch (_) {}
  });

  test('writes .database.yaml + one .md per open card', () async {
    final src = File(p.join(inputs.path, 'board.json'));
    await src.writeAsString('''{
  "name": "Sprint",
  "lists": [
    {"id":"L1","name":"To Do","closed":false},
    {"id":"L2","name":"Doing","closed":false}
  ],
  "cards":[
    {"name":"first card","desc":"hello","idList":"L1","labels":[],"closed":false,"due":"2026-06-01T00:00:00.000Z"},
    {"name":"second card","desc":"world","idList":"L2","labels":[{"name":"urgent"}],"closed":false}
  ]
}''');
    final summary = await TrelloDatabaseImporter.importTo(src, vault);
    expect(summary.folder, 'Trello — Sprint');
    expect(summary.cards.length, 2);
    final schema = await File(
            p.join(vault.path, 'Trello — Sprint', '.database.yaml'))
        .readAsString();
    expect(schema, contains('name: Sprint'));
    expect(schema, contains('type: select'));
    expect(schema, contains('To Do'));
    expect(schema, contains('Doing'));
    expect(schema, contains('group_by: status'));
    final first = await File(
            p.join(vault.path, 'Trello — Sprint', 'first card.md'))
        .readAsString();
    expect(first, contains('title: first card'));
    expect(first, contains('status: To Do'));
    expect(first, contains('due: 2026-06-01'));
    expect(first, contains('imported_from: board.json'));
    expect(first, contains('hello'));
    final second = await File(
            p.join(vault.path, 'Trello — Sprint', 'second card.md'))
        .readAsString();
    expect(second, contains('labels: [urgent]'));
  });

  test('non-board JSON → FormatException', () async {
    final src = File(p.join(inputs.path, 'x.json'));
    await src.writeAsString('"not a board"');
    await expectLater(
      () => TrelloDatabaseImporter.importTo(src, vault),
      throwsA(isA<FormatException>()),
    );
  });
}
