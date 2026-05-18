/// Editor-domain interface for the "Print page" / "Save as PDF" kebab
/// action.
///
/// Defined here so `editor_beta_page.dart` no longer needs to import
/// from `features/vault/data/pdf_exporter.dart` directly (CA-04
/// follow-on to the M1794 HtmlExportRepository extraction). The
/// concrete implementation in
/// `lib/features/editor/data/repositories/pdf_export_repository_impl.dart`
/// delegates to the pre-existing `PdfExporter.exportSingle` method,
/// which already carries its own test coverage in the vault feature.
// Single-method abstract is intentional: enables DI swap-out
// (RepositoryProvider in tests) without forcing the caller to take
// a typedef alias. CA-04 / RP-01 prefer named interfaces over
// function aliases for cross-feature injection points.
// ignore: one_member_abstracts
abstract class PdfExportRepository {
  /// Render [body] (markdown) as a PDF byte buffer titled [title].
  /// The result is byte-ready for `Printing.layoutPdf` /
  /// `File.writeAsBytes`.
  Future<List<int>> renderPdf({
    required String title,
    required String body,
  });
}
