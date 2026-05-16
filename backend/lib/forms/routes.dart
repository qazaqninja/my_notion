import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

/// Repository contract for form-definition lookups + submission storage.
/// Slice E46 ships only the abstract interface plus a default impl that
/// always returns no-form-definition; future slices fill in the actual
/// `.database.yaml`-walking lookup + Postgres row insert.
///
/// The interface lives here (not under `lib/db/`) because the rest of
/// the forms feature will sit in this folder — single-feature surface,
/// not a generic DB concern.
abstract class FormsRepositoryBase {
  /// True when [ulid] resolves to a page that declares a form definition
  /// in its frontmatter (`forms:`) AND that form's target database is
  /// currently writable.
  Future<bool> hasFormDefinition(String ulid);
}

/// Default no-form-definition repo. Used by E46 to honor the "every
/// submit 404s until a real definition shows up" contract.
class NoFormsRepository implements FormsRepositoryBase {
  const NoFormsRepository();
  @override
  Future<bool> hasFormDefinition(String ulid) async => false;
}

/// Concrete repo backed by Postgres. E47 wires the lookup against
/// `vault_files` — a page is form-bearing iff it's public AND its
/// frontmatter declared a non-empty `forms:` value (the
/// `FrontmatterProbe` sets `has_forms = true` on upsert).
class FormsRepository implements FormsRepositoryBase {
  const FormsRepository(this._conn);
  final Connection _conn;

  @override
  Future<bool> hasFormDefinition(String ulid) async {
    final rows = await _conn.execute(
      Sql.named('''
        SELECT 1 FROM vault_files
        WHERE ulid = @ulid AND is_public = true AND has_forms = true
        LIMIT 1
      '''),
      parameters: {'ulid': ulid},
    );
    return rows.isNotEmpty;
  }
}

/// Public forms surface — Phase E E56+ scaffold (E46 / M1349).
///
/// Routes:
///   - `POST /forms/<ulid>/submit` — receives an `application/x-www-form-
///     urlencoded` submission targeted at the form definition embedded
///     in the page at `<ulid>`. The current contract is:
///       - 404 `not_found` when the ULID is malformed.
///       - 404 `no_form_definition` when no page declares this form
///         (the slice E46 default — the repo always returns false).
///       - Future slices will add: 422 on schema-validation failure,
///         303 redirect to a confirmation page on success.
///
/// Why "shape first, behavior later":
///   - The Flutter client (form designer + share button) is going to be
///     built against this URL pattern. Locking it in first means the
///     designer can render a working `<form action="…">`.
///   - The 404 is the right answer until any page actually carries a
///     `forms:` definition.
///   - Tests for the contract are cheap to write now and pin down the
///     wire format before the implementation drifts.
Router buildFormsRouter({required FormsRepositoryBase repo}) {
  final router = Router();

  router.post('/<ulid>/submit', (Request req) async {
    final ulid = req.params['ulid'];
    if (ulid == null || !_isUlid(ulid)) {
      return Response(404, body: 'not_found');
    }
    if (!await repo.hasFormDefinition(ulid)) {
      return Response(404, body: 'no_form_definition');
    }
    // Unreachable under E46 (NoFormsRepository always returns false).
    // E47 fills in the schema-validation + row-insert flow.
    return Response(501, body: 'not_implemented');
  });

  return router;
}

bool _isUlid(String s) =>
    RegExp(r'^[0-9A-HJKMNP-TV-Z]{26}$').hasMatch(s);
