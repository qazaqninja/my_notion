// Smoke test for PdfInlinePreview (B3 of the 1m-loop plan).
//
// Verifies the widget renders a loading placeholder before the PDF document
// resolves. Actually rendering a PDF page is platform-channel territory and
// out of scope for unit tests.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/shared/widgets/pdf_inline_preview.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PdfInlinePreview (B3)', () {
    testWidgets('renders a loading placeholder before the document resolves',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PdfInlinePreview(filePath: '/tmp/does-not-exist.pdf'),
          ),
        ),
      );

      expect(find.byType(PdfInlinePreview), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('exposes the filePath via the widget API', (tester) async {
      const widget = PdfInlinePreview(filePath: '/foo.pdf');
      expect(widget.filePath, '/foo.pdf');
    });
  });
}
