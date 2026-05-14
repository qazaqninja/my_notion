import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/database/domain/entities/database_schema.dart';
import 'package:my_notion/features/database/domain/repositories/database_repository.dart';
import 'package:my_notion/features/database/presentation/widgets/list_view.dart';
import 'package:my_notion/shared/theme/accent.dart';
import 'package:my_notion/shared/theme/tokens.dart';

const _schema = DatabaseSchema(
  id: 'x',
  name: 'X',
  icon: 'X',
  color: '#000',
  folderPath: 'X',
  columns: [
    ColumnDef(key: 'stage', type: ColumnType.text),
  ],
  views: [DatabaseView(id: 'all', name: 'All', type: ViewType.list)],
);

Widget _wrap(Widget child) => MaterialApp(
      theme: makeTheme(Brightness.light, AccentKey.sage),
      home: Scaffold(body: SizedBox(height: 600, child: child)),
    );

void main() {
  testWidgets('subGroupBy emits a section header per value', (tester) async {
    const rows = [
      DatabasePageRow(
        ulid: '01HQAAA0000000000000000001',
        title: 'A',
        relativePath: 'X/A.md',
        cells: {'stage': 'todo'},
      ),
      DatabasePageRow(
        ulid: '01HQAAA0000000000000000002',
        title: 'B',
        relativePath: 'X/B.md',
        cells: {'stage': 'todo'},
      ),
      DatabasePageRow(
        ulid: '01HQAAA0000000000000000003',
        title: 'C',
        relativePath: 'X/C.md',
        cells: {'stage': 'done'},
      ),
    ];
    await tester.pumpWidget(_wrap(const DatabaseListView(
      schema: _schema,
      rows: rows,
      subGroupBy: 'stage',
    )));
    await tester.pump();
    // Each section label appears at least once.
    expect(find.text('todo'), findsAtLeastNWidgets(1));
    expect(find.text('done'), findsAtLeastNWidgets(1));
    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.text('C'), findsOneWidget);
    // Counts: '2' for todo, '1' for done.
    expect(find.text('2'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('no subGroupBy → no headers', (tester) async {
    const rows = [
      DatabasePageRow(
        ulid: '01HQAAA0000000000000000001',
        title: 'A',
        relativePath: 'X/A.md',
        cells: {'stage': 'todo'},
      ),
      DatabasePageRow(
        ulid: '01HQAAA0000000000000000002',
        title: 'B',
        relativePath: 'X/B.md',
        cells: {'stage': 'done'},
      ),
    ];
    await tester.pumpWidget(_wrap(const DatabaseListView(
      schema: _schema,
      rows: rows,
    )));
    await tester.pump();
    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    // 'todo' / 'done' appear in the right-aligned secondary column once
    // each (no extra section header copy).
    expect(find.text('todo'), findsOneWidget);
    expect(find.text('done'), findsOneWidget);
  });

  testWidgets('empty value lands in "—" section', (tester) async {
    const rows = [
      DatabasePageRow(
        ulid: '01HQAAA0000000000000000001',
        title: 'X',
        relativePath: 'X/X.md',
        cells: {'stage': ''},
      ),
    ];
    await tester.pumpWidget(_wrap(const DatabaseListView(
      schema: _schema,
      rows: rows,
      subGroupBy: 'stage',
    )));
    await tester.pump();
    expect(find.text('—'), findsOneWidget);
  });
}
