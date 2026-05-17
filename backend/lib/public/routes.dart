// File contains HTML/CSS template renderers (`_renderUnlockForm`,
// `_renderHtml`) — adjacent string literals are concatenated to
// assemble template output without semantically meaningful
// whitespace. The missing_whitespace_between_adjacent_strings lint
// flags every line of those templates; the rule doesn't apply to
// this idiom.
// ignore_for_file: missing_whitespace_between_adjacent_strings

import 'package:backend/public/markdown_html.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

/// Public read-only access surface. Mounted at `/public/` with NO
/// authentication so anyone with a ULID can read a page IF the owner
/// has flagged it `public: true` in frontmatter.
///
/// Routes:
///   - `GET /public/<ulid>` — 404 if the ULID doesn't exist or
///     `is_public = false`. If the page also has a non-null
///     `public_password_hash`, returns the unlock-form HTML unless the
///     visitor presents a valid `quill_unlock_<ulid>` cookie (E43).
///     Otherwise 200 with the rendered HTML.
///   - `POST /public/<ulid>/unlock` — accepts a `password=…` form
///     field, bcrypt-checks against the stored hash, sets the unlock
///     cookie on success, returns 303 redirect to `/public/<ulid>`.
///
/// E21: rendering goes through `MarkdownHtmlRenderer` — block-aware
/// markdown → HTML pass with HTML escaping baked in. Wikilinks render
/// as plain text so a public page doesn't leak arbitrary cross-vault
/// IDs as clickable URLs.
Router buildPublicRouter({required Connection conn}) {
  return Router()
    ..get('/<ulid>', (Request req) async {
    final ulid = req.params['ulid'];
    if (ulid == null || !_isUlid(ulid)) {
      return Response(404, body: 'not_found');
    }
    final rows = await conn.execute(
      Sql.named('''
        SELECT body, public_password_hash FROM vault_files
        WHERE ulid = @ulid AND is_public = true
        LIMIT 1
      '''),
      parameters: {'ulid': ulid},
    );
    if (rows.isEmpty) {
      return Response(404, body: 'not_found');
    }
    final body = rows.first[0] as String;
    final hash = rows.first[1] as String?;
    // E43: if the page is password-protected, demand the unlock
    // cookie. The cookie is set on a successful POST to
    // /public/<ulid>/unlock and carries the bcrypt hash itself —
    // simple, stateless, and rotates when the owner re-publishes
    // with a new password (the cookie value won't match the new
    // hash so visitors are re-prompted).
    if (hash != null && !_hasUnlockCookie(req, ulid: ulid, hash: hash)) {
      return Response.ok(
        _renderUnlockForm(ulid),
        headers: const {'content-type': 'text/html; charset=utf-8'},
      );
    }
    return Response.ok(
      _renderHtml(body),
      headers: const {'content-type': 'text/html; charset=utf-8'},
    );
  })
    ..post('/<ulid>/unlock', (Request req) async {
    final ulid = req.params['ulid'];
    if (ulid == null || !_isUlid(ulid)) {
      return Response(404, body: 'not_found');
    }
    final rows = await conn.execute(
      Sql.named('''
        SELECT public_password_hash FROM vault_files
        WHERE ulid = @ulid AND is_public = true
        LIMIT 1
      '''),
      parameters: {'ulid': ulid},
    );
    if (rows.isEmpty) return Response(404, body: 'not_found');
    final hash = rows.first[0] as String?;
    if (hash == null) {
      // Page is public but not protected — pointless POST but harmless.
      return Response(303, headers: {'location': '/public/$ulid'});
    }
    final form = _parseForm(await req.readAsString());
    final password = form['password'];
    if (password == null ||
        password.isEmpty ||
        !BCrypt.checkpw(password, hash)) {
      // Re-render the form with an inline error.
      return Response(
        401,
        body: _renderUnlockForm(ulid, error: 'Incorrect password.'),
        headers: const {'content-type': 'text/html; charset=utf-8'},
      );
    }
    return Response(
      303,
      headers: {
        'location': '/public/$ulid',
        // Cookie carries the bcrypt hash; rotating the password on
        // the owner's side will mismatch the cookie and re-prompt.
        // HttpOnly + SameSite=Lax keeps it out of XSS-readable
        // surfaces and cross-site form posts.
        'set-cookie':
            'quill_unlock_$ulid=$hash; Path=/public/$ulid; '
            'HttpOnly; SameSite=Lax; Max-Age=2592000',
      },
    );
  });
}

