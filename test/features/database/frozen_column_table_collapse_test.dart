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

// Text column with isParent: true sidesteps the relation cell
// renderer's need for a QuillDatabase provider — the depth/collapse
// logic only inspects the isParent flag, not the column type.
const _schema = DatabaseSchema(
  id: 'tasks',
  name: 'Tasks',
  icon: 'T',
  color: '#6B8E7F',
  folderPath: 'Tasks',
  columns: [
    ColumnDef(
      key: 'parent',
      type: ColumnType.text,
      isParent: true,
    ),
  ],
  views: [DatabaseView(id: 'all', name: 'All', type: ViewType.table)],
);

const _parent = DatabasePageRow(
  ulid: 'PARENTULID000000000000000A',
  title: 'Parent task',
  relativePath: 'Tasks/P.md',
  cells: {},
);

const _child = DatabasePageRow(
  ulid: 'CHILDULID0000000000000000A',
  title: 'Child task',
  relativePath: 'Tasks/C.md',
  cells: {'parent': 'PARENTULID000000000000000A'},
);

Widget _wrap(Widget child) {
  final vault = _StubVaultBloc();
  return MaterialApp(
    theme: makeTheme(Brightness.light, AccentKey.sage),
    home: BlocProvider<VaultBloc>.value(
      value: vault,
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('parent row shows chevron when it has children', (tester) async {
    await tester.pumpWidget(_wrap(FrozenColumnTable(
      schema: _schema,
      rows: const [_parent, _child],
      onOpenPage: (_) {},
    )));
    await tester.pump();
    expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
    expect(find.text('Parent task'), findsOneWidget);
    expect(find.text('Child task'), findsOneWidget);
  });

  testWidgets('tapping chevron hides the child row', (tester) async {
    await tester.pumpWidget(_wrap(FrozenColumnTable(
      schema: _schema,
      rows: const [_parent, _child],
      onOpenPage: (_) {},
    )));
    await tester.pump();
    expect(find.text('Child task'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
    await tester.pump();
    expect(find.text('Child task'), findsNothing);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });

  testWidgets('tapping chevron again restores the child row',
      (tester) async {
    await tester.pumpWidget(_wrap(FrozenColumnTable(
      schema: _schema,
      rows: const [_parent, _child],
      onOpenPage: (_) {},
    )));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pump();
    expect(find.text('Child task'), findsOneWidget);
  });

  testWidgets('parent row without children has no chevron', (tester) async {
    await tester.pumpWidget(_wrap(FrozenColumnTable(
      schema: _schema,
      rows: const [_parent],
      onOpenPage: (_) {},
    )));
    await tester.pump();
    expect(find.byIcon(Icons.keyboard_arrow_down), findsNothing);
    expect(find.byIcon(Icons.chevron_right), findsNothing);
  });
}
