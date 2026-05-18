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

**v1 fully shipped (M0–M1813+).** Latest commit on `main` is M1813 (final sub-slice of the shared provider harness arc — `pumpEditorBeta` now mounts `EditorBetaPage` with all 9 collaborators wired; first behavioral smoke test passes). Recent arcs: **D30 cutover** closed at M1765 (2,625 LOC removed in the largest single-file deletion in Quill history); **post-D30d archaeology** closed at M1785 (67 stale `editor_page.dart` doc-comment citations swept across 5 bite-sized slices M1773→M1785); **canonical doc refresh** at M1767 (CLAUDE.md) + M1769 (FEATURES.md) with freshness-guard test family; **TS-01 stub** at M1787 (`test/features/editor/presentation/pages/editor_beta_page_test.dart` opened); **CA-04 ExportRepository arc** closed at M1796 (M1794 HtmlExportRepository + M1796 PdfExportRepository — both export handlers now reach `vault/data/*_exporter.dart` through editor-domain interfaces wired via RepositoryProvider); **M1800 CA-04 Indexer/QuillDatabase boundary survey** — documented the remaining widget-tier bloc-construction reads as legitimate carry-forward (regression-guarded; full RP-01 sweep deferred); **shared provider harness arc** closed at M1813 (5 sub-slices M1804→M1806→M1809→M1811→M1813 wired all 9 collaborators behind `pumpEditorBeta` in `test/features/editor/presentation/pages/_harness/editor_beta_pump.dart` — future per-handler smoke tests reuse the harness directly instead of rebuilding the 9-provider stack). The original Pick-next queue (items 1/3/4/6/9 from FEATURES.md) is fully landed; subsequent milestones extended through 1,760+ commits adding block-editor depth, database polish, slash-menu extractors (M1100–M1186 series — ~110 source-text extractors), Phase E V2 backend (auth + sync + public + forms + presence + WebSocket CRDT seam), Phase G mobile shell + Phase H presence layer, the full **D-fp parity arc** (M1700-M1755 — 26 kebab actions ported onto `EditorBetaPage`: Move-to-Trash, Pull-from-server, Share-via-OS, Find-in-page with Cmd+F/⌘G/⌘⇧G/Esc, Copy-[[link]]/ULID/path, Duplicate, Reveal, Rename, Publish-toggle, Publish-with-password, Page-history, Move-to-folder, Add-tags, Set-font, Set-goal, Export-MD/HTML, Print-page, Set/Snooze/Clear-reminder, Copy-body/plain/JSON, View-form-submissions, Copy-form-link), and the full **D30 cutover arc** (D30a→D30b→D30c-a→D30c-c→D30c-b→D30d: route fork collapse + helper deletion + Settings toggle + EditorPreferencesCubit family + legacy `EditorPage` source all deleted across M1757-M1765). `lib/core/routing/routes.dart` typed-route helper module + touch-tuned mobile UI pass (slash menu + properties panel hit-targets at 44pt) also landed. ~2,677+ Flutter editor-tree tests + ~2,800+ across all features in 185+ test files + 192 backend tests across 15 test files, both `flutter analyze` and backend `dart analyze` clean.

For the full roadmap and prioritized backlog read `docs/FEATURES.md`. It's the authoritative source for what's shipped, what's queued, and what's out of scope. The Pick-next queue at the bottom is the work list to follow.

Live verified end-to-end on macOS via the picker → vault tree → editor → palette flow. iOS build succeeds via `flutter build ios --no-codesign --debug`. Linux/Windows builds require respective hosts (use CI).

## Quick start

