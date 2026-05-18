import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/editor/data/repositories/pdf_export_repository_impl.dart';
import 'package:my_notion/features/editor/domain/repositories/pdf_export_repository.dart';

void main() {
  // M1796: CA-04 ExportRepository extraction (slice 2 — completes
  // the arc). Mirrors M1794 (HtmlExportRepository) for the PDF
  // half. Editor-domain interface adapts vault/data/pdf_exporter.dart
  // so editor_beta_page can resolve the renderer via
  // context.read<PdfExportRepository>() instead of crossing the
  // feature boundary at import time. PdfExporter has its own
  // coverage in vault/data tests.
  group('PdfExportRepository', () {
    group('domain contract', () {
      test('renderPdf returns a non-empty byte buffer', () async {
        const repo = PdfExportRepositoryImpl();
        final bytes = await repo.renderPdf(
          title: 'Hello',
          body: 'World.',
        );

        expect(bytes, isNotEmpty);
      });

      test('impl implements the abstract interface', () {
        expect(
          const PdfExportRepositoryImpl(),
          isA<PdfExportRepository>(),
        );
      });
    });
  });

  group('CA-04 boundary', () {
    test('editor_beta_page no longer imports vault/data/pdf_exporter', () {
      final source = File(
        'lib/features/editor/presentation/pages/editor_beta_page.dart',
      ).readAsStringSync();
      expect(
        source.contains("import '../../../vault/data/pdf_exporter.dart';"),
        isFalse,
        reason:
            'M1796: PdfExporter now reached via PdfExportRepository, '
            'not a direct cross-feature data-layer import. Closes the '
            'CA-04 ExportRepository arc that started at M1794.',
      );
    });
  });
}
