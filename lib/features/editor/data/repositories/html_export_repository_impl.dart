import '../../../vault/data/html_exporter.dart';
import '../../domain/repositories/html_export_repository.dart';

/// Thin adapter that exposes the pure-function
/// [HtmlExporter.renderStandalonePage] (vault/data) through the
/// editor-domain [HtmlExportRepository] interface. Lets the editor
/// presentation layer consume the renderer without crossing the
/// `editor/` → `vault/data/` feature-boundary that CA-04 forbids.
class HtmlExportRepositoryImpl implements HtmlExportRepository {
  const HtmlExportRepositoryImpl();

  @override
  String renderStandalonePage({
    required String title,
    required String body,
  }) {
    return HtmlExporter.renderStandalonePage(title: title, body: body);
  }
}
