import 'package:my_notion/features/vault/domain/entities/page.dart' as pg;

/// E58 — projection over [pg.Page] for the Settings → Forms pane.
/// One entry per form-bearing page (frontmatter `forms:` set to a
/// non-empty value), carrying the row's title + relative path so
/// the UI can render a list without holding a reference to the
/// full Page object.
///
/// Equatable is intentionally NOT used — these aren't compared in
/// any state machine; the pane just maps them straight into list
/// tiles.
class FormBearingPage {
  const FormBearingPage({
    required this.ulid,
    required this.title,
    required this.relativePath,
    required this.formsRef,
  });

  /// Page ULID. Drives the link into the existing
  /// FormSubmissionsDialog (E51) when the row is tapped.
  final String ulid;

  /// Display title — either `frontmatter['title']` or derived from
  /// the filename (already resolved on the Page entity).
  final String title;

  /// Path relative to vault root, e.g. `Operations/Bug reports.md`.
  /// Shown beneath the title so users can disambiguate identically-
  /// titled pages.
  final String relativePath;

  /// Raw `forms:` value as it appears in frontmatter. Today this
  /// is either `'true'` (form-bearing without a typed schema) or
  /// the path to a linked `.database.yaml` file. The Settings pane
  /// can surface this as a secondary line ("→ Bugs.database.yaml")
  /// to help authors orient.
  final String formsRef;
}

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
