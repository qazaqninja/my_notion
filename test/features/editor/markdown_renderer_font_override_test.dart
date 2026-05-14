import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/editor/presentation/widgets/markdown_renderer.dart';
import 'package:my_notion/shared/theme/accent.dart';
import 'package:my_notion/shared/theme/tokens.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: makeTheme(Brightness.light, AccentKey.sage),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

DefaultTextStyle? _findOverride(WidgetTester tester) {
  // The renderer wraps its body Column in a DefaultTextStyle.merge —
  // find the one whose fontFamily is one of our two overrides.
  return tester
      .widgetList<DefaultTextStyle>(find.byType(DefaultTextStyle))
      .where((d) =>
          d.style.fontFamily == 'Georgia' ||
          d.style.fontFamily == 'JetBrainsMono')
      .firstOrNull;
}

void main() {
  testWidgets('font: serif sets Georgia + serif fallback', (tester) async {
    await tester.pumpWidget(_wrap(
      const MarkdownRenderer(body: '# Title\n\nbody', font: 'serif'),
    ));
    final dts = _findOverride(tester);
    expect(dts, isNotNull);
    expect(dts!.style.fontFamily, 'Georgia');
    expect(dts.style.fontFamilyFallback,
        containsAll(<String>['Times New Roman', 'serif']));
  });

  testWidgets('font: mono sets JetBrainsMono', (tester) async {
    await tester.pumpWidget(_wrap(
      const MarkdownRenderer(body: 'plain body', font: 'mono'),
    ));
    final dts = _findOverride(tester);
    expect(dts, isNotNull);
    expect(dts!.style.fontFamily, 'JetBrainsMono');
  });

  testWidgets('font: default does not wrap in a font override',
      (tester) async {
    await tester.pumpWidget(_wrap(
      const MarkdownRenderer(body: 'plain body', font: 'default'),
    ));
    // We shouldn't have wrapped in a Georgia/JetBrainsMono DTS — the only
    // DefaultTextStyles in the tree are MaterialApp's, neither of which
    // sets fontFamily to one of our overrides.
    final found = tester
        .widgetList<DefaultTextStyle>(find.byType(DefaultTextStyle))
        .any((d) =>
            d.style.fontFamily == 'Georgia' ||
            d.style.fontFamily == 'JetBrainsMono');
    expect(found, isFalse);
  });

  testWidgets('font: garbage value is ignored', (tester) async {
    await tester.pumpWidget(_wrap(
      const MarkdownRenderer(body: 'plain body', font: 'comic-sans'),
    ));
    final found = tester
        .widgetList<DefaultTextStyle>(find.byType(DefaultTextStyle))
        .any((d) =>
            d.style.fontFamily == 'Georgia' ||
            d.style.fontFamily == 'JetBrainsMono');
    expect(found, isFalse);
  });
}
