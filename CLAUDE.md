# CLAUDE.md — Quill (my_notion)

> Loaded automatically when Claude Code starts in this directory. Keep it accurate.

## What this is

**Quill** is a self-hosted, markdown-first Notion alternative built in Flutter.
- Every page is a real `.md` file with YAML frontmatter — portable, openable in Obsidian.
- "Databases" are folders + a `.database.yaml` schema file.
- Relations are stored as `[[ULID]]` wikilinks in markdown bodies; titles resolved at display time.
- **Markdown on disk is the source of truth.** Drift (SQLite) is a derived index that can be nuked and rebuilt from disk with byte-identical state.

Branded as "Quill" inside the app; package name `my_notion`.

## Status

**v1 mostly shipped (M0–M1186+).** Latest commit on `main` is M1186 (Stripe doc example to .env-loaded test fixture). The original Pick-next queue (items 1/3/4/6/9 from FEATURES.md) is fully landed; subsequent milestones extended through 1,200+ commits adding block-editor depth, database polish, slash-menu extractors (M1100–M1186 series — ~110 source-text extractors), and many more features. ~2,600+ tests passing across 91 test files, `flutter analyze` clean.

For the full roadmap and prioritized backlog read `docs/FEATURES.md`. It's the authoritative source for what's shipped, what's queued, and what's out of scope. The Pick-next queue at the bottom is the work list to follow.

Live verified end-to-end on macOS via the picker → vault tree → editor → palette flow. iOS build succeeds via `flutter build ios --no-codesign --debug`. Linux/Windows builds require respective hosts (use CI).

## Quick start

```bash
flutter pub get
flutter analyze            # expect "No issues found"
flutter test               # expect "All tests passed!" (~2,600 tests across 91 files)
flutter build macos --debug
open build/macos/Build/Products/Debug/my_notion.app
```

When the picker dialog opens, type **Cmd+Shift+G** then paste the path to a vault folder (e.g. `fixtures/sample_vault`) and press Return twice. The native open dialog is sometimes hidden by the screenshot filter in computer-use MCP — the keystrokes still work blindly.

## Tech stack

- Flutter stable (3.35.5+), Dart 3.9+
- State: `flutter_bloc` v9 (one Bloc per feature, Cubit per transient overlay)
- Routing: `go_router` v16 with `ShellRoute` for sidebar persistence
- DB: `drift` v2.20 over `sqlite3_flutter_libs` (FTS5 enabled via custom statements)
- Filesystem: `path_provider`, `package:file` (in-memory FS in tests)
- YAML: `yaml` (parse), custom writer that preserves raw scalars for byte-identical round-trip
- Editor: hand-rolled `MarkdownRenderer` (read-only) + `TextField` for source. `super_editor` is in deps but **not instantiated** — WYSIWYG editing is a v1.x backlog item.
- Fonts: **vendored** in `assets/fonts/` (InterVariable.ttf + JetBrainsMono Regular/Medium/Bold). `google_fonts` was removed because macOS sandbox blocks `fonts.gstatic.com`.
- Icons: hand-rolled `QuillIcon` `CustomPainter` with a mini SVG-path parser. ~40 glyphs ported 1:1 from the design's `icons.jsx`.

## Architecture — Clean Architecture

```
lib/
  main.dart                            # bootstrap
  app.dart                             # QuillApp + MultiBlocProvider + go_router
  core/
    db/quill_database.dart{.g.dart}    # Drift schema: pages, relations, databases + pages_fts FTS5
    markdown/                          # frontmatter_parser, type_inference, wikilink_parser
    ulid/ulid_generator.dart
    error/                             # (empty placeholder)
    network/                           # (empty placeholder for v2 sync)
  features/
    vault/                             # M2, M4 — filesystem + sidebar + picker
    editor/                            # M5, M10 — editor page, rails, properties panel
    database/                          # M7, M8 — table + gallery/board/timeline
    relations/                         # M5, M6 — title resolver, backlinks, [[ picker
    commands/                          # M9 — ⌘K palette
    settings/                          # M11 — settings page
    sync/                              # (empty — v2)
  shared/
    theme/                             # tokens, accents, theme_cubit, tag_colors
    widgets/                           # Chip, Tag, StatusDot, Avatar, SideItem, Segment, ToolBtn,
                                       # FrontmatterRow, ImagePlaceholder, Kbd, QuillIcon,
                                       # DBGlyph, ComponentSheetPage, ResponsiveLayout
```

