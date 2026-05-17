import 'package:my_notion/features/forms/domain/entities/form_bearing_page.dart';

/// E58b — domain interface for loading every form-bearing page out
/// of the Quill cache. The Settings → Forms pane's Cubit code
/// against this; the production impl
/// (`DriftFormBearingPagesRepository`) lives in `data/repositories/`
/// and queries the local Drift `pages` table. Tests substitute a
/// mocktail mock or a hand-rolled fake.
// ignore: one_member_abstracts
abstract class FormBearingPagesRepository {
  /// Returns every form-bearing page in the cache, sorted
  /// alphabetically by title (case-insensitive). Throws
  /// [FormBearingPagesLoadException] when the underlying store is
  /// unreachable or malformed beyond per-row recovery.
  Future<List<FormBearingPage>> loadAll();
}

/// Typed exception for repo-level load failures. Wraps the
/// underlying Drift / sqlite3 exception's message; per-row JSON
/// parse errors are silently skipped inside the impl (one bad row
/// shouldn't break the whole load) so this only fires on
/// catastrophic failures.
class FormBearingPagesLoadException implements Exception {
  const FormBearingPagesLoadException(this.message);
  final String message;
  @override
  String toString() => 'FormBearingPagesLoadException: $message';
}
