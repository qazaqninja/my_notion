import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/database/data/datasources/database_yaml_parser.dart';
import 'package:my_notion/features/database/domain/entities/database_schema.dart';

void main() {
  group('DatabaseYamlParser', () {
    test('parses basic schema + views', () {
      final s = DatabaseYamlParser.parse(
        '''
id: 01HX0V9R5N6E8L3P7Q8S9U2X4B
name: Customers
icon: 🏢
color: "#6B8E7F"
schema:
  arr:
    type: number
  stage:
    type: select
    options: [pilot, won, churn]
views:
  - id: main
    type: table
''',
        folderPath: 'Customers',
      );
      expect(s, isNotNull);
      expect(s!.name, equals('Customers'));
      expect(s.columns, hasLength(2));
      expect(s.columns[1].options, equals(['pilot', 'won', 'churn']));
      expect(s.views.first.type, equals(ViewType.table));
    });

    test('reads is_parent flag on relation columns', () {
      final s = DatabaseYamlParser.parse(
        '''
id: db
name: Tasks
schema:
  parent:
    type: relation
    is_parent: true
    target_database: db
''',
        folderPath: 'Tasks',
      );
      expect(s!.columns.first.isParent, isTrue);
      expect(s.columns.first.targetDatabase, equals('db'));
    });

    test('reads views[].visible list', () {
      final s = DatabaseYamlParser.parse(
        '''
id: db
name: T
views:
  - id: focus
    type: table
    visible: [title, owner]
''',
        folderPath: 'T',
      );
      expect(s!.views.first.visible, equals(['title', 'owner']));
    });

    test('reads new column type aliases', () {
      final s = DatabaseYamlParser.parse(
        '''
id: db
name: T
schema:
  created:
    type: created_time
  modified:
    type: last_edited_time
  done:
    type: checkbox
  v:
    type: formula
    formula: 'arr * 12'
''',
        folderPath: 'T',
      );
      expect(s!.columns[0].type, equals(ColumnType.createdTime));
      expect(s.columns[1].type, equals(ColumnType.lastEditedTime));
      expect(s.columns[2].type, equals(ColumnType.checkbox));
      expect(s.columns[3].formula, equals('arr * 12'));
    });

    test('garbage YAML → null', () {
      expect(
        DatabaseYamlParser.parse('not a map', folderPath: 'x'),
        isNull,
      );
    });

    test('reads inverse_of on relation columns', () {
      final s = DatabaseYamlParser.parse(
        '''
id: db
name: T
schema:
  customer:
    type: relation
    inverse_of: deals
''',
        folderPath: 'x',
      )!;
      expect(s.columns.first.inverseOf, equals('deals'));
    });

    test('inverse_of is null when absent', () {
      final s = DatabaseYamlParser.parse(
        '''
id: db
name: T
schema:
  customer: {type: relation}
''',
        folderPath: 'x',
      )!;
      expect(s.columns.first.inverseOf, isNull);
    });

    test('reads locked: true', () {
      final s = DatabaseYamlParser.parse(
        '''
id: db
name: Locked
locked: true
schema:
  title:
    type: text
''',
        folderPath: 'x',
      )!;
      expect(s.locked, isTrue);
    });

    test('locked defaults to false when absent', () {
      final s = DatabaseYamlParser.parse(
        '''
id: db
name: Open
schema:
  title:
    type: text
''',
        folderPath: 'x',
      )!;
      expect(s.locked, isFalse);
    });

    test('reads views[].card_fields list', () {
      final s = DatabaseYamlParser.parse(
        '''
id: db
name: T
schema:
  title: {type: text}
  priority: {type: text}
  due: {type: date}
views:
  - id: cards
    type: gallery
    card_fields: [priority, due]
''',
        folderPath: 'x',
      )!;
      expect(s.views.first.cardFields, equals(['priority', 'due']));
    });

    test('card_fields is null when absent', () {
      final s = DatabaseYamlParser.parse(
        '''
id: db
name: T
schema:
  title: {type: text}
views:
  - id: cards
    type: gallery
''',
        folderPath: 'x',
      )!;
      expect(s.views.first.cardFields, isNull);
    });

    test('filterColumns preserves locked flag', () {
      final s = DatabaseYamlParser.parse(
        '''
id: db
name: Locked
locked: true
schema:
  title:
    type: text
  extra:
    type: text
''',
        folderPath: 'x',
      )!;
      expect(s.filterColumns({'title'}).locked, isTrue);
    });

    test('parses list view type', () {
      final s = DatabaseYamlParser.parse(
        '''
id: db
name: T
views:
  - id: compact
    type: list
''',
        folderPath: 'T',
      );
      expect(s!.views.first.type, equals(ViewType.list));
    });
  });

  group('DatabaseSchema.filterColumns', () {
    final base = DatabaseSchema(
      id: 'x',
      name: 'T',
      icon: '*',
      color: '#000',
      folderPath: 'T',
      columns: const [
        ColumnDef(key: 'title', type: ColumnType.text),
        ColumnDef(key: 'arr', type: ColumnType.number),
        ColumnDef(key: 'owner', type: ColumnType.text),
      ],
      views: const [],
    );

    test('null keys returns identical schema', () {
      expect(base.filterColumns(null), same(base));
    });

    test('filters but always keeps title', () {
      final r = base.filterColumns({'arr'});
      expect(r.columns.map((c) => c.key), equals(['title', 'arr']));
    });
  });
}
