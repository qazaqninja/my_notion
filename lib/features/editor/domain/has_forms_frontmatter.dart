import '../../vault/domain/entities/frontmatter.dart';

/// Returns true when [frontmatter] declares a `forms:` field with a
/// non-empty (post-trim) value. Mirrors the legacy `_hasForms`
/// predicate and the backend `FrontmatterProbe.hasForms` rule so
/// the kebab "View form
/// submissions →" entry only renders when the server would accept the
/// list-submissions request — otherwise the click resolves to a 403 /
/// not-owner.
///
/// Pulled into the domain layer at M1741 so the
/// EditorBetaAppBarAction.viewFormSubmissions gating is unit-testable
/// without a widget tree (D-fp19 port).
bool hasFormsFrontmatter(Frontmatter frontmatter) {
  final v = frontmatter.get('forms');
  if (v == null) return false;
  return '$v'.trim().isNotEmpty;
}
