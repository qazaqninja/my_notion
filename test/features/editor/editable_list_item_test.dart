/// Smoke test for tap-to-edit on list items (M176). The full commit
/// flow is exercised indirectly: the same `ListReorder.emit` helper
/// already has unit tests (list_reorder_test.dart) and the underlying
/// edit pattern mirrors `_EditableBlock` from M40. This test just
/// pumps a list-bearing MarkdownRenderer to confirm no
/// regressions in rendering.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/core/db/quill_database.dart' hide Page;
import 'package:my_notion/features/editor/presentation/widgets/markdown_renderer.dart';
import 'package:my_notion/features/vault/presentation/bloc/vault_bloc.dart';
import 'package:my_notion/features/vault/presentation/bloc/vault_state.dart';
import 'package:my_notion/shared/theme/accent.dart';
import 'package:my_notion/shared/theme/tokens.dart';

class _StubVaultBloc extends Cubit<VaultState> implements VaultBloc {
  _StubVaultBloc() : super(const VaultInitial());
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _wrap(Widget child) {
  final vault = _StubVaultBloc();
  final db = QuillDatabase.forTesting(NativeDatabase.memory());
  return MaterialApp(
    theme: makeTheme(Brightness.light, AccentKey.sage),
    home: MultiBlocProvider(
      providers: [
        BlocProvider<VaultBloc>.value(value: vault),
        RepositoryProvider<QuillDatabase>.value(value: db),
      ],
      child: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

void main() {
  testWidgets('renderer with ul + onBodyChange wires without crashing',
      (tester) async {
    String? lastBody;
    await tester.pumpWidget(_wrap(MarkdownRenderer(
      body: '- one\n- two\n- three\n',
      onBodyChange: (b) => lastBody = b,
    )));
    expect(find.text('one'), findsOneWidget);
    expect(find.text('two'), findsOneWidget);
    expect(find.text('three'), findsOneWidget);
    // No edits yet → callback never fired.
    expect(lastBody, isNull);
  });

  testWidgets('renderer with ol + onBodyChange wires without crashing',
      (tester) async {
    await tester.pumpWidget(_wrap(const MarkdownRenderer(
      body: '1. alpha\n2. beta\n3. gamma\n',
    )));
    expect(find.text('alpha'), findsOneWidget);
    expect(find.text('beta'), findsOneWidget);
    expect(find.text('gamma'), findsOneWidget);
    // Numbered prefixes render as separate mono text.
    expect(find.text('1.'), findsOneWidget);
    expect(find.text('2.'), findsOneWidget);
    expect(find.text('3.'), findsOneWidget);
  });
}
