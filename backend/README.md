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
