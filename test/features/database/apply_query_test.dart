import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/database/domain/entities/database_query.dart';
import 'package:my_notion/features/database/domain/entities/database_schema.dart';
import 'package:my_notion/features/database/domain/repositories/database_repository.dart';
import 'package:my_notion/features/database/domain/usecases/apply_query.dart';

void main() {
  final schema = DatabaseSchema(
    id: 'db',
    name: 'Customers',
    icon: '🏢',
    color: '#6B8E7F',
    folderPath: 'Customers',
    columns: const [
      ColumnDef(key: 'title', type: ColumnType.text),
      ColumnDef(key: 'arr', type: ColumnType.number),
      ColumnDef(
        key: 'stage',
        type: ColumnType.select,
        options: ['pilot', 'expanding', 'churn'],
      ),
      ColumnDef(key: 'updated', type: ColumnType.date),
      ColumnDef(key: 'active', type: ColumnType.checkbox),
    ],
    views: const [],
  );

  DatabasePageRow r(String ulid, Map<String, dynamic> cells) =>
      DatabasePageRow(
          ulid: ulid,
          title: '${cells['title'] ?? ulid}',
          relativePath: '$ulid.md',
          cells: cells);

  final rows = [
    r('A', {'title': 'Acmeco', 'arr': '120000', 'stage': 'pilot', 'updated': '2026-04-01', 'active': 'true'}),
    r('B', {'title': 'Boco',   'arr': '420000', 'stage': 'expanding', 'updated': '2026-05-01', 'active': 'true'}),
    r('C', {'title': 'Cinc',   'arr': '30000',  'stage': 'churn', 'updated': '2026-03-15', 'active': 'false'}),
    r('D', {'title': 'Dyna',   'arr': '',       'stage': 'pilot', 'updated': '', 'active': 'false'}),
  ];

  group('ApplyQuery.apply', () {
    test('filter: equals on select narrows rows', () {
      final q = DatabaseQuery(filters: [
        FilterRule(columnKey: 'stage', op: FilterOp.equals, value: 'pilot'),
      ]);
      final out = ApplyQuery.apply(rows, q, schema);
      expect(out.map((r) => r.ulid).toList(), ['A', 'D']);
    });

    test('filter: notEquals + isNotEmpty combined', () {
      final q = DatabaseQuery(filters: [
        FilterRule(columnKey: 'stage', op: FilterOp.notEquals, value: 'churn'),
        FilterRule(columnKey: 'arr', op: FilterOp.isNotEmpty),
      ]);
      final out = ApplyQuery.apply(rows, q, schema);
      expect(out.map((r) => r.ulid).toList(), ['A', 'B']);
    });

    test('filter: gt on number', () {
      final q = DatabaseQuery(filters: [
        FilterRule(columnKey: 'arr', op: FilterOp.gt, value: '100000'),
      ]);
      final out = ApplyQuery.apply(rows, q, schema);
      expect(out.map((r) => r.ulid).toList().toSet(), {'A', 'B'});
    });

    test('filter: lt on date (lexicographic)', () {
      final q = DatabaseQuery(filters: [
        FilterRule(columnKey: 'updated', op: FilterOp.lt, value: '2026-04-15'),
      ]);
      final out = ApplyQuery.apply(rows, q, schema);
      expect(out.map((r) => r.ulid).toList().toSet(), {'A', 'C'});
    });

    test('filter: contains on text', () {
      final q = DatabaseQuery(filters: [
        FilterRule(columnKey: 'title', op: FilterOp.contains, value: 'co'),
      ]);
      final out = ApplyQuery.apply(rows, q, schema);
      // Acmeco, Boco — both contain "co".
      expect(out.map((r) => r.ulid).toList().toSet(), {'A', 'B'});
    });

    test('filter: equals on checkbox', () {
      final q = DatabaseQuery(filters: [
        FilterRule(columnKey: 'active', op: FilterOp.equals, value: 'true'),
      ]);
      final out = ApplyQuery.apply(rows, q, schema);
      expect(out.map((r) => r.ulid).toList().toSet(), {'A', 'B'});
    });

    test('sort: ascending on number, empties last', () {
      final q = const DatabaseQuery(sorts: [SortRule(columnKey: 'arr')]);
      final out = ApplyQuery.apply(rows, q, schema);
      expect(out.map((r) => r.ulid).toList(), ['C', 'A', 'B', 'D']);
    });

    test('sort: descending on number', () {
      final q =
          const DatabaseQuery(sorts: [SortRule(columnKey: 'arr', ascending: false)]);
      final out = ApplyQuery.apply(rows, q, schema);
      expect(out.map((r) => r.ulid).toList(), ['B', 'A', 'C', 'D']);
    });

    test('combined filter + sort', () {
      final q = DatabaseQuery(
        filters: [
          FilterRule(columnKey: 'stage', op: FilterOp.notEquals, value: 'churn'),
        ],
        sorts: const [SortRule(columnKey: 'arr', ascending: false)],
      );
      final out = ApplyQuery.apply(rows, q, schema);
      expect(out.map((r) => r.ulid).toList(), ['B', 'A', 'D']);
    });
  });

  group('ApplyQuery.group', () {
    test('null groupBy → single "All" bucket', () {
      final grouped = ApplyQuery.group(rows, null, schema);
      expect(grouped.keys.toList(), ['All']);
      expect(grouped['All']!.length, 4);
    });

    test('groupBy stage uses declared option order; empty groups still appear', () {
      final grouped = ApplyQuery.group(rows, 'stage', schema);
      expect(grouped.keys.toList(), ['pilot', 'expanding', 'churn']);
      expect(grouped['pilot']!.map((r) => r.ulid).toList(), ['A', 'D']);
      expect(grouped['expanding']!.map((r) => r.ulid).toList(), ['B']);
      expect(grouped['churn']!.map((r) => r.ulid).toList(), ['C']);
    });

    test('groupBy non-select with empty values bucketed as "—"', () {
      final grouped = ApplyQuery.group(rows, 'updated', schema);
      // Updated has 3 distinct dates + one empty.
      expect(grouped.keys, containsAll(['2026-04-01', '2026-05-01', '2026-03-15', '—']));
    });
  });

  // M791 — equals filter on a multi column must check any-item membership
  // in the YAML flow list, not a string match on the bracketed whole.
  group('ApplyQuery.apply — M791 multi-column equals', () {
    final multiSchema = DatabaseSchema(
      id: 'db',
      name: 'Posts',
      icon: '📝',
      color: '#6B8E7F',
      folderPath: 'Posts',
      columns: const [
        ColumnDef(key: 'title', type: ColumnType.text),
        ColumnDef(key: 'tags', type: ColumnType.multi),
      ],
      views: const [],
    );

    DatabasePageRow row(String ulid, String title, String tagsRaw) =>
        DatabasePageRow(
          ulid: ulid,
          title: title,
          relativePath: '$ulid.md',
          cells: {'title': title, 'tags': tagsRaw},
        );

    final rows = [
      row('A', 'one', '[draft, urgent]'),
      row('B', 'two', '[urgent]'),
      row('C', 'three', '[done]'),
      row('D', 'four', '[]'),
    ];

    test('equals "draft" matches a multi cell containing "draft"', () {
      final q = DatabaseQuery(filters: [
        FilterRule(columnKey: 'tags', op: FilterOp.equals, value: 'draft'),
      ]);
      final out = ApplyQuery.apply(rows, q, multiSchema);
      expect(out.map((r) => r.ulid).toList(), ['A']);
    });

    test('equals "urgent" matches both rows that include it', () {
      final q = DatabaseQuery(filters: [
        FilterRule(columnKey: 'tags', op: FilterOp.equals, value: 'urgent'),
      ]);
      final out = ApplyQuery.apply(rows, q, multiSchema);
      expect(out.map((r) => r.ulid).toList().toSet(), {'A', 'B'});
    });

    test('equals is case-insensitive', () {
      final q = DatabaseQuery(filters: [
        FilterRule(columnKey: 'tags', op: FilterOp.equals, value: 'DRAFT'),
      ]);
      final out = ApplyQuery.apply(rows, q, multiSchema);
      expect(out.map((r) => r.ulid).toList(), ['A']);
    });

    test('equals does not match the bracketed whole', () {
      final q = DatabaseQuery(filters: [
        FilterRule(
            columnKey: 'tags',
            op: FilterOp.equals,
            value: '[draft, urgent]'),
      ]);
      final out = ApplyQuery.apply(rows, q, multiSchema);
      expect(out, isEmpty,
          reason: 'the bracketed form is never a valid tag value');
    });

    test('equals on empty flow list yields no matches', () {
      final q = DatabaseQuery(filters: [
        FilterRule(columnKey: 'tags', op: FilterOp.equals, value: 'draft'),
      ]);
      final out = ApplyQuery.apply([rows[3]], q, multiSchema);
      expect(out, isEmpty);
    });
  });
}
