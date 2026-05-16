import 'dart:convert';

import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:ulid/ulid.dart';

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

  /// E48 — record a submission for the form at [pageUlid]. [fields] is
  /// the parsed form payload (one entry per text input on the page).
  /// Returns the generated submission ID.
  Future<String> insertSubmission({
    required String pageUlid,
    required Map<String, String> fields,
    String? sourceIp,
  });
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
    required Map<String, String> fields,
    String? sourceIp,
  }) async {
    throw StateError(
      'NoFormsRepository.insertSubmission called — '
      'route guard on hasFormDefinition should have prevented this',
    );
  }
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

  @override
  Future<String> insertSubmission({
    required String pageUlid,
    required Map<String, String> fields,
    String? sourceIp,
  }) async {
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
  }
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

  router.post('/<ulid>/submit', (Request req) async {
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
    final fields = _parseForm(raw);
    // Strip blank values — a flat `?foo=&bar=` shouldn't count as
    // a real submission.
    fields.removeWhere((_, v) => v.isEmpty);
    if (fields.isEmpty) {
      return Response(400, body: 'empty_body');
    }
    final id = await repo.insertSubmission(
      pageUlid: ulid,
      fields: fields,
      sourceIp: _sourceIp(req),
    );
    return Response(
      303,
      headers: {'location': '/forms/$ulid/thanks?id=$id'},
    );
  });

  // Submission landing — minimal "Thanks!" page so the 303 doesn't
  // dump the user on a blank tab.
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

/// Parse an `application/x-www-form-urlencoded` body into a flat map.
/// Repeated keys collapse to the last value (forms typically don't
/// use repeats; checkbox groups carry a single comma-joined value).
Map<String, String> _parseForm(String body) {
  final out = <String, String>{};
  for (final pair in body.split('&')) {
    if (pair.isEmpty) continue;
    final idx = pair.indexOf('=');
    if (idx < 0) continue;
    try {
      final key = Uri.decodeQueryComponent(pair.substring(0, idx));
      final value = Uri.decodeQueryComponent(pair.substring(idx + 1));
      if (key.isEmpty) continue;
      out[key] = value;
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
