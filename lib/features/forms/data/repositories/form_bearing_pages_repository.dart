import 'dart:convert';

import 'package:my_notion/core/db/quill_database.dart';
import 'package:my_notion/features/forms/domain/usecases/list_form_bearing_pages.dart';

/// E58b — data layer for the Settings → Forms pane. Loads every
/// form-bearing page out of the Drift cache, parses each row's
/// JSON-encoded frontmatter for the `forms:` value, and projects
/// down to [FormBearingPage] via the same blank/whitespace +
/// alphabetical-sort rules as the in-memory `listFormBearingPages`
/// usecase (M1409). Keeps client + server views of "form-bearing"
/// in lockstep with the backend's `FrontmatterProbe.hasForms`
/// rule.
///
/// Why this lives in `forms/data/repositories/` and not just calls
/// the pure usecase on a fetched `List<pg.Page>`: the indexer
/// stores frontmatter as a JSON string in the Drift cache, NOT as
/// the full `Frontmatter` entity. Reconstructing `pg.Page` values
/// just to feed the pure filter would mean re-parsing every row's
/// raw markdown via FrontmatterParser, which is heavy work the
/// pane doesn't need — it only cares about the `forms:` value.
/// Reading `frontmatter_json` directly skips that round trip.
class FormBearingPagesRepository {
  FormBearingPagesRepository(this._db);

  final QuillDatabase _db;

  /// Returns every form-bearing page in the cache, sorted
  /// alphabetically by title (case-insensitive). Drift query is
  /// unfiltered — Dart-side projection keeps the JSON parsing
  /// honest (a SQL `LIKE '%forms%'` filter would miss escaped
  /// values and produce false positives).
  Future<List<FormBearingPage>> loadAll() async {
    final rows = await _db.select(_db.pages).get();
    final out = <FormBearingPage>[];
    for (final r in rows) {
      final ref = _extractFormsRef(r.frontmatterJson);
      if (ref == null) continue;
      out.add(FormBearingPage(
        ulid: r.ulid,
        title: r.title,
        relativePath: r.relativePath,
        formsRef: ref,
      ));
    }
    out.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return out;
  }

  /// Returns the trimmed `forms:` value when the row's frontmatter
  /// declares a non-blank one, null otherwise. Defensive against
  /// malformed JSON: a row whose `frontmatter_json` doesn't parse
  /// is silently skipped — one bad row shouldn't fail the whole
  /// pane load.
  String? _extractFormsRef(String frontmatterJson) {
    Object? decoded;
    try {
      decoded = jsonDecode(frontmatterJson);
    } catch (_) {
      return null;
    }
    if (decoded is! Map<String, dynamic>) return null;
    final v = decoded['forms'];
    if (v == null) return null;
    final s = '$v'.trim();
    return s.isEmpty ? null : s;
  }
}
