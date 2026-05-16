# Phase E manual sanity checklist

> One-screen reference for live-testing the v2 backend (sync + public
> sharing + forms). Each section is independent — you can skip down to
> the slice you care about. Tick the box once you've actually clicked
> through it on a running stack.

## Stack up

```
cd backend
docker compose up -d
# Postgres :5432, pgAdmin :5050, server :8080
curl -s http://localhost:8080/health   # → ok
```

If `/health` returns `db: not connected`, wait ~10 s and retry — the
Dart server boots faster than Postgres warms up; subsequent requests
will report green.

## Sync (E1–E40)

- [ ] **Signup** — open Quill, Settings → Sync, enter a fresh email +
  password, hit Sign up. Card flips to green "Connected" with the
  account email.
- [ ] **Restore** — quit the app, relaunch. The Sync card stays
  "Connected" (token survives via SharedPreferences; an empty
  `/sync/list` ping verifies the JWT on boot).
- [ ] **Auto-push on save** — open any `.md` page, type, wait for the
  debounced auto-save. The sync card's "Last push" row updates to
  `<relpath> · X s ago`.
- [ ] **Conflict toast** — `psql` into the backend, set the page's
  `sha256` to a junk value, save again. Warn toast "Sync conflict on
  …" appears with a Pull action.
- [ ] **Pull dialog** — tap the toast's Pull action. Reconcile dialog
  shows local vs server side-by-side, server mtime "X ago", and a
  disabled Use Server button if the bodies are byte-identical.
- [ ] **Bulk push** — Settings → Sync → "Push all unsynced". Toast
  shows `Bulk push queued — N files`. The Activity row's
  `pendingPushes` indicator counts down to 0.
- [ ] **Background ping** — leave the app idle for >60 s on the sync
  pane. The Backend row's relative time updates ("reachable · 30s
  ago", "1m ago", …).
- [ ] **Logout** — Log out. Card flips to login. The `sync.token`
  pref is gone (`adb shell run-as / iOS UserDefaults` to verify if
  curious).

## Public sharing (E16, E21, E43, E44)

- [ ] **Publish & copy link** — kebab → "Publish & copy link" on a
  page. URL `http://localhost:8080/public/<ulid>` is on the
  clipboard. Pasting it in a browser shows the page rendered as
  HTML (headings, lists, code blocks, etc.).
- [ ] **Publish with password** — kebab → "Publish with password…".
  Enter a password, hit Publish. URL copied. Pasting in a fresh
  incognito window shows the unlock form. Wrong password → 401
  with inline error. Right password → page renders + sets the
  `quill_unlock_<ulid>` cookie. Refresh in the same tab → page
  loads directly (cookie hit).
- [ ] **Password rotation** — re-run "Publish with password…" with a
  new password. The old browser cookie no longer matches; the
  visitor sees the unlock form again on next request.
- [ ] **Unpublish** — kebab → "Unpublish". URL now 404s. Re-publish
  without a password and confirm no stale `public_password` field
  remains in frontmatter.

## Forms (E46–E51)

- [ ] **Mark a page as form-bearing** — manually add `forms: true` to
  frontmatter (also requires `public: true`). Wait for auto-save.
- [ ] **Visitor submit** — in a fresh incognito window, run:
  ```
  curl -i -X POST http://localhost:8080/forms/<ulid>/submit \
       -H 'content-type: application/x-www-form-urlencoded' \
       --data 'name=Pat&email=pat@example.com'
  ```
  Expected: `HTTP/1.1 303` with `location: /forms/<ulid>/thanks?id=…`.
  Follow the redirect → "Thanks!" page renders.
- [ ] **Body too large** — POST with `--data "name=$(yes x | head -c
  33000 | tr -d '\n')"` → 413 `body_too_large`.
- [ ] **Empty body** — POST with `--data ''` → 400 `empty_body`.
- [ ] **Owner views submissions** — back in Quill, kebab → "View form
  submissions →". Dialog opens; tile shows the timestamp, "from
  127.0.0.1" (or whatever your `X-Forwarded-For` resolves to), and
  the JSON-pretty body.
- [ ] **Not-owner path** — log out of Quill, sign up as a second
  user, navigate to a page with the **first** user's ULID (e.g. by
  manually editing frontmatter), open the dialog. Renders the
  "This page is not yours, or it hasn't been published yet." copy
  with a Retry button.
- [ ] **Empty submissions** — for a freshly-marked form-bearing page
  with no submissions yet, the dialog shows the "No submissions
  yet." placeholder.
- [ ] **Retry on transient failure** — `docker compose stop server`
  while the dialog is open, hit Retry → "Network: …" error.
  `docker compose start server`, hit Retry again → list renders.

## Stack down

```
cd backend
docker compose down -v   # discards Postgres volume too
```

Useful when iterating on migrations — drop everything, change the
SQL, bring it back up; the migrator runs from v1 again.
