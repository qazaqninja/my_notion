// Smoke test for MermaidView (C1 slice 1 of the 1m-loop plan).
//
// Drives only the early-render contract — actually loading mermaid.min.js
// requires a real WebView platform channel and isn't reachable from pure
// unit tests. Slice 2 will add a golden against the rendered placeholder
// shell; slice 3 may add an integration test on real devices/emulators.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/shared/widgets/mermaid_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MermaidView (C1)', () {
    testWidgets('renders a placeholder on unsupported platforms', (tester) async {
      // Linux / Windows: the widget shows a fallback styled card with the
      // source text, since webview_flutter is iOS/Android/macOS-only.
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MermaidView(
              source: 'graph TD\n  A-->B',
              forceFallback: true,
            ),
          ),
        ),
      );

      expect(find.byType(MermaidView), findsOneWidget);
      // Fallback shows the source as selectable text + a "rendering needs
      // a viewer" hint.
      expect(find.textContaining('graph TD'), findsOneWidget);
    });

    testWidgets('exposes the source via the widget API', (tester) async {
      const widget = MermaidView(source: 'sequenceDiagram\n  A->>B: hello');
      expect(widget.source, 'sequenceDiagram\n  A->>B: hello');
    });
  });
}