/// True iff the request carries a `quill_unlock_<ulid>` cookie whose
/// value matches the stored password hash. Defends against the
/// stale-hash case: re-publishing with a new password rotates the
/// hash, the old cookie no longer matches, the visitor is re-prompted.
bool _hasUnlockCookie(
  Request req, {
  required String ulid,
  required String hash,
}) {
  final raw = req.headers['cookie'];
  if (raw == null) return false;
  final wanted = 'quill_unlock_$ulid';
  for (final pair in raw.split(';')) {
    final idx = pair.indexOf('=');
    if (idx <= 0) continue;
    final key = pair.substring(0, idx).trim();
    final value = pair.substring(idx + 1).trim();
    if (key == wanted && value == hash) return true;
  }
  return false;
}

/// Parse an `application/x-www-form-urlencoded` body into a flat map.
Map<String, String> _parseForm(String body) {
  final out = <String, String>{};
  for (final pair in body.split('&')) {
    if (pair.isEmpty) continue;
    final idx = pair.indexOf('=');
    if (idx < 0) continue;
    final key = Uri.decodeQueryComponent(pair.substring(0, idx));
    final value = Uri.decodeQueryComponent(pair.substring(idx + 1));
    out[key] = value;
  }
  return out;
}

/// Minimal unlock form. Inline-styled so it renders without external
/// assets; no JS. Inherits the same dark-mode media query as the main
/// page so it doesn't look out of place.
String _renderUnlockForm(String ulid, {String? error}) {
  // HTML-escape ulid even though we restrict it to the ULID charset
  // up the stack — defense in depth.
  final safeUlid = ulid.replaceAll('<', '&lt;').replaceAll('>', '&gt;');
  final errorBlock = error == null
      ? ''
      : '<p style="color:#c45c5c;margin:.5em 0">'
          '${error.replaceAll('<', '&lt;').replaceAll('>', '&gt;')}'
          '</p>';
  return '<!doctype html><meta charset="utf-8">'
      '<title>Quill public page — locked</title>'
      '<meta name="viewport" content="width=device-width,initial-scale=1">'
      '<style>'
      'body{font-family:system-ui,-apple-system,sans-serif;'
      'max-width:420px;margin:5rem auto;padding:0 1rem;line-height:1.55;'
      'color:#222;background:#fff}'
      'h1{font-size:1.25rem;font-weight:600;margin:0 0 .5em}'
      'p{color:#666;margin:0 0 1em}'
      'form{display:flex;gap:8px}'
      'input[type=password]{flex:1;padding:.5em;border:1px solid #ddd;border-radius:4px;font:inherit}'
      'button{padding:.5em 1em;border:0;border-radius:4px;background:#333;color:#fff;font:inherit;cursor:pointer}'
      '@media (prefers-color-scheme:dark){'
      'body{color:#e6e6e6;background:#0e0e10}'
      'input[type=password]{background:#1b1b1f;border-color:#333;color:#e6e6e6}'
      'button{background:#7faedb;color:#0e0e10}'
      '}'
      '</style>'
      '<h1>This page is password-protected</h1>'
      '<p>Enter the password to view this Quill page.</p>'
      '$errorBlock'
      '<form method="POST" action="/public/$safeUlid/unlock">'
      '<input type="password" name="password" autofocus required>'
      '<button type="submit">Unlock</button>'
      '</form>';
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
