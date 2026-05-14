import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/database/data/datasources/database_yaml_parser.dart';
import 'package:my_notion/features/database/domain/entities/database_schema.dart';

void main() {
  group('person column type', () {
    test('parses type: person', () {
      final s = DatabaseYamlParser.parse(
        '''
id: db
name: T
schema:
  owner: {type: person}
''',
        folderPath: 'x',
      )!;
      expect(s.columns.first.type, equals(ColumnType.person));
    });

    test('aliases: user / owner / assignee / created_by / last_edited_by',
        () {
      for (final alias in [
        'user',
        'owner',
        'assignee',
        'created_by',
        'last_edited_by',
      ]) {
        final s = DatabaseYamlParser.parse(
          '''
id: db
name: T
schema:
  who: {type: $alias}
''',
          folderPath: 'x',
        )!;
        expect(s.columns.first.type, equals(ColumnType.person),
            reason: 'alias "$alias" should map to ColumnType.person');
      }
    });

    test('unknown type still falls back to text', () {
      final s = DatabaseYamlParser.parse(
        '''
id: db
name: T
schema:
  garbage: {type: zzz}
''',
        folderPath: 'x',
      )!;
      expect(s.columns.first.type, equals(ColumnType.text));
    });
  });
}
