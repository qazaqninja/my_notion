import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/editor/presentation/widgets/markdown_renderer.dart';
import 'package:my_notion/shared/theme/accent.dart';
import 'package:my_notion/shared/theme/tokens.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: makeTheme(Brightness.light, AccentKey.sage),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  testWidgets('[breadcrumb] renders mono path segments', (tester) async {
    await tester.pumpWidget(_wrap(
      const MarkdownRenderer(
        body: '[breadcrumb]\n',
        relativePath: 'Operations/Customers/Acmeco.md',
      ),
    ));
    expect(find.text('Operations'), findsOneWidget);
    expect(find.text('Customers'), findsOneWidget);
    expect(find.text('Acmeco'), findsOneWidget);
    // .md is stripped from the leaf
    expect(find.text('Acmeco.md'), findsNothing);
    // separators
    expect(find.text('/'), findsNWidgets(2));
  });

  testWidgets('[[breadcrumb]] alternate spelling works', (tester) async {
    await tester.pumpWidget(_wrap(
      const MarkdownRenderer(
        body: '[[breadcrumb]]\n',
        relativePath: 'Inbox.md',
      ),
    ));
    expect(find.text('Inbox'), findsOneWidget);
  });

  testWidgets('no relativePath → placeholder message', (tester) async {
    await tester.pumpWidget(_wrap(
      const MarkdownRenderer(body: '[breadcrumb]\n'),
    ));
    expect(find.textContaining('Breadcrumb'), findsOneWidget);
  });

  testWidgets('plain text body does not match the marker', (tester) async {
    await tester.pumpWidget(_wrap(
      const MarkdownRenderer(
        body: 'This page mentions [breadcrumb] in passing.\n',
        relativePath: 'Notes/Note.md',
      ),
    ));
    // Should not see a path crumb at all — the marker only fires when
    // the entire line is the marker.
    expect(find.text('Notes'), findsNothing);
  });
}
