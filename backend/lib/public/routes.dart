import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'markdown_html.dart';

/// Public read-only access surface. Mounted at `/public/` with NO
/// authentication so anyone with a ULID can read a page IF the owner
/// has flagged it `public: true` in frontmatter.
///
/// Route: `GET /public/<ulid>`
///   - 404 if the ULID doesn't exist or `is_public = false`.
///   - 200 with rendered HTML body otherwise.
///
/// E21: rendering goes through `MarkdownHtmlRenderer` — block-aware
/// markdown → HTML pass with HTML escaping baked in. Wikilinks render
/// as plain text so a public page doesn't leak arbitrary cross-vault
/// IDs as clickable URLs.
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

/// Full HTML document wrap around the rendered markdown body. Style is
/// intentionally minimal so the page reads cleanly in light + dark and
/// loads fast (no external assets, no JS).
String _renderHtml(String markdown) {
  final article = MarkdownHtmlRenderer.render(markdown);
  return '<!doctype html><meta charset="utf-8">'
      '<title>Quill public page</title>'
      '<meta name="viewport" content="width=device-width,initial-scale=1">'
      '<style>'
      'body{font-family:system-ui,-apple-system,sans-serif;'
      'max-width:760px;margin:2rem auto;padding:0 1rem;line-height:1.55;'
      'color:#222;background:#fff}'
      'h1,h2,h3{line-height:1.2;margin-top:1.4em}'
      'pre{background:#f6f8fa;padding:.8em;overflow:auto;border-radius:4px}'
      'code{font-family:ui-monospace,Menlo,monospace;font-size:.95em}'
      'blockquote{border-left:3px solid #ddd;margin:1em 0;padding:.25em 0 .25em 1em;color:#555}'
      'a{color:#3071a9}'
      'img{max-width:100%;height:auto}'
      'hr{border:0;border-top:1px solid #eee;margin:2em 0}'
      '@media (prefers-color-scheme:dark){'
      'body{color:#e6e6e6;background:#0e0e10}'
      'pre{background:#1b1b1f}'
      'blockquote{border-left-color:#555;color:#aaa}'
      'a{color:#7faedb}'
      'hr{border-top-color:#222}'
      '}'
      '</style>'
      '<article>$article</article>';
}
