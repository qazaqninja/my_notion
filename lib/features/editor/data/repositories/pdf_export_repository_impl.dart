import '../../../vault/data/pdf_exporter.dart';
import '../../domain/repositories/pdf_export_repository.dart';

/// Thin adapter that exposes the pre-existing
/// [PdfExporter.exportSingle] (vault/data) through the editor-domain
/// [PdfExportRepository] interface. Lets the editor presentation
/// layer consume the renderer without crossing the
/// `editor/` → `vault/data/` feature-boundary that CA-04 forbids.
class PdfExportRepositoryImpl implements PdfExportRepository {
  const PdfExportRepositoryImpl();

  @override
  Future<List<int>> renderPdf({
    required String title,
    required String body,
  }) {
    return const PdfExporter().exportSingle(title: title, body: body);
  }
}
