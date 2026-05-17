import 'dart:convert';

import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:ulid/ulid.dart';

import 'package:backend/auth/middleware.dart';
import 'package:backend/db/exceptions.dart';
import 'package:backend/sync/frontmatter_probe.dart';
import 'package:backend/forms/form_schema.dart';
import 'package:backend/forms/render_form_html.dart';

/// Repository contract for form-definition lookups + submission storage.
/// Slice E46 ships only the abstract interface plus a default impl that
/// always returns no-form-definition; E48 adds the submission insert.
///
/// The interface lives here (not under `lib/db/`) because the rest of
/// the forms feature will sit in this folder — single-feature surface,
/// not a generic DB concern.
abstract class FormsRepositoryBase {
  /// True when [ulid] resolves to a page that declares a form definition
  /// in its frontmatter (`forms:`) AND that form's target database is
  /// currently writable.
  Future<bool> hasFormDefinition(String ulid);

  /// F5 — resolve the schema linked from the form-bearing page at
  /// [ulid]. Returns:
  ///   - `null` when the page doesn't exist or isn't form-bearing
  ///     (route uses this as a 404 indicator, same shape as
  ///     `hasFormDefinition` returning false).
  ///   - `FormSchema.empty` when the page is form-bearing but has no
  ///     resolvable `forms:` ref (e.g. `forms: true`) OR the linked
  ///     `.database.yaml` isn't in the user's vault_files. Legacy
  ///     "any non-empty body" submissions land in this branch.
  ///   - The parsed schema otherwise.
  Future<FormSchema?> loadSchemaFor(String ulid);

  /// E48 — record a submission for the form at [pageUlid]. [fields] is
  /// the (possibly schema-coerced) form payload — F5 widened from
  /// `Map<String, String>` to `Map<String, Object?>` so checkbox
  /// booleans and number ints land in JSONB as native types.
  /// Returns the generated submission ID.
  Future<String> insertSubmission({
    required String pageUlid,
    required Map<String, Object?> fields,
    String? sourceIp,
  });

  /// E49 — list submissions for [pageUlid] on behalf of [userId].
  ///
  /// Returns `null` when the page exists but is not owned by [userId]
  /// (route layer maps that to 403). Returns an empty list when the
  /// page exists and the caller owns it but no submissions have come
  /// in yet. Returns `null` when the page is missing entirely — the
  /// caller can't distinguish "missing" from "not owned" by design
  /// (avoids leaking which ULIDs exist).
  Future<List<FormSubmission>?> listSubmissionsFor({
    required String userId,
    required String pageUlid,
  });
}

/// Single row from `form_submissions`. Equatable not used — these
/// aren't compared in any state machine; the route layer just maps
/// them to JSON.
class FormSubmission {
  const FormSubmission({
    required this.id,
    required this.pageUlid,
    required this.fields,
    required this.createdAt,
    this.sourceIp,
  });
  final String id;
  final String pageUlid;
  final Map<String, dynamic> fields;
  final DateTime createdAt;
  final String? sourceIp;

  Map<String, dynamic> toJson() => {
        'id': id,
        'page_ulid': pageUlid,
        'fields': fields,
        'created_at': createdAt.toIso8601String(),
        if (sourceIp != null) 'source_ip': sourceIp,
      };
}

/// Default no-form-definition repo. Used by E46 to honor the "every
/// submit 404s until a real definition shows up" contract. E48
/// implements `insertSubmission` as an unreachable error because the
/// route guards on `hasFormDefinition` first.
class NoFormsRepository implements FormsRepositoryBase {
  const NoFormsRepository();
  @override
  Future<bool> hasFormDefinition(String ulid) async => false;
  @override
  Future<String> insertSubmission({
    required String pageUlid,
    required Map<String, Object?> fields,
    String? sourceIp,
  }) async {
    throw StateError(
      'NoFormsRepository.insertSubmission called — '
      'route guard on hasFormDefinition should have prevented this',
    );
  }

  @override
  Future<List<FormSubmission>?> listSubmissionsFor({
    required String userId,
    required String pageUlid,
  }) async =>
      null;

  @override
  Future<FormSchema?> loadSchemaFor(String ulid) async => null;
}

/// Concrete repo backed by Postgres. E47 wires the lookup against
/// `vault_files` — a page is form-bearing iff it's public AND its
/// frontmatter declared a non-empty `forms:` value (the
/// `FrontmatterProbe` sets `has_forms = true` on upsert). E48 adds the
/// `form_submissions` row insert.
class FormsRepository implements FormsRepositoryBase {
  const FormsRepository(this._conn);
  final Connection _conn;

