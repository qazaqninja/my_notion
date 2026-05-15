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
  testWidgets(
      'paragraph with trailing ^<ULID> hides the id but keeps text visible',
      (tester) async {
    const body = 'this is a paragraph ^01HZBLOCKAAAAAAAAAAAAAAAAA\n';
    await tester.pumpWidget(_wrap(const MarkdownRenderer(body: body)));
    await tester.pump();
    // The visible text drops the suffix.
    expect(find.textContaining('this is a paragraph'), findsOneWidget);
    // The raw block id is not rendered as visible text.
    expect(find.textContaining('^01HZBLOCK'), findsNothing);
    expect(find.textContaining('01HZBLOCKAAAAAAAAAAAAAAAAA'), findsNothing);
  });

  testWidgets('heading with trailing ^<ULID> hides the id', (tester) async {
    const body = '# My title ^01HZBLOCKHHHHHHHHHHHHHHHHH\n\nbody';
    await tester.pumpWidget(_wrap(const MarkdownRenderer(body: body)));
    await tester.pump();
    expect(find.text('My title'), findsOneWidget);
    expect(find.textContaining('^01HZBLOCK'), findsNothing);
  });

  testWidgets('paragraph without block id renders unchanged', (tester) async {
    const body = 'plain text without anchors\n';
    await tester.pumpWidget(_wrap(const MarkdownRenderer(body: body)));
    await tester.pump();
    expect(find.textContaining('plain text without anchors'), findsOneWidget);
  });

  testWidgets('multi-line paragraph: id at the very end is stripped',
      (tester) async {
    const body = 'line one\nline two ^01HZBLOCK00000000000000001\n';
    await tester.pumpWidget(_wrap(const MarkdownRenderer(body: body)));
    await tester.pump();
    // Both lines visible, no caret-ulid in view.
    expect(find.textContaining('line one'), findsOneWidget);
    expect(find.textContaining('^01HZBLOCK'), findsNothing);
  });

  testWidgets('lowercase caret-ULID is not consumed (left in body)',
      (tester) async {
    // Lowercase fails the strict regex, so the caret stays as plain text.
    const body = 'hello ^01hzblock00000000000000001\n';
    await tester.pumpWidget(_wrap(const MarkdownRenderer(body: body)));
    await tester.pump();
    expect(find.textContaining('^01hzblock'), findsOneWidget);
  });
}
