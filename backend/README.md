# Quill backend

> V2 backend scaffold (Phase E E1 of `~/.claude/plans/1m-run-until-we-frolicking-thompson.md`).

Self-hosted server that lets the Quill Flutter client sync, share, and
collaborate across devices and users. The phase-1 self-hosted local-first
experience does NOT need this backend — it's purely additive for the v2
multi-user / sync features.

## Stack

- **Language:** Dart 3.9+
- **Framework:** [shelf](https://pub.dev/packages/shelf) + [shelf_router](https://pub.dev/packages/shelf_router). Migration to [Dart Frog](https://dartfrog.vgv.dev) is queued once `dart_frog_cli` is installed.
- **Database:** Postgres 16 (canonical store)
- **Auth:** bcrypt + JWT (slice E6-E15)
- **Sync:** ETag-based push/pull (slice E16-E30)
- **CRDT:** Yjs port via `y_crdt` (slice E31-E45)

## Quick start

### Local dev (Dart SDK only)

```
cd backend
dart pub get
dart run bin/server.dart
# Server listening on port 8080
curl http://localhost:8080            # → Hello, World!
curl http://localhost:8080/echo/hi    # → hi
```

### Full stack (Docker)

```
cd backend
docker compose up -d
# Postgres :5432, pgAdmin :5050 (admin@quill / admin), server :8080
docker compose logs -f server
docker compose down -v                # stop + destroy volumes
```

## Directory layout

```
backend/
  bin/
    server.dart          # entrypoint
  lib/                   # (forthcoming) routes/, db/, sync/, auth/, crdt/
  test/
    server_test.dart     # initial smoke test
  Dockerfile             # multi-stage Dart-runtime container
  docker-compose.yml     # Postgres + pgAdmin + server orchestration
  pubspec.yaml
```

## Roadmap (Phase E of the 1m-loop plan)

- **E1 (this slice)** — Scaffold + docker-compose ✅
- **E2-E5** — Postgres migrations / db package, health endpoint
- **E6-E15** — Auth (signup / login / refresh, users table, JWT)
- **E16-E30** — File-level sync (push/pull/delta with ETag/If-Match)
- **E31-E45** — CRDT layer (`y_crdt` + WebSocket subscriptions)
- **E46-E55** — Public page sharing (`/public/<ulid>` HTML render)
- **E56-E65** — Forms (database column type + public submit endpoint)
- **E66+** — Polish (web clipper, rich bookmarks, notifications worker)

## Public sharing contract (E16–E44)

The public surface is the one part of the backend a non-authenticated
visitor talks to directly. Understanding the field/cookie/route names
matters because they're all hand-rolled (no auth library) and the
contract spans both sides of the codebase.

### Frontmatter fields a page can carry

- `id: <ULID>` — the page identifier. Backend extracts via
  `FrontmatterProbe` on every sync upsert. Required for the page to
  appear at `/public/<ulid>`.
- `public: true` — opt-in to publication. The probe also accepts
  `public: yes`. Anything else (false / absent / other strings) keeps
  the page private.
- `public_password: "$2a$10$…"` — optional. The plaintext password is
  never seen by the backend; the **client** computes the bcrypt hash
  before pushing (see
  `lib/features/sync/domain/usecases/build_public_password_entries.dart`
  and the editor kebab "Publish with password…"). The probe defensively
  rejects values that don't match the bcrypt hash shape
  (`$2[abxy]$NN$…` with 53 trailing chars).

### Routes

- `GET /public/<ulid>` (no auth)
  - 404 if no row with `is_public = true` matches.
  - 200 with the unlock-form HTML if `public_password_hash IS NOT NULL`
    AND the request does not carry a matching `quill_unlock_<ulid>`
    cookie.
  - 200 with the rendered markdown otherwise.
- `POST /public/<ulid>/unlock` (no auth, form-encoded body)
  - 303 redirect to `/public/<ulid>` on bcrypt match. Sets cookie
    `quill_unlock_<ulid>=<hash>; Path=/public/<ulid>; HttpOnly;
    SameSite=Lax; Max-Age=2592000`.
  - 401 with the unlock form re-rendered (+ inline error) on mismatch.
  - 404 if no public row matches the ULID.

### Cookie semantics

The cookie value is **the bcrypt hash itself**, not a session token.
This is deliberate:

- Stateless — backend doesn't persist any per-visitor state.
- Self-rotating — when the owner re-publishes with a new password, the
  stored hash changes, the visitor's cookie value no longer matches,
  and the unlock form re-prompts. No server-side revocation list.
- Scope-limited — `Path=/public/<ulid>` keeps the cookie from being
  sent on any other route.
- `HttpOnly` keeps it out of `document.cookie` for XSS-defense.
- `SameSite=Lax` blocks cross-site form posts while letting top-level
  navigations unlock as expected.

### End-to-end flow (publish-with-password)

1. **Editor kebab → "Publish with password…"** opens a modal with an
   obscured text field.
2. On submit, `buildPublicPasswordEntries(password)` bcrypt-hashes the
   plaintext (cost 10) and returns two `FrontmatterEntry`s.
3. Editor dispatches `AddFrontmatterField` / `EditFrontmatterField`
   for `public: true` and `public_password: "<hash>"`.
4. Auto-save fires; the E18 save → push bridge dispatches
   `SyncPushFileRequested` to `SyncBloc`.
5. Backend `PUT /sync/put/<relpath>` runs `FrontmatterProbe.fromBody`,
   extracts `ulid` + `isPublic` + `publicPasswordHash`, and writes the
   row to `vault_files`.
6. Visitor opens `http://<host>/public/<ulid>` → unlock form.
7. Visitor enters password → `POST /public/<ulid>/unlock` → bcrypt
   check → 303 + Set-Cookie.
8. Visitor follows redirect → cookie matches → rendered HTML.
9. Owner rotates the password (re-runs "Publish with password…" with a
   new value) → stored hash changes → old visitor cookies invalidated
   automatically on next request.

## Forms contract (E46–E51)

The forms surface lets a public page accept submissions from
non-authenticated visitors and lets the page's owner read what came in.

### Frontmatter fields a form-bearing page carries

- `id: <ULID>` — same as the public-sharing flow; the page is reachable
  at `/forms/<ulid>/submit` and `/forms/owner/<ulid>/submissions`.
- `public: true` — required. Visitors can only submit to publicly-
  reachable pages.
- `forms: <anything-non-empty>` — flags the page as form-bearing.
  Today any non-empty value works (the rich `.database.yaml` schema
  resolution is a future slice). Suggested conventions:
  `forms: true` for a single-form page or
  `forms: customers.database.yaml` once schema-walking lands.

`FrontmatterProbe` extracts both `isPublic` and `hasForms` on every
sync upsert; the row's `has_forms` column is the gate the visitor's
POST checks against.

### Routes

- **Unauthed (visitor-facing):**
  - `POST /forms/<ulid>/submit` (form-urlencoded body)
    - 404 `not_found` — malformed ULID.
    - 404 `no_form_definition` — no public page with `has_forms = true`.
    - 413 `body_too_large` — body > 32 KB.
    - 400 `empty_body` — no non-empty fields after parsing.
    - 303 → `/forms/<ulid>/thanks?id=<submissionId>` on success.
  - `GET /forms/<ulid>/thanks` — minimal styled HTML "Thanks!" page.

- **Authed (page-owner-facing):**
  - `GET /forms/owner/<ulid>/submissions` (Bearer JWT)
    - 401 — missing/invalid token (from `requireAuth` middleware).
    - 403 `not_owner` — the page doesn't exist OR doesn't belong to
      the caller. Same response shape on both branches to avoid
      letting visitors enumerate ULIDs.
    - 404 `not_found` — malformed ULID in the path.
    - 200 `{"submissions": [...]}` on success.

The owner-facing sub-router is mounted at `/forms/owner/` **before**
the unauthed `/forms/` mount in `server.dart`, so shelf_router's
prefix-first dispatch always lands authed requests on the gated
handler. Reversing the order would create an auth bypass — covered
explicitly in the E50 audit.

### Storage

- `vault_files.has_forms BOOLEAN` (migration 5) — set by the sync
  upsert from `FrontmatterProbe.hasForms`. Partial index
  `idx_vault_files_ulid_forms ON vault_files(ulid) WHERE is_public =
  true AND has_forms = true` matches the lookup predicate exactly.
- `form_submissions(id, page_ulid, fields JSONB, source_ip,
  created_at)` (migration 6) — one row per submission. `id` is a
  fresh ULID generated by the route handler. `idx_form_submissions_
  page ON (page_ulid, created_at DESC)` covers the owner-side list.

### Source IP capture

`FormsRepository.insertSubmission` records the visitor's IP best-
effort: first `X-Forwarded-For` (split on `,`, first hop) if present,
otherwise shelf's `shelf.io.connection_info`. Null when neither is
available (e.g. unit tests).

### Cookie semantics

Forms do NOT use cookies. The unauthed POST is one-shot — no session,
no rate limiting, no captcha (those are future polish slices). The
authed `/owner/` route uses the same Bearer JWT as `/sync/`.

### End-to-end flow (submit a form)

1. **Owner stamps `public: true` + `forms: true`** into the page's
   frontmatter (manually for now; a "Publish as form…" kebab entry is
   a future slice).
2. Auto-save → `PUT /sync/put/<relpath>` → backend probes both flags
   and writes `is_public = true`, `has_forms = true`.
3. Owner shares `http://<host>/forms/<ulid>/submit` URL with a visitor
   (or embeds a `<form action="…">` on a separate static site).
4. **Visitor** submits the form. Server inserts a row in
   `form_submissions`, returns 303 → `/forms/<ulid>/thanks?id=<sid>`.
5. Owner opens the page in Quill, taps kebab → "View form submissions
   →" (only shown when `_hasForms(loaded)` is true).
6. `FormSubmissionsDialog` fires `GET /forms/owner/<ulid>/submissions`
   with the cached JWT, renders each submission as a tile
   (timestamp + `from <ip>` + JSON of fields).
7. Errors map to typed exceptions: `FormsNotOwnerException` →
   "This page is not yours, or it hasn't been published yet."
   `FormsAuthException` → "Session expired — log in again."
   `FormsNetworkException` → "Network: <msg>". All three render with
   a Retry button.
