// Smoke test for MermaidView (C1 slice 1 of the 1m-loop plan) plus the
// M1686 extraction: pure-Dart unit coverage of [mermaidHtmlFor], the
// scaffolding helper that _MermaidViewState injects into the WebView.

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

    testWidgets('renders the source through the fallback path '
        '(behavioral cover for the widget API)', (tester) async {
      // M1690 (TS-06 fix-forward): the prior incarnation asserted on the
      // `widget.source` field directly, which only proved the constructor
      // stored the value. This pumps the widget and observes that the
      // source actually flows through to the rendered output via the
      // fallback card path — same coverage, behavior-first.
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MermaidView(
              source: 'sequenceDiagram\n  A->>B: hello',
              forceFallback: true,
            ),
          ),
        ),
      );

      expect(find.textContaining('sequenceDiagram'), findsOneWidget);
      expect(find.textContaining('A->>B: hello'), findsOneWidget);
    });
  });

  group('mermaidHtmlFor (M1686)', () {
    // M1690 (TS-04 fix-forward): sub-group labels now prefix the function
    // under test so the test runner output reads `mermaidHtmlFor() source
    // escaping › escapes ampersands …` rather than the bare concern name.
    group('mermaidHtmlFor() source escaping', () {
      test('escapes ampersands as &amp;', () {
        final html = mermaidHtmlFor(source: 'A & B', mermaidJs: 'x');
        expect(html, contains('A &amp; B'));
        expect(html, isNot(contains('<div class="mermaid">A & B')));
      });

      test('escapes left angle brackets as &lt;', () {
        final html = mermaidHtmlFor(source: 'A<B', mermaidJs: 'x');
        expect(html, contains('A&lt;B'));
      });

      test('escapes right angle brackets as &gt;', () {
        final html = mermaidHtmlFor(source: 'A>B', mermaidJs: 'x');
        expect(html, contains('A&gt;B'));
      });

      test('ampersand-then-lt escapes both in correct order (& first)', () {
        // The naive order < first would corrupt: &lt; → &amp;lt; on the
        // second pass. The implementation must escape `&` BEFORE `<`/`>`.
        final html = mermaidHtmlFor(source: '<', mermaidJs: 'x');
        expect(html, contains('&lt;'));
        expect(html, isNot(contains('&amp;lt;')));
      });
    });

    group('mermaidHtmlFor() mermaid.min.js inlining', () {
      test('inlines the JS payload inside a <script> tag when non-empty', () {
        final html = mermaidHtmlFor(
          source: 'graph TD',
          mermaidJs: 'console.log("hi")',
        );
        expect(html, contains('<script>console.log("hi")</script>'));
      });

      test('falls back to a "not vendored" notice when mermaidJs is empty',
          () {
        final html = mermaidHtmlFor(source: 'graph TD', mermaidJs: '');
        expect(html, contains('mermaid.min.js not vendored yet'));
        expect(html, contains('assets/mermaid/mermaid.min.js'));
      });
    });

    group('mermaidHtmlFor() HTML scaffold', () {
      test('starts with the HTML5 doctype', () {
        final html = mermaidHtmlFor(source: 'graph TD', mermaidJs: 'x');
        expect(html.trimLeft(), startsWith('<!doctype html>'));
      });

      test('emits a <div class="mermaid"> wrapping the escaped source', () {
        final html = mermaidHtmlFor(source: 'graph TD', mermaidJs: 'x');
        expect(html, contains('<div class="mermaid">graph TD</div>'));
      });

      test('invokes mermaid.initialize with startOnLoad + securityLevel '
          'so the inlined source auto-renders', () {
        final html = mermaidHtmlFor(source: 'graph TD', mermaidJs: 'x');
        expect(html, contains('mermaid.initialize'));
        expect(html, contains('startOnLoad: true'));
        expect(html, contains("securityLevel: 'loose'"));
      });
    });
  });
}