  @override
  Future<bool> hasFormDefinition(String ulid) async => runDb(
        op: 'hasFormDefinition',
        () async {
          final rows = await _conn.execute(
            Sql.named('''
              SELECT 1 FROM vault_files
              WHERE ulid = @ulid AND is_public = true AND has_forms = true
              LIMIT 1
            '''),
            parameters: {'ulid': ulid},
          );
          return rows.isNotEmpty;
        },
      );

  @override
  Future<String> insertSubmission({
    required String pageUlid,
    required Map<String, Object?> fields,
    String? sourceIp,
  }) async =>
      runDb(op: 'insertSubmission', () async {
        final id = Ulid().toString();
        await _conn.execute(
          Sql.named('''
            INSERT INTO form_submissions (id, page_ulid, fields, source_ip)
            VALUES (@id, @page, @fields, @ip)
          '''),
          parameters: {
            'id': id,
            'page': pageUlid,
            // JSONB column: pass the JSON string; postgres adapter
            // handles the conversion.
            'fields': jsonEncode(fields),
            'ip': sourceIp,
          },
        );
        return id;
      });

  @override
  Future<FormSchema?> loadSchemaFor(String ulid) async => runDb(
        op: 'loadSchemaFor',
        () async {
          // 1. Find the form-bearing page and (a) confirm it's still
          //    is_public + has_forms, (b) get its body so we can probe
          //    the `forms:` ref, (c) get user_id so the linked
          //    .database.yaml lookup stays scoped to the same vault.
          final pageRows = await _conn.execute(
            Sql.named('''
              SELECT body, user_id FROM vault_files
              WHERE ulid = @ulid AND is_public = true AND has_forms = true
              LIMIT 1
            '''),
            parameters: {'ulid': ulid},
          );
          if (pageRows.isEmpty) return null;
          final pageBody = pageRows.first[0]! as String;
          final userId = pageRows.first[1]! as String;
          final probe = FrontmatterProbe.fromBody(pageBody);
          final ref = probe.formsRef;
          // Bare `forms: true` (no ref) → empty schema, legacy fallback.
          if (ref == null) return FormSchema.empty;
          // 2. Look up the linked schema file in the same user's vault.
          //    Forward-slashes are how the Flutter side serializes relpaths.
          final schemaRows = await _conn.execute(
            Sql.named('''
              SELECT body FROM vault_files
              WHERE user_id = @uid AND relpath = @rel
              LIMIT 1
            '''),
            parameters: {'uid': userId, 'rel': ref},
          );
          if (schemaRows.isEmpty) {
            // Page references a schema file that isn't synced yet —
            // fall back to empty schema rather than blocking submissions.
            return FormSchema.empty;
          }
          final schemaBody = schemaRows.first[0]! as String;
          return parseFormSchema(schemaBody);
        },
      );

  @override
  Future<List<FormSubmission>?> listSubmissionsFor({
    required String userId,
    required String pageUlid,
  }) async =>
      runDb(op: 'listSubmissionsFor', () async {
        // Verify ownership before reading any submission rows. The join
        // against vault_files lets us answer "owns this page?" in one
        // round-trip; we deliberately don't distinguish "page missing"
        // from "not owner" in the response (the route maps both to 403)
        // so visitors can't enumerate ULIDs.
        final ownerCheck = await _conn.execute(
          Sql.named('''
            SELECT 1 FROM vault_files
            WHERE ulid = @ulid AND user_id = @uid
            LIMIT 1
          '''),
          parameters: {'ulid': pageUlid, 'uid': userId},
        );
        if (ownerCheck.isEmpty) return null;
        final rows = await _conn.execute(
          Sql.named('''
            SELECT id, page_ulid, fields, source_ip, created_at
            FROM form_submissions
            WHERE page_ulid = @ulid
            ORDER BY created_at DESC
          '''),
          parameters: {'ulid': pageUlid},
        );
        return rows
            .map((r) => FormSubmission(
                  id: r[0]! as String,
                  pageUlid: r[1]! as String,
                  // `fields` comes back as JSONB; postgres adapter decodes
                  // to a Dart Map when the column type is jsonb.
                  fields: (r[2] is String)
                      ? jsonDecode(r[2]! as String) as Map<String, dynamic>
                      : (r[2]! as Map).cast<String, dynamic>(),
                  sourceIp: r[3] as String?,
                  createdAt: r[4]! as DateTime,
                ))
            .toList();
      });
}

