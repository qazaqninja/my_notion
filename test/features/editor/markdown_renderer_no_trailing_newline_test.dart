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
  testWidgets('renders body without trailing newline (last block sourceEnd '
      'must not overshoot body.length)', (tester) async {
    const body = '# Heading\n\nfirst paragraph\n\nlast paragraph';
    assert(!body.endsWith('\n'));

    await tester.pumpWidget(
      _wrap(MarkdownRenderer(body: body, onBodyChange: (_) {})),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Heading'), findsOneWidget);
    expect(find.text('last paragraph'), findsOneWidget);
  });

  testWidgets('renders body without trailing newline (read-only path)',
      (tester) async {
    const body = '# Title\n\nonly paragraph with no trailing newline';
    await tester.pumpWidget(_wrap(const MarkdownRenderer(body: body)));
    expect(tester.takeException(), isNull);
  });
}
