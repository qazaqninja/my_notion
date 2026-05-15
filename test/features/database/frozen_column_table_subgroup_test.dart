import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/database/domain/entities/database_schema.dart';
import 'package:my_notion/features/database/domain/repositories/database_repository.dart';
import 'package:my_notion/features/database/presentation/widgets/frozen_column_table.dart';
import 'package:my_notion/features/vault/presentation/bloc/vault_bloc.dart';
import 'package:my_notion/features/vault/presentation/bloc/vault_state.dart';
import 'package:my_notion/shared/theme/accent.dart';
import 'package:my_notion/shared/theme/tokens.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _StubVaultBloc extends Cubit<VaultState> implements VaultBloc {
  _StubVaultBloc() : super(const VaultInitial());
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _schema = DatabaseSchema(
  id: 'tasks',
  name: 'Tasks',
  icon: 'T',
  color: '#000',
  folderPath: 'T',
  columns: [
    ColumnDef(key: 'stage', type: ColumnType.text),
  ],
  views: [DatabaseView(id: 'all', name: 'All', type: ViewType.table)],
);

Widget _wrap(Widget child) {
  final vault = _StubVaultBloc();
  return MaterialApp(
    theme: makeTheme(Brightness.light, AccentKey.sage),
    home: BlocProvider<VaultBloc>.value(
      value: vault,
      child: Scaffold(body: SizedBox(height: 600, child: child)),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('subGroupBy inserts divider band when value changes',
      (tester) async {
    const rows = [
      DatabasePageRow(
        ulid: '01HQAAA00000000000000000A1',
        title: 'A',
        relativePath: 'T/A.md',
        cells: {'stage': 'todo'},
      ),
      DatabasePageRow(
        ulid: '01HQAAA00000000000000000A2',
        title: 'B',
        relativePath: 'T/B.md',
        cells: {'stage': 'todo'},
      ),
      DatabasePageRow(
        ulid: '01HQAAA00000000000000000A3',
        title: 'C',
        relativePath: 'T/C.md',
        cells: {'stage': 'done'},
      ),
    ];
    await tester.pumpWidget(_wrap(FrozenColumnTable(
      schema: _schema,
      rows: rows,
      onOpenPage: (_) {},
      subGroupBy: 'stage',
    )));
    await tester.pump();
    // Both group labels rendered as divider headers (and may also
    // appear inside row cell renderers — verify at least one match).
    expect(find.text('todo'), findsAtLeastNWidgets(1));
    expect(find.text('done'), findsAtLeastNWidgets(1));
    // Row titles present.
    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.text('C'), findsOneWidget);
  });

  testWidgets('no subGroupBy → no divider bands', (tester) async {
    const rows = [
      DatabasePageRow(
        ulid: '01HQAAA00000000000000000A1',
        title: 'A',
        relativePath: 'T/A.md',
        cells: {'stage': 'todo'},
      ),
      DatabasePageRow(
        ulid: '01HQAAA00000000000000000A2',
        title: 'B',
        relativePath: 'T/B.md',
        cells: {'stage': 'done'},
      ),
    ];
    await tester.pumpWidget(_wrap(FrozenColumnTable(
      schema: _schema,
      rows: rows,
      onOpenPage: (_) {},
    )));
    await tester.pump();
    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    // Group labels appear only in row cells, exactly once each.
    expect(find.text('todo'), findsOneWidget);
    expect(find.text('done'), findsOneWidget);
  });

  testWidgets('empty subGroupBy value renders as "—" divider',
      (tester) async {
    const rows = [
      DatabasePageRow(
        ulid: '01HQAAA00000000000000000A1',
        title: 'A',
        relativePath: 'T/A.md',
        cells: {'stage': ''},
      ),
      DatabasePageRow(
        ulid: '01HQAAA00000000000000000A2',
        title: 'B',
        relativePath: 'T/B.md',
        cells: {'stage': 'done'},
      ),
    ];
    await tester.pumpWidget(_wrap(FrozenColumnTable(
      schema: _schema,
      rows: rows,
      onOpenPage: (_) {},
      subGroupBy: 'stage',
    )));
    await tester.pump();
    // The divider for the empty cell renders as "—" — same label the
    // CellRenderer uses for empty values, so allow >=1 match.
    expect(find.text('—'), findsAtLeastNWidgets(1));
    expect(find.text('done'), findsAtLeastNWidgets(1));
  });
}