/// Maximum form-body size accepted by `POST /forms/<ulid>/submit`.
/// Anything larger gets a 413 rather than being parsed. 32 KB is
/// generous for typical contact-form / RSVP shapes and small enough to
/// keep an abusive payload from holding the event loop.
const int _kMaxFormBodyBytes = 32 * 1024;

/// Public forms surface — Phase E E56+ scaffold (E46 / M1349 / M1351).
///
/// Routes:
///   - `POST /forms/<ulid>/submit` — receives an `application/x-www-form-
///     urlencoded` submission targeted at the form definition embedded
///     in the page at `<ulid>`. Response matrix:
///       - 404 `not_found` when the ULID is malformed.
///       - 404 `no_form_definition` when no page declares this form.
///       - 413 `body_too_large` when the payload exceeds 32 KB.
///       - 400 `empty_body` when the request carries no fields.
///       - 303 redirect to a confirmation page on success, with the
///         generated submission ID in the URL.
///       - (Future) 422 on schema-mismatch once per-field validation
///         lands.
///
/// E48 narrows the route from "shape-only" to "fully writes a row".
/// Per-field schema validation against the page's `.database.yaml` is
/// still future work — for now any non-empty form-urlencoded body is
/// accepted and recorded as `fields JSONB`.
Router buildFormsRouter({required FormsRepositoryBase repo}) {
  final router = Router();

  router.post('/<ulid>/submit', (Request req) => _handleSubmit(req, repo));

  // E56b — public form page. Renders the HTML form a visitor fills
  // out before posting back to `/forms/<ulid>/submit`. The schema is
  // resolved via FormsRepositoryBase.loadSchemaFor; a null result
  // means the page doesn't exist or isn't form-bearing (404). A
  // non-null result — including FormSchema.empty — gets a 200 with
  // the rendered HTML so the legacy "any non-empty body" fallback
  // still shows a usable skeleton.
  router.get('/<ulid>', (Request req) async {
    final ulid = req.params['ulid'];
    if (ulid == null || !_isUlid(ulid)) {
      return Response(404, body: 'not_found');
    }
    final schema = await repo.loadSchemaFor(ulid);
    if (schema == null) {
      return Response(404, body: 'no_form_definition');
    }
    return Response.ok(
      renderFormHtml(ulid: ulid, schema: schema),
      headers: const {'content-type': 'text/html; charset=utf-8'},
    );
  });

  router.get('/<ulid>/thanks', (Request req) async {
    final ulid = req.params['ulid'];
    if (ulid == null || !_isUlid(ulid)) {
      return Response(404, body: 'not_found');
    }
    return Response.ok(
      _renderThanksHtml(),
      headers: const {'content-type': 'text/html; charset=utf-8'},
    );
  });

  return router;
}

Future<Response> _handleSubmit(
    Request req, FormsRepositoryBase repo) async {
  final ulid = req.params['ulid'];
  if (ulid == null || !_isUlid(ulid)) {
    return Response(404, body: 'not_found');
  }
  if (!await repo.hasFormDefinition(ulid)) {
    return Response(404, body: 'no_form_definition');
  }
  // Defensive size cap. Content-Length is advisory; we still cap on
  // the actual read to defend against chunked encodings that lie.
  final cl = req.contentLength;
  if (cl != null && cl > _kMaxFormBodyBytes) {
    return Response(413, body: 'body_too_large');
  }
  final raw = await req.readAsString();
  if (raw.length > _kMaxFormBodyBytes) {
    return Response(413, body: 'body_too_large');
  }
  final fields = parseUrlEncodedForm(raw);
  // Strip blank values — a flat `?foo=&bar=` shouldn't count as
  // a real submission.
  fields.removeWhere((_, v) => v.isEmpty);
  if (fields.isEmpty) {
    return Response(400, body: 'empty_body');
  }
  // F5: schema-aware validation. An empty schema (legacy "any
  // non-empty body" fallback) lets `fields` through unchanged.
  final schema = await repo.loadSchemaFor(ulid);
  final Map<String, Object?> toStore;
  if (schema != null) {
    final result = validateSubmission(schema, fields);
    if (!result.isValid) {
      return Response(
        422,
        body: jsonEncode({
          'error': 'validation_failed',
          'errors': result.errors,
        }),
        headers: const {'content-type': 'application/json'},
      );
    }
    toStore = result.normalized;
    // Coerced map may be empty if schema fields were all optional
    // and the submission only carried out-of-schema keys.
    if (toStore.isEmpty) {
      return Response(400, body: 'empty_body');
    }
  } else {
    toStore = Map<String, Object?>.from(fields);
  }
  final id = await repo.insertSubmission(
    pageUlid: ulid,
    fields: toStore,
    sourceIp: _sourceIp(req),
  );
  return Response(
    303,
    headers: {'location': '/forms/$ulid/thanks?id=$id'},
  );
}

