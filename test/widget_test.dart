import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/shared/theme/accent.dart';
import 'package:my_notion/shared/theme/quill_tokens.dart';
import 'package:my_notion/shared/theme/tokens.dart';
import 'package:my_notion/shared/widgets/quill_icon.dart';

void main() {
  testWidgets('makeTheme returns a ThemeData with QuillTokens extension', (tester) async {
    final theme = makeTheme(Brightness.light, AccentKey.sage);
    final tokens = theme.extension<QuillTokens>();
    expect(tokens, isNotNull);
    expect(tokens!.bg, const Color(0xFFF8F6F2));
    expect(tokens.accent, AccentKey.sage.color);
  });

  testWidgets('QuillIcon renders without exception for known names', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: makeTheme(Brightness.light, AccentKey.sage),
        home: Scaffold(
          body: Row(
            children: [
              for (final n in const ['plus', 'x', 'file-md', 'folder', 'caret', 'database', 'gear'])
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: QuillIcon(n, size: 16),
                ),
            ],
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
