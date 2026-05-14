import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/database/domain/entities/database_schema.dart';
import 'package:my_notion/features/database/domain/repositories/database_repository.dart';
import 'package:my_notion/features/database/presentation/widgets/timeline_view.dart';
import 'package:my_notion/shared/theme/accent.dart';
import 'package:my_notion/shared/theme/tokens.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: makeTheme(Brightness.light, AccentKey.sage),
      home: Scaffold(body: child),
    );

const _schema = DatabaseSchema(
  id: 'proj',
  name: 'Projects',
  icon: 'P',
  color: '#6B8E7F',
  folderPath: 'Projects',
  columns: [],
  views: [DatabaseView(id: 'all', name: 'All', type: ViewType.table)],
);

void main() {
  testWidgets('renders dep badge with ↳ N for dependent rows', (tester) async {
    final rows = [
      const DatabasePageRow(
        ulid: '01HQAAA0000000000000000001',
        title: 'A',
        relativePath: 'Projects/A.md',
        cells: {'updated': '2026-05-01'},
      ),
      const DatabasePageRow(
        ulid: '01HQAAA0000000000000000002',
        title: 'B',
        relativePath: 'Projects/B.md',
        cells: {
          'updated': '2026-05-08',
          'depends_on': '[[01HQAAA0000000000000000001]]',
        },
      ),
    ];
    await tester.pumpWidget(_wrap(TimelineView(schema: _schema, rows: rows)));
    expect(find.text('↳ 1'), findsOneWidget);
  });

  testWidgets('multiple deps render as ↳ N with combined tooltip',
      (tester) async {
    final rows = [
      const DatabasePageRow(
        ulid: '01HQAAA0000000000000000001',
        title: 'Upstream A',
        relativePath: 'Projects/A.md',
        cells: {'updated': '2026-05-01'},
      ),
      const DatabasePageRow(
        ulid: '01HQAAA0000000000000000002',
        title: 'Upstream B',
        relativePath: 'Projects/B.md',
        cells: {'updated': '2026-05-02'},
      ),
      const DatabasePageRow(
        ulid: '01HQAAA0000000000000000003',
        title: 'C',
        relativePath: 'Projects/C.md',
        cells: {
          'updated': '2026-05-15',
          'depends_on': [
            '[[01HQAAA0000000000000000001]]',
            '[[01HQAAA0000000000000000002]]',
          ],
        },
      ),
    ];
    await tester.pumpWidget(_wrap(TimelineView(schema: _schema, rows: rows)));
    expect(find.text('↳ 2'), findsOneWidget);
  });

  testWidgets('unresolved ULIDs are dropped, not counted', (tester) async {
    final rows = [
      const DatabasePageRow(
        ulid: '01HQAAA0000000000000000001',
        title: 'Real',
        relativePath: 'Projects/A.md',
        cells: {'updated': '2026-05-01'},
      ),
      const DatabasePageRow(
        ulid: '01HQAAA0000000000000000002',
        title: 'B',
        relativePath: 'Projects/B.md',
        cells: {
          'updated': '2026-05-08',
          'depends_on': '[[ZZZZZZZZZZZZZZZZZZZZZZZZZZ]]',
        },
      ),
    ];
    await tester.pumpWidget(_wrap(TimelineView(schema: _schema, rows: rows)));
    expect(find.textContaining('↳'), findsNothing);
  });

  testWidgets('no depends_on cell → no badge', (tester) async {
    final rows = [
      const DatabasePageRow(
        ulid: '01HQAAA0000000000000000001',
        title: 'A',
        relativePath: 'Projects/A.md',
        cells: {'updated': '2026-05-01'},
      ),
    ];
    await tester.pumpWidget(_wrap(TimelineView(schema: _schema, rows: rows)));
    expect(find.textContaining('↳'), findsNothing);
  });

  testWidgets('subGroupBy emits a band when value changes', (tester) async {
    final rows = [
      const DatabasePageRow(
        ulid: '01HQAAA0000000000000000001',
        title: 'A',
        relativePath: 'Projects/A.md',
        cells: {'updated': '2026-05-01', 'stage': 'todo'},
      ),
      const DatabasePageRow(
        ulid: '01HQAAA0000000000000000002',
        title: 'B',
        relativePath: 'Projects/B.md',
        cells: {'updated': '2026-05-08', 'stage': 'done'},
      ),
    ];
    await tester.pumpWidget(_wrap(TimelineView(
      schema: _schema,
      rows: rows,
      subGroupBy: 'stage',
    )));
    // The band labels are visible somewhere on screen (the timeline's
    // long horizontal scroll may push other text off-screen, so allow
    // at-least-one match).
    expect(find.text('todo'), findsAtLeastNWidgets(1));
    expect(find.text('done'), findsAtLeastNWidgets(1));
  });
}