/// E49 — owner-facing forms routes. Mounted at `/forms/owner/` behind
/// the standard `requireAuth` middleware so handlers can read the
/// authed `User` from `currentUser(request)`.
///
/// Routes:
///   - `GET /forms/owner/<ulid>/submissions` — JSON list of submissions
///     for [ulid]. Returns 403 `not_owner` when the caller doesn't own
///     the page (also when the page doesn't exist — by design, no ULID
///     enumeration). Returns `{"submissions": [...]}` on success.
Router buildOwnerFormsRouter({required FormsRepositoryBase repo}) {
  final router = Router();

  router.get('/<ulid>/submissions', (Request req) async {
    final ulid = req.params['ulid'];
    if (ulid == null || !_isUlid(ulid)) {
      return Response(
        404,
        body: jsonEncode({'error': 'not_found'}),
        headers: const {'content-type': 'application/json'},
      );
    }
    final user = currentUser(req);
    final submissions = await repo.listSubmissionsFor(
      userId: user.id,
      pageUlid: ulid,
    );
    if (submissions == null) {
      return Response(
        403,
        body: jsonEncode({'error': 'not_owner'}),
        headers: const {'content-type': 'application/json'},
      );
    }
    return Response.ok(
      jsonEncode({
        'submissions': submissions.map((s) => s.toJson()).toList(),
      }),
      headers: const {'content-type': 'application/json'},
    );
  });

  return router;
}

/// Parse an `application/x-www-form-urlencoded` body into a flat map.
/// Repeated keys join with `,` so a multi-select checkbox group
/// (M1482 FormFieldType.multi) submits as `tag=a&tag=b&tag=c` and
/// surfaces as a single `'a,b,c'` value here. Single-value fields
/// (text, number, date, etc.) post the key exactly once, so this
/// degrades gracefully — no observable change for existing
/// callers. validateSubmission for `multi` splits on `,` and
/// validates each value against `field.options`.
///
/// Public (was `_parseForm`) so its repeated-key contract can be
/// unit-tested directly without standing up a route handler —
/// M1483 closes the orchestrator's M1482 TS-01 gap.
Map<String, String> parseUrlEncodedForm(String body) {
  final out = <String, String>{};
  for (final pair in body.split('&')) {
    if (pair.isEmpty) continue;
    final idx = pair.indexOf('=');
    if (idx < 0) continue;
    try {
      final key = Uri.decodeQueryComponent(pair.substring(0, idx));
      final value = Uri.decodeQueryComponent(pair.substring(idx + 1));
      if (key.isEmpty) continue;
      final prior = out[key];
      out[key] = prior == null ? value : '$prior,$value';
    } on ArgumentError {
      // `Uri.decodeQueryComponent` throws ArgumentError on invalid
      // percent-encoding. Skip the offending pair rather than 500ing.
      continue;
    } on FormatException {
      continue;
    }
  }
  return out;
}

/// Best-effort source IP — shelf's `shelf.io.connection_info` is set
/// by `shelf_io.serve`; in tests where the handler is invoked
/// directly the key is absent. Reverse-proxy `X-Forwarded-For` is
/// considered too if present.
String? _sourceIp(Request req) {
  final xff = req.headers['x-forwarded-for'];
  if (xff != null && xff.isNotEmpty) {
    return xff.split(',').first.trim();
  }
  final info = req.context['shelf.io.connection_info'];
  return info?.toString();
}

String _renderThanksHtml() {
  return '<!doctype html><meta charset="utf-8">'
      '<title>Thanks!</title>'
      '<meta name="viewport" content="width=device-width,initial-scale=1">'
      '<style>'
      'body{font-family:system-ui,-apple-system,sans-serif;'
      'max-width:520px;margin:5rem auto;padding:0 1rem;line-height:1.55;'
      'color:#222;background:#fff;text-align:center}'
      'h1{font-size:1.5rem;font-weight:600;margin:0 0 .25em}'
      'p{color:#666;margin:0}'
      '@media (prefers-color-scheme:dark){'
      'body{color:#e6e6e6;background:#0e0e10}'
      'p{color:#999}'
      '}'
      '</style>'
      '<h1>Thanks!</h1>'
      '<p>Your submission was recorded.</p>';
}

bool _isUlid(String s) =>
    RegExp(r'^[0-9A-HJKMNP-TV-Z]{26}$').hasMatch(s);