Each feature folder follows `data/{datasources,repositories,models}/` + `domain/{entities,repositories,usecases}/` + `presentation/{bloc,pages,widgets,cubit}/`.

## Critical non-negotiables (DO NOT REGRESS)

1. **Markdown round-trip integrity.** `FrontmatterParser.serialise(parse(raw)) == raw` byte-identical for unedited pages. Enforced by `test/core/markdown/frontmatter_parser_test.dart`. Strategy: parser captures raw YAML block as a string and re-emits it verbatim unless entries were edited.

2. **Drift is a derived cache.** Wipe the SQLite file, run `Indexer.reindex(root)`, and the resulting `(pages, relations, databases)` snapshot is byte-identical to the previous run. Enforced by `test/integration/reindex_idempotent_test.dart`. Snapshots intentionally exclude `mtime` since it varies.

3. **ULIDs are the page identifier, not titles or paths.** All relations use `[[ULID]]`. Rename a page, rename a folder — links still resolve.

4. **No HTML stored.** Any rich content serialises to CommonMark/GFM. If WYSIWYG editing lands, the bridge layer in `lib/core/markdown/super_editor_serializer.dart` (TBD) handles the round-trip.

5. **Pages without an `id:` frontmatter field break the cache.** All seed fixtures must have `id:`. When `VaultFsDatasource.readOne` finds none, it generates one but doesn't write it back — this is OK for tests but means the indexer would produce different ULIDs across runs.

## Project conventions

- **`hide Page`** when importing `core/db/quill_database.dart` from outside the db layer — Drift generates a `Page` data class from the `pages` table that clashes with the domain `Page` entity. Pattern: `import '.../quill_database.dart' hide Page;`
- **`hide Page` on flutter/material too** — in `properties_panel.dart`, since `material.dart` re-exports `Page` from `navigator.dart`.
- **One Bloc per feature, one Cubit per transient overlay** (RelationPicker, CommandPalette, ThemeCubit). Don't multiply.
- **Indexer is a top-level `RepositoryProvider`-injected singleton.** Don't construct per-bloc.
- **Drift snake_case maps to camelCase columns automatically** — `frontmatterJson` Dart field → `frontmatter_json` SQL column. Custom SQL must use snake_case.
- **`copyWith` on entities is hand-rolled** (no freezed yet). When adding fields, update `copyWith` to include them.
- **`mono(...)` from `lib/shared/theme/tokens.dart`** is the universal helper for monospace text. Don't `GoogleFonts.jetBrainsMono(...)`.
- **`QuillTokens.of(context)`** reads design tokens. All non-Material colors go through this.
- **Path-component lists in YAML use raw scalars.** The parser preserves whatever string appeared on the right of `key:`, so don't normalise.

## Known gotchas / quirks

