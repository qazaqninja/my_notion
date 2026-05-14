import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/database/domain/entities/database_schema.dart';
import 'package:my_notion/features/database/domain/repositories/database_repository.dart';
import 'package:my_notion/features/database/presentation/widgets/gallery_view.dart';
import 'package:my_notion/features/vault/presentation/bloc/vault_bloc.dart';
import 'package:my_notion/features/vault/presentation/bloc/vault_state.dart';
import 'package:my_notion/shared/theme/accent.dart';
import 'package:my_notion/shared/theme/tokens.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _StubVaultBloc extends Cubit<VaultState> implements VaultBloc {
  _StubVaultBloc() : super(const VaultInitial());

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _schema = DatabaseSchema(
  id: 'proj',
  name: 'Projects',
  icon: 'P',
  color: '#6B8E7F',
  folderPath: 'Projects',
  columns: [],
  views: [DatabaseView(id: 'all', name: 'All', type: ViewType.gallery)],
);

const _rows = [
  DatabasePageRow(
    ulid: '01HQAAA0000000000000000001',
    title: 'A',
    relativePath: 'Projects/A.md',
    cells: {},
  ),
];

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

  testWidgets('shows S / M / L card-size segment', (tester) async {
    await tester.pumpWidget(
      _wrap(const GalleryView(schema: _schema, rows: _rows)),
    );
    await tester.pump();
    expect(find.text('S'), findsOneWidget);
    expect(find.text('M'), findsOneWidget);
    expect(find.text('L'), findsOneWidget);
    expect(find.text('Card size'), findsOneWidget);
  });

  testWidgets('hydrates persisted size from SharedPreferences',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'gallery.cardSize.proj': 'large',
    });
    await tester.pumpWidget(
      _wrap(const GalleryView(schema: _schema, rows: _rows)),
    );
    // initial pump shows default medium; one more for hydrate
    await tester.pump();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('gallery.cardSize.proj'), 'large');
  });

  testWidgets('tapping a size button persists the choice', (tester) async {
    await tester.pumpWidget(
      _wrap(const GalleryView(schema: _schema, rows: _rows)),
    );
    await tester.pump();
    await tester.tap(find.text('L'));
    await tester.pump();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('gallery.cardSize.proj'), 'large');
  });

  testWidgets('custom cardFields renders labelled rows', (tester) async {
    const rows = [
      DatabasePageRow(
        ulid: '01HQAAA0000000000000000001',
        title: 'A',
        relativePath: 'Projects/A.md',
        cells: {
          'priority': 'High',
          'due': '2026-06-01',
          'notes': 'hello world',
        },
      ),
    ];
    await tester.pumpWidget(_wrap(const GalleryView(
      schema: _schema,
      rows: rows,
      cardFields: ['priority', 'due', 'notes'],
    )));
    await tester.pump();
    expect(find.text('priority'), findsOneWidget);
    expect(find.text('due'), findsOneWidget);
    expect(find.text('notes'), findsOneWidget);
    expect(find.text('hello world'), findsOneWidget);
    expect(find.text('2026-06-01'), findsOneWidget);
  });

  testWidgets('cardFields skips empty + title cells', (tester) async {
    const rows = [
      DatabasePageRow(
        ulid: '01HQAAA0000000000000000001',
        title: 'A',
        relativePath: 'Projects/A.md',
        cells: {
          'priority': '',
          'due': '2026-06-01',
        },
      ),
    ];
    await tester.pumpWidget(_wrap(const GalleryView(
      schema: _schema,
      rows: rows,
      cardFields: ['title', 'priority', 'due'],
    )));
    await tester.pump();
    // `priority` empty → label not shown; `title` is always skipped from
    // the body since it's already the heading.
    expect(find.text('priority'), findsNothing);
    expect(find.text('due'), findsOneWidget);
  });
}
