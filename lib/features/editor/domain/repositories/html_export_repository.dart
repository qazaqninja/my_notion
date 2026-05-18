/// Editor-domain interface for the "Export as .html…" kebab action.
///
/// Defined here so `editor_beta_page.dart` no longer needs to import
/// from `features/vault/data/html_exporter.dart` directly (CA-04
/// carry-forward from M1747). The concrete implementation in
/// `lib/features/editor/data/repositories/html_export_repository_impl.dart`
/// delegates to the pre-existing `HtmlExporter.renderStandalonePage`
/// pure function, which already carries its own test coverage in the
/// vault feature.
// Single-method abstract is intentional: enables DI swap-out
// (RepositoryProvider in tests) without forcing the caller to take
// a typedef alias. CA-04 / RP-01 prefer named interfaces over
// function aliases for cross-feature injection points.
// ignore: one_member_abstracts
abstract class HtmlExportRepository {
  /// Render [body] (markdown) as a standalone HTML page titled [title]
  /// with the site CSS inlined and wikilinks downgraded to
  /// non-link pills. The result is byte-ready for `File.writeAsString`.
  String renderStandalonePage({
    required String title,
    required String body,
  });
}
