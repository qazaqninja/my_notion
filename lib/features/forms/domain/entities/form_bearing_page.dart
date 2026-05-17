import 'package:equatable/equatable.dart';

/// E58 — projection over a form-bearing page for the Settings →
/// Forms pane. Pure value type; two production consumers today:
/// the in-memory `listFormBearingPages` usecase (M1409) and the
/// Drift-backed `FormBearingPagesRepository` (M1412). Promoted to
/// `domain/entities/` from `domain/usecases/` in M1413 once the
/// second consumer appeared (CA-05 fix-forward).
///
/// Equatable used so the Settings pane's Cubit can put
/// `List<FormBearingPage>` into state without identity-comparison
/// surprises (BL-06).
class FormBearingPage extends Equatable {
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

  @override
  List<Object?> get props => [ulid, title, relativePath, formsRef];
}
