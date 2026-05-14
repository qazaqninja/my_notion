import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/database/data/datasources/csv_exporter.dart';
import 'package:my_notion/features/database/domain/entities/database_schema.dart';
import 'package:my_notion/features/database/domain/repositories/database_repository.dart';
import 'package:path/path.dart' as p;

void main() {
  final schema = DatabaseSchema(
    id: 'db',
    name: 'Customers',
    icon: '🏢',
    color: '#000',
    folderPath: 'Customers',
    columns: const [
      ColumnDef(key: 'id', type: ColumnType.text), // excluded
      ColumnDef(key: 'title', type: ColumnType.text),
      ColumnDef(key: 'arr', type: ColumnType.number),
      ColumnDef(key: 'note', type: ColumnType.text),
    ],
    views: const [],
  );

  test('exports rows with title-first header', () async {
    final tmp = await Directory.systemTemp.createTemp('quill_csv_exp_');
    final dest = File(p.join(tmp.path, 'out.csv'));
    final rows = [
      DatabasePageRow(
        ulid: 'a',
        title: 'Northwind',
        relativePath: 'n.md',
        cells: const {'arr': '420000', 'note': 'hi'},
      ),
      DatabasePageRow(
        ulid: 'b',
        title: 'Foo, Inc',
        relativePath: 'f.md',
        cells: const {'arr': '5', 'note': 'has "quote"'},
      ),
    ];

    final n = await const CsvExporter().export(
      destination: dest,
      schema: schema,
      rows: rows,
    );
    expect(n, 2);
    final raw = await dest.readAsString();
    expect(raw, startsWith('title,arr,note\n'));
    expect(raw, contains('Northwind,420000,hi'));
    // Comma → quoted, doubled-quote inside escaped.
    expect(raw, contains('"Foo, Inc",5,"has ""quote"""'));

    await tmp.delete(recursive: true);
  });

  test('handles empty rows', () async {
    final tmp = await Directory.systemTemp.createTemp('quill_csv_exp_empty_');
    final dest = File(p.join(tmp.path, 'out.csv'));
    final n = await const CsvExporter().export(
      destination: dest,
      schema: schema,
      rows: const [],
    );
    expect(n, 0);
    expect(await dest.readAsString(), 'title,arr,note\n');
    await tmp.delete(recursive: true);
  });
}