```bash
flutter pub get
flutter analyze            # expect "No issues found"
flutter test               # expect "All tests passed!" (~2,800 tests across 144 files)
cd backend && dart analyze  # expect "No issues found!" (slice 3b cleared 252+ findings)
cd backend && dart test     # expect "All tests passed!" (192 tests across 15 files)
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
- Editor: full WYSIWYG via `super_editor` 0.3.0-dev.51 (`EditorBetaPage`). Both `/editor/:ulid` and `/editor-beta/:ulid` serve the same widget after the D30 cutover arc closed at M1765 — the legacy `EditorPage` source (2,625 lines), the `EditorPreferencesCubit` opt-in family, and the Settings → Advanced toggle were all deleted across M1757-M1765. Hand-rolled `MarkdownRenderer` survives only as a public-route renderer (`backend/lib/public/markdown_html.dart`).
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
7. ~~**macOS security-scoped bookmark persistence**~~ — ✅ Shipped at M1236-M1238 (C2 of the 1m-loop plan). `macos/Runner/AppDelegate.swift` registers a `quill/bookmarks` MethodChannel exposing `save(path)` / `resolve(bookmark)` using `URL.bookmarkData(.withSecurityScope)`. Dart wrapper at `lib/core/platform/security_scoped_bookmarks.dart`. VaultBloc persists Base64 bookmark bytes in SharedPreferences under `vault.bookmark` and resolves them on `tryRestore`. Quit + relaunch macOS app now auto-opens the vault.
8. ~~**Reveal in Finder / xdg-open / explorer.exe**~~ — ✅ Already shipped. `lib/core/platform/reveal.dart` dispatches `open` / `xdg-open` / `explorer.exe /select,` per-platform; called from the palette and editor breadcrumb. Strike from the backlog.
9. ✅ **WYSIWYG editing via super_editor** — biggest single-feature lift, **FULLY SHIPPED**. `super_editor: 0.3.0-dev.51` in `pubspec.yaml`. `lib/core/markdown/super_editor_serializer.dart` is the markdown↔MutableDocument bridge. **D1-D22 ✅** (paragraph + headings + lists + todos + code + hr + blockquote + GFM callouts + math + mermaid + GFM pipe tables + image cards + file attachments + bookmarks + sub-page + transclusion + columns + breadcrumb + toc + button fences + bold + inline code + italic + strike + underline + highlight + sub + sup + color + wikilink chip + date pill). **D23 ✅** (slash menu wiring — M1521-M1545: caret-driven trigger session, DocumentLayout caret-rect lookup, overlay rendering + selection-splice, list/todo conversion, async picker actions). **D24a/c/d ✅** (block reorder Cmd+Shift+Up/Down M1570, duplicate Cmd+D M1574, delete Cmd+Shift+Backspace M1578). **D25 ✅** (multi-block selection M1597-M1607). **D26 ✅** (inline autoformat M1549-M1564: bold, italic, strike, inline code, highlight, sub, sup). **D27 ✅** (heading conversion Cmd+Opt+1/2/3/0 M1583, list/todo conversion Cmd+Shift+7/8/9 M1591). **D-fp parity arc ✅** (M1700-M1755 — 26 kebab actions ported onto `EditorBetaPage`). **D28-D30 cutover arc ✅** (M1662-M1765): D28a/b/c toggle + GoRoute fork + Settings row (M1662/M1665/M1667), D29 default flip false→true (M1670), D30a safety net (M1673), D30b GoRoute fork collapse → direct `EditorBetaPage` build (M1757), D30c-a helper deletion (M1759), D30c-c Settings toggle + root BlocProvider deletion (M1761), D30c-b EditorPreferencesCubit + Store + tests + orphan field/dispose deletion (M1763), **D30d legacy `EditorPage` source deletion** (M1765, 2,625 LOC removed). Both `/editor/:ulid` and `/editor-beta/:ulid` now serve the same `EditorBetaPage` widget. Zero legacy artifacts remain in the editor feature.
10. ~~**Mobile editor + database screens**~~ — ✅ Both halves shipped. Responsive *shell* (drawer + tab bar) at M13/M20; mobile-shell FAB at M197; responsive command palette + slash menu widths at M206/M207; database table auto-falls-back to list rendering at M209; per-page mobile-optimised editor toolbar at G2/G2.5 (`MobileEditorToolbar` wired into editor_page body column); **touch-tuned slash menu rows (M1680)** — `slashRowPaddingFor`/`IconSizeFor`/`LabelFontSizeFor`/`ShowsKeyboardHint` helpers gated by `isMobileWidth(context)`, ≥44pt touch target on mobile, keyboard-hint chip hidden; **touch-tuned properties panel rows (M1682)** — `propertiesRowPaddingFor`/`IconSizeFor`/`KeyFontSizeFor` mirror the same pattern. Optional future: convert the right-rail properties panel to a draggable bottom sheet on mobile (heavier layout change, deferred until dogfood surfaces the need).

**Recent additions (not in original 10-item list):**

11. ~~**Inline video / audio / PDF playback**~~ — ✅ Dep-level shipped. `video_player: ^2.10.0`, `audioplayers: ^6.6.0`, `pdfx: ^2.9.2` are all in `pubspec.yaml`. Inline player widgets land via the Phase B slices when called.
12. ~~**OS notifications for reminders**~~ — ✅ Dep-level shipped. `flutter_local_notifications: ^20.1.0` + `timezone: ^0.10.0` are in `pubspec.yaml` and `test/features/reminders/reminders_bloc_test.dart` exercises the ReminderBloc.
13. ~~**Mermaid native rendering**~~ — ✅ Dep-level shipped. `webview_flutter: ^4.13.1` is in `pubspec.yaml`. Vendored mermaid asset + the M200 placeholder swap to a `_MermaidView` lands in the C-phase wire-up slice.
14. ~~**OS share-sheet integration**~~ — ✅ Already shipped. `share_plus: ^12.0.2` + `receive_sharing_intent` are in `pubspec.yaml`; F1-F3 wired the inbound listener at app boot to splice incoming text/files into `Inbox/Quick capture.md`.
15. ~~**Home-screen widgets (iOS / Android)**~~ — ✅ Dep-level shipped. `home_widget: ^0.7.0` is in `pubspec.yaml`; G1 shipped the Add-to-Inbox skeleton.
16. ~~**bloc_test / alchemist / mockingjay test packages**~~ — ✅ All four present in `pubspec.yaml` (`bloc_test: ^10.0.0`, `mocktail: ^1.0.4`, `alchemist: ^0.12.1`, `mockingjay: ^2.0.0`); foundation smoke tests at `test/foundation/{bloc_test,golden,mockingjay}_smoke_test.dart`. Existing 180 Flutter test files are a mix of hand-written + bloc_test-driven.

Settings page completion (Vault pane is solid; Appearance ✅ M100, Export ✅ M101, Advanced ✅ M102, Users ✅ M188, Sidebar ✅ M204; remaining non-Vault sections are mostly stubs), engineering quality (injectable DI, freezed entities, golden tests, bloc_test backfill), and v2 backend (Dart Frog/Serverpod + Postgres + Docker + sync) are all in the plan file `~/.claude/plans/1m-run-until-we-frolicking-thompson.md`.

## How to continue work in a new session

1. **Read this file first** (Claude Code does so automatically).
2. **Read the plan** at `~/.claude/plans/build-prompt-self-hosted-transient-bear.md` — full milestone history + unimplemented-features list.
3. **Read recent git log** to see what shipped: `git log --oneline -20`.
4. **Run tests + analyze** before changing anything: `flutter analyze && flutter test`.
5. **Reference the design** at `/tmp/design_extract/extracted/my-notion/project/src/*.jsx` when porting a screen. The design is the canonical visual spec.
6. **Pick a top-priority item** from the v1.x backlog list above, follow the existing patterns (Bloc/Cubit per scope, Clean Architecture layering, `hide Page` on db imports, mono() helper, QuillTokens), and commit incrementally.

When testing live, the macOS open dialog gotcha (hidden by computer-use screenshot filter) is worked around with blind `Cmd+Shift+G` keystrokes — see "Quick start" above.
