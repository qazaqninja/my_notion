import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

/// Public read-only access surface. Mounted at `/public/` with NO
/// authentication so anyone with a ULID can read a page IF the owner
/// has flagged it `public: true` in frontmatter.
///
/// Route: `GET /public/<ulid>`
///   - 404 if the ULID doesn't exist or `is_public = false`.
///   - 200 with HTML body otherwise.
///
/// The HTML rendering is intentionally minimal in slice E16 — wraps
/// the raw markdown in `<pre>` so the source is human-readable.
/// Slice E17+ will swap in a real markdown→HTML pass that reuses the
/// existing client-side `HtmlExporter` once it's portable to the
/// server.
Router buildPublicRouter({required Connection conn}) {
  final router = Router();

  router.get('/<ulid>', (Request req) async {
    final ulid = req.params['ulid'];
    if (ulid == null || !_isUlid(ulid)) {
      return Response(404, body: 'not_found');
    }
    final rows = await conn.execute(
      Sql.named('''
        SELECT body FROM vault_files
        WHERE ulid = @ulid AND is_public = true
        LIMIT 1
      '''),
      parameters: {'ulid': ulid},
    );
    if (rows.isEmpty) {
      return Response(404, body: 'not_found');
    }
    final body = rows.first[0] as String;
    return Response.ok(
      _renderHtml(body),
      headers: const {'content-type': 'text/html; charset=utf-8'},
    );
  });

  return router;
}

bool _isUlid(String s) =>
    RegExp(r'^[0-9A-HJKMNP-TV-Z]{26}$').hasMatch(s);

/// Minimal HTML wrap. Slice E17 will swap in real markdown rendering.
String _renderHtml(String body) {
  final escaped = body
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
  return '<!doctype html><meta charset="utf-8">'
      '<title>Quill public page</title>'
      '<style>body{font-family:system-ui;max-width:760px;margin:2rem auto;padding:0 1rem}'
      'pre{white-space:pre-wrap;font-family:inherit;line-height:1.55}</style>'
      '<pre>$escaped</pre>';
}