- **macOS app sandbox blocks ~/Documents and other folders by default.** `com.apple.security.files.user-selected.read-write` only grants access to folders the user picks via `file_picker`. Auto-restore from `SharedPreferences` works for the current session but does NOT survive across launches without security-scoped bookmark persistence (v1.x backlog item F2).
- **`VaultBloc._isAutoRestoring`** silently swallows `PathAccessException` on the first reindex after a relaunch — by design, so the user sees a clean picker rather than a stale error banner.
- **`flutter run` hot-restart does not rebuild macOS entitlements.** Changing `Debug.entitlements` requires `flutter build macos --debug` + relaunch.
- **The first build downloads sqlite3 source (~50 MB).** Subsequent builds are cached.
- **`sqlite3.c MIN macro ambiguous`** warnings during macOS build are harmless and from upstream sqlite3.
- **In computer-use MCP, the native open dialog is filtered out** (rendered by `appkit.xpc.openAndSavePanelService` which isn't allowlisted). Workaround: blind keystrokes via `Cmd+Shift+G` + path + Return + Return.

## Critical files / patterns

| Concern | Path |
|---|---|
| Design tokens (hex values) | `lib/shared/theme/tokens.dart` |
| Theme extension carrying non-Material colors | `lib/shared/theme/quill_tokens.dart` |
| Frontmatter parser (the byte-identical round trip) | `lib/core/markdown/frontmatter_parser.dart` |
| Drift schema | `lib/core/db/quill_database.dart` |
| Indexer (the nuke-and-rebuild contract) | `lib/features/vault/data/indexer.dart` |
| Markdown rendering (hand-rolled) | `lib/features/editor/presentation/widgets/markdown_renderer.dart` |
| Frozen-column table | `lib/features/database/presentation/widgets/frozen_column_table.dart` |
| Cell renderers per type | `lib/features/database/presentation/widgets/cell_renderers.dart` |
| Shell + routing | `lib/features/vault/presentation/pages/vault_shell_page.dart` + `lib/app.dart` |
| Macros for ⌘K | `lib/features/vault/presentation/pages/vault_shell_page.dart` (CallbackShortcuts) |
| macOS entitlements | `macos/Runner/{Debug,Release}.entitlements` |
| Original implementation plan | `~/.claude/plans/build-prompt-self-hosted-transient-bear.md` |
| Original design bundle (source of truth for visuals) | `/tmp/design_extract/extracted/my-notion/project/src/*.jsx` |

## Test commands

```bash
flutter test                                                # all
flutter test test/integration/reindex_idempotent_test.dart  # the non-negotiable
flutter test test/core/markdown/                            # parser tests
flutter test test/features/vault/                           # FS + exporter
```

`fixtures/sample_vault/` contains a 7-page seed vault with a `Customers` database (`.database.yaml`) and cross-page wikilinks. Use it for live testing and as test seed data.

## What is NOT implemented (v1.x backlog, by priority)

User-visible polish in rough impact order (full breakdown in `~/.claude/plans/build-prompt-self-hosted-transient-bear.md` § "Unimplemented features"):

1. ~~**File watching**~~ — ✅ Already shipped. `lib/features/vault/data/vault_watcher.dart` runs `Directory.watch(recursive: true)` with a 250 ms debounce, filters to `.md` + `.database.yaml`, and `VaultBloc` subscribes (line 54) to dispatch `RefreshFromDisk` on each ping. Strike from the backlog.
2. ~~**Frontmatter inline editing in editor + properties panel**~~ — ✅ Already shipped. `properties_panel.dart` dispatches `EditFrontmatterField` / `AddFrontmatterField` / `RemoveFrontmatterField`; `editor_page.dart` reuses the same events for the page-icon / reminder / font kebab actions. Strike from the backlog.
3. ~~**Database cell editing + Add row**~~ — ✅ Already shipped. `FrozenColumnTable` has `_EditableCell` (line 1085+) wired through `onCellEdit` and an `onCreateRow` callback rendered as a `+` row at the bottom of each table. Strike from the backlog.
4. ~~**Filter / Sort / Group runtime in database table**~~ — ✅ Already shipped. `lib/features/database/domain/usecases/apply_query.dart` (`ApplyQuery.apply`) takes a `DatabaseQuery` (`FilterRule` / sort / group) and is called from `database_table_page.dart` (lines 470, 555, 710) plus `board_view.dart._groupRows`. Strike from the backlog.
5. ~~**Relation picker keyboard navigation**~~ — ✅ Already shipped. `source_view.dart:663-690` wires Up/Down → `Cubit.move()`, Enter/Tab → `onPick(selected)`, Escape → `dismiss()`. Strike from the backlog.
6. ~~**Command palette action handlers**~~ — ✅ Already shipped. `vault_shell_page.dart:_invokeAction` switches on the entry label and runs the matching handler for Reindex, Quick capture, Bookmark URL, Open random page, Open today's daily note, Toggle theme, Toggle compact mode, Show orphan/untagged/no-title/broken-wikilink/stale pages, Import CSV/HTML/text/Markdown/OPML, Export vault, Reveal vault in Finder, Show trash. Strike from the backlog.
7. **macOS security-scoped bookmark persistence** — currently auto-restore fails on relaunch and silently falls back to picker. `macos/Runner/` has no `SecurityScopedResource` calls; no `MethodChannel` for bookmark save/resolve. (1 day, Swift channel)
8. ~~**Reveal in Finder / xdg-open / explorer.exe**~~ — ✅ Already shipped. `lib/core/platform/reveal.dart` dispatches `open` / `xdg-open` / `explorer.exe /select,` per-platform; called from the palette and editor breadcrumb. Strike from the backlog.
9. **WYSIWYG editing via super_editor** — biggest single-feature lift. Source mode + read-only rendered work fine without it. **Note:** `super_editor` is NOT yet in `pubspec.yaml` (was previously assumed to be a dependency); the migration starts with adding it. (2–3 days incl. round-trip serializer audit)
10. 🚧 **Mobile editor + database screens** — Responsive *shell* (drawer + tab bar) shipped at M13/M20; mobile-shell FAB at M197; responsive command palette + slash menu widths at M206/M207; database table auto-falls-back to list rendering at M209. **Still pending:** per-page mobile-optimised editor toolbar, mobile-first properties panel, touch-tuned slash menu. (~1 day remaining)

**Recent additions (not in original 10-item list):**

11. **Inline video / audio / PDF playback** — M201 ships rich M201 cards (video terracotta band, audio blue band, PDF sage band) but `_open()` falls back to OS default player; no `video_player`, `audioplayers`, or `pdfx` in `pubspec.yaml`. (2–3 days for all three)
12. **OS notifications for reminders** — M89 / M211 / M230 surface `reminder:` frontmatter in PageHeader + home-page list + kebab editor; no `flutter_local_notifications` dispatch. (1 day)
13. **Mermaid native rendering** — M200 styles fenced ```mermaid blocks as a placeholder card; no `webview_flutter` or `flutter_mermaid` actually renders them. (~0.5 day with vendored mermaid.min.js + webview)
14. **OS share-sheet integration** — M210 in-app Quick Capture covers the analogous workflow; no `share_plus` or `receive_sharing_intent`. (1 day)
15. **Home-screen widgets (iOS / Android)** — write-only "Add to Inbox" widget would be the natural first. (~1 day per platform via `home_widget`)
16. **bloc_test / alchemist / mockingjay test packages** — RULES.md TS-03 / TS-08 / TS-09 require these; none are currently in `pubspec.yaml`. Existing 91 test files are hand-written. (Foundation phase of the 1m-loop adds them + ports 5 existing bloc tests.)

Settings page completion (Vault pane is solid; Appearance ✅ M100, Export ✅ M101, Advanced ✅ M102, Users ✅ M188, Sidebar ✅ M204; remaining non-Vault sections are mostly stubs), engineering quality (injectable DI, freezed entities, golden tests, bloc_test backfill), and v2 backend (Dart Frog/Serverpod + Postgres + Docker + sync) are all in the plan file `~/.claude/plans/1m-run-until-we-frolicking-thompson.md`.

## How to continue work in a new session

1. **Read this file first** (Claude Code does so automatically).
2. **Read the plan** at `~/.claude/plans/build-prompt-self-hosted-transient-bear.md` — full milestone history + unimplemented-features list.
3. **Read recent git log** to see what shipped: `git log --oneline -20`.
4. **Run tests + analyze** before changing anything: `flutter analyze && flutter test`.
5. **Reference the design** at `/tmp/design_extract/extracted/my-notion/project/src/*.jsx` when porting a screen. The design is the canonical visual spec.
6. **Pick a top-priority item** from the v1.x backlog list above, follow the existing patterns (Bloc/Cubit per scope, Clean Architecture layering, `hide Page` on db imports, mono() helper, QuillTokens), and commit incrementally.

When testing live, the macOS open dialog gotcha (hidden by computer-use screenshot filter) is worked around with blind `Cmd+Shift+G` keystrokes — see "Quick start" above.
