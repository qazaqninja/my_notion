import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/editor/data/repositories/html_export_repository_impl.dart';
import 'package:my_notion/features/editor/domain/repositories/html_export_repository.dart';

void main() {
  // M1794: CA-04 ExportRepository extraction (slice 1 of arc).
  // Establishes a thin editor/domain interface so editor_beta_page
  // stops importing vault/data/html_exporter.dart directly. The impl
  // delegates to the existing pure-function `HtmlExporter.renderStandalonePage`
  // (which has its own coverage in vault/data tests).
  group('HtmlExportRepository', () {
    group('domain contract', () {
      test('renderStandalonePage returns a non-empty HTML document', () {
        final repo = HtmlExportRepositoryImpl();
        final html = repo.renderStandalonePage(
          title: 'Hello',
          body: 'World.',
        );

        expect(html, isNotEmpty);
        expect(html, contains('<!doctype html>'));
        expect(html, contains('Hello'));
      });

      test('impl implements the abstract interface', () {
        expect(HtmlExportRepositoryImpl(), isA<HtmlExportRepository>());
      });
    });
  });

  group('CA-04 boundary', () {
    test('editor_beta_page no longer imports vault/data/html_exporter', () {
      final source = File(
        'lib/features/editor/presentation/pages/editor_beta_page.dart',
      ).readAsStringSync();
      expect(
        source.contains(
          "import '../../../vault/data/html_exporter.dart';",
        ),
        isFalse,
        reason:
            'M1794: HtmlExporter now reached via HtmlExportRepository, '
            'not a direct cross-feature data-layer import.',
      );
    });
  });
}
