import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/core/markdown/frontmatter_parser.dart';
import 'package:my_notion/core/ulid/ulid_generator.dart';
import 'package:my_notion/features/database/data/datasources/csv_importer.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('quill_csv_test_');
  });

  tearDown(() async {
    try {
      await tmp.delete(recursive: true);
    } catch (_) {}
  });

  test('imports a basic CSV with type inference', () async {
    final csv = File(p.join(tmp.path, 'pets.csv'));
    await csv.writeAsString(
      'title,age,active,joined\n'
      'Whiskers,3,true,2024-01-15\n'
      'Mittens,7,false,2023-08-22\n',
    );

    final result = await const CsvImporter(ulids: UlidGenerator()).importTo(
      csv,
      tmp,
    );

    expect(result.rowsWritten, 2);
    expect(result.columns, 4);

    final dbYaml = await File(p.join(result.folderPath, '.database.yaml'))
        .readAsString();
    expect(dbYaml, contains('title:'));
    expect(dbYaml, contains('age:\n    type: number'));
    expect(dbYaml, contains('active:\n    type: checkbox'));
    expect(dbYaml, contains('joined:\n    type: date'));

    final whiskers =
        await File(p.join(result.folderPath, 'Whiskers.md')).readAsString();
    final parsed = FrontmatterParser.parse(whiskers);
    expect(parsed.frontmatter.title, equals('Whiskers'));
    expect(parsed.frontmatter.get('age'), equals(3));
    expect(parsed.frontmatter.get('active'), isTrue);
    expect(parsed.frontmatter.get('joined'), equals('2024-01-15'));
  });

  test('handles quoted commas and doubled quotes', () async {
    final csv = File(p.join(tmp.path, 'q.csv'));
    await csv.writeAsString(
      'title,note\n'
      '"Foo, bar","She said ""hi"""\n',
    );
    final r = await const CsvImporter().importTo(csv, tmp);
    expect(r.rowsWritten, 1);
    final md = await Directory(r.folderPath).list().toList();
    final filePath = md
        .whereType<File>()
        .firstWhere((f) => p.basename(f.path).startsWith('Foo'));
    final parsed = FrontmatterParser.parse(await filePath.readAsString());
    expect(parsed.frontmatter.title, equals('Foo, bar'));
    expect(parsed.frontmatter.get('note'), equals('She said "hi"'));
  });

  test('picks "name" column as title when "title" is absent', () async {
    final csv = File(p.join(tmp.path, 'n.csv'));
    await csv.writeAsString('name,arr\nAcmeco,420000\n');
    final r = await const CsvImporter().importTo(csv, tmp);
    expect(r.rowsWritten, 1);
    expect(await File(p.join(r.folderPath, 'Acmeco.md')).exists(), isTrue);
  });

  test('skips wholly-empty rows', () async {
    final csv = File(p.join(tmp.path, 'e.csv'));
    await csv.writeAsString('title\nFoo\n\n\nBar\n');
    final r = await const CsvImporter().importTo(csv, tmp);
    expect(r.rowsWritten, 2);
  });

  test('throws on CSV with no data rows', () async {
    final csv = File(p.join(tmp.path, 'h.csv'));
    await csv.writeAsString('title,age\n');
    expect(
      () => const CsvImporter().importTo(csv, tmp),
      throwsA(isA<FormatException>()),
    );
  });

  test('normalises column keys to snake_case + drops YAML-unsafe chars '
      '(M759)', () async {
    final csv = File(p.join(tmp.path, 'oddcols.csv'));
    // Headers with spaces, colons, hashes, slashes, brackets — used
    // to land in FrontmatterEntry.key verbatim and corrupt the YAML
    // mapping on serialise.
    await csv.writeAsString(
      'title,Foo: Bar,#Priority,Tag/Stage,Cool [v2]\n'
      'Row,1,P1,beta,ok\n',
    );

    final result = await const CsvImporter(ulids: UlidGenerator()).importTo(
      csv,
      tmp,
    );
    expect(result.rowsWritten, 1);

    final raw =
        await File(p.join(result.folderPath, 'Row.md')).readAsString();
    final parsed = FrontmatterParser.parse(raw);
    // Every key now snake_case, no unsafe glyphs remain.
    expect(parsed.frontmatter.get('foo_bar'), equals(1),
        reason: 'colon stripped, spaces snake-cased');
    expect(parsed.frontmatter.get('priority'), equals('P1'),
        reason: 'leading # stripped');
    expect(parsed.frontmatter.get('tag_stage'), equals('beta'),
        reason: 'slash replaced');
    expect(parsed.frontmatter.get('cool_v2'), equals('ok'),
        reason: 'brackets stripped');
  });
}
