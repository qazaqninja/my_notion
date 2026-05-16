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
