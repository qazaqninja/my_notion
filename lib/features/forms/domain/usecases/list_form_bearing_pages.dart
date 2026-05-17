// Cross-feature domain→domain dep: forms reads vault's stable
// Page value type. Same pattern as relations/domain/usecases/
// search_pages.dart — acceptable per CA-* precedent (M1409 audit).
import 'package:my_notion/features/forms/domain/entities/form_bearing_page.dart';
import 'package:my_notion/features/vault/domain/entities/page.dart' as pg;

// FormBearingPage was promoted to features/forms/domain/entities/
// in M1413 (CA-05 — two production consumers now: this in-memory
// usecase + the Drift-backed FormBearingPagesRepository). Re-
// exported here so existing callers don't break.
export 'package:my_notion/features/forms/domain/entities/form_bearing_page.dart'
    show FormBearingPage;

/// Filter + project [pages] down to the ones that declare a
/// non-empty `forms:` frontmatter entry. Mirrors the
/// `_hasForms` predicate already used by editor_page.dart and the
/// backend's `FrontmatterProbe.hasForms` rule — keeps client and
/// server views of "form-bearing" in lockstep.
///
/// Result is sorted alphabetically by title (case-insensitive) so
/// the Settings pane has a predictable order across vault scans.
List<FormBearingPage> listFormBearingPages(Iterable<pg.Page> pages) {
  final out = <FormBearingPage>[];
  for (final p in pages) {
    final v = p.frontmatter.get('forms');
    if (v == null) continue;
    final s = '$v'.trim();
    if (s.isEmpty) continue;
    out.add(FormBearingPage(
      ulid: p.ulid,
      title: p.title,
      relativePath: p.relativePath,
      formsRef: s,
    ));
  }
  out.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  return out;
}
