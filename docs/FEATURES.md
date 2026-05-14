# Feature roadmap — Quill (my_notion)

> Reconciliation of every Notion feature against what Quill has actually shipped (M0–M20), what is partially done, what is queued, and what is explicitly out of scope. The goal is that any agent landing in this repo for the first time can open this file, pick an item, follow the file pointers it includes, and ship it as the next milestone (Mxx) without re-discovering the codebase.

Read `CLAUDE.md` first for invariants and conventions. Read `~/.claude/plans/build-prompt-self-hosted-transient-bear.md` for the original milestone plan. Then come back here.

## How to use this doc

1. Scan the **Pick-next queue** at the bottom — it's the prioritized work list. The top item is what you should pick.
2. Find the item in the categorized list to see which file(s) and patterns to touch.
3. Follow the **Architecture invariants** below — they are non-negotiable and they tell you *where* state lives (markdown frontmatter vs. drift vs. nowhere).
4. Ship as the next milestone commit `Mxx: <feature>`, matching the style of the existing 21 milestones.

## Status legend

- ✅ **Shipped** — landed in M0–M20. Commit hash in parens when notable.
- 🚧 **Partial** — some of it works, the rest is queued.
- 📋 **Backlog** — ready to pick up. No backend or new architecture required.
- 🔮 **v2 — requires backend** — needs the Dart Frog/Serverpod + Postgres + Docker layer that hasn't been built yet.
- 🚫 **Out of scope for v1** — Quill is a desktop/mobile self-hosted markdown editor, not a publishing platform or SaaS admin console. Reason given inline.

## Architecture invariants (don't break these while shipping a feature)

1. **Markdown on disk is the source of truth.** Every persistent piece of state goes in either YAML frontmatter or the markdown body. New fields → frontmatter. Round-trip must remain byte-identical for unedited pages (`test/core/markdown/frontmatter_parser_test.dart`).
2. **Drift is a derived cache.** `Indexer.reindex(root)` must reproduce identical `(pages, relations, databases)` state from disk. Never store user data only in SQLite (`test/integration/reindex_idempotent_test.dart`).
3. **All relations use `[[ULID]]`.** Page identity is the ULID in the frontmatter `id:` field, not the title or path. Titles, paths, and folders may change freely.

If your feature wants to store something new, the answer is almost always "add a frontmatter field and make the parser/indexer aware of it" — not "add a Drift column".

---

## Pages & Content

- 🚧 Hierarchical nested pages (infinite depth) — Folder tree already renders as page tree (`lib/features/vault/presentation/widgets/sidebar_tree.dart`). Missing: "Create subpage" action and breadcrumb. See Pick-next #3.
- 🚧 Subpages and page-in-page — Same as above; subpage blocks (inline) are 📋 and depend on the block editor model.
- 📋 Page icons (emoji, custom upload, Notion gallery) — Store in frontmatter `icon: 📝` or `icon: assets/icons/foo.png`. Render in `lib/features/editor/presentation/widgets/frontmatter_card.dart` and in the sidebar row.
- 📋 Page covers (image upload, URL, Unsplash, gallery) — Frontmatter `cover: <path|url>`. Hero band at the top of `editor_page.dart`. Unsplash search is optional and needs an API key in settings.
- 📋 Page templates (built-in and custom) — Convention: a `Templates/` folder at vault root. On "Create from template", copy the `.md` and regenerate `id:`. Built-in gallery is just seeded files in `assets/templates/`.
- 📋 Duplicate page (with or without subpages) — Add `DuplicatePage` use case to `lib/features/vault/domain/usecases/`. The recursive variant copies the folder for folder-pages.
- 📋 Move page to another location — Drag in `sidebar_tree.dart` → rename file → `VaultBloc` reindex. `[[ULID]]` links don't care about paths so this is safe.
- 📋 Page history / version history — Two options: (a) if vault is a git repo, shell out to `git log -- <file>` and `git show <sha>:<file>`; (b) snapshot `.md` into `.history/<ULID>/<ts>.md`. Recommend (a) with (b) as fallback.
- 📋 Page locking — Frontmatter `locked: true`. `EditorBloc` checks it and disables `EditBody` / `EditFrontmatter`.
- 🚧 Favorites / pinning — Sidebar section exists visually. Persist as `favorites: [ULID, ...]` in a vault-root `.quill.yaml`. Toggle via star icon in editor toolbar.
- 📋 Trash with restore — Move file to `.trash/<YYYY-MM>/<original-name>.md`. Drift flags `deleted=true` for filtered views. Restore = move back.
- 📋 Page comments (general and inline) — Sidecar `<page>.comments.yaml` keyed by block id; or frontmatter `comments:` array. Inline comments need block ids in the renderer first.
- 🚧 Page mentions (@page-name) — `[[ULID]]` works (M5/M6). The `@` UX sugar — typing `@` to open the same picker — is 📋. Trivial wiring in `source_view.dart` once added.
- 🔮 Public page sharing via web link — Requires hosting backend.
- 🚫 Custom page URLs / domains (paid) — Quill is a desktop app, not a publishing platform.
- 🚫 Page analytics (views, visitors) — Same reason.
- 📋 Wiki mode (turn page into a wiki with owners and verification) — Frontmatter `wiki: true`, `owners: [...]`, `verified: <date>`. Render badge in editor header.
- 📋 Breadcrumb navigation — Derive from the file's path within the vault. Render at the top of `editor_page.dart`.
- ✅ Backlinks (auto-tracked references to a page) — M5, `lib/features/editor/presentation/widgets/backlinks_rail.dart`. Powered by `relations` table.

## Block Editor

- 🚧 Block-based editing (everything is a block) — Read-only renderer (`markdown_renderer.dart`) already walks a block tree. There is no editable block model yet; `super_editor` is in `pubspec.yaml` but not instantiated. The biggest single-feature lift in this doc.
- 📋 **Slash command menu (/)** — Pick-next #1. Mirror `command_palette_cubit.dart`: a `SlashMenuCubit` driven by source-mode keystrokes in `source_view.dart`. Each entry inserts a markdown snippet at the cursor.
- 📋 Drag and drop blocks — Depends on editable block model.
- 📋 Multi-column layouts — Custom container syntax or a dedicated block; renderer + serializer round-trip required.
- 📋 Toggle (collapsible) blocks — Render as `<details><summary>`; preserve in serializer.
- 📋 Toggle headings — Same.
- ✅ Headings (H1, H2, H3) — `markdown_renderer.dart`.
- ✅ Bulleted, numbered, and to-do lists — `markdown_renderer.dart`.
- ✅ Nested list indentation — `markdown_renderer.dart`.
- ✅ Quote blocks — `markdown_renderer.dart`.
- 📋 Callout blocks with custom icons and colors — Use GFM admonition syntax (`> [!NOTE]`) or a custom fenced container. Renderer extension + serializer.
- ✅ Divider lines — `markdown_renderer.dart`.
- ✅ Code blocks with syntax highlighting for 60+ languages — `flutter_highlight`.
- ✅ Inline code formatting — `markdown_renderer.dart`.
- 📋 Math equations (KaTeX) — block and inline — Pick-next #5. Add `flutter_math_fork`; parse `$inline$` and `$$block$$`.
- 📋 Tables (simple, non-database) — GFM pipe tables; not yet rendered. Add to `markdown_renderer.dart`.
- 📋 Synced blocks (edit in one place, updates everywhere) — Wikilink-style transclusion: `![[ULID#blockId]]`.
- 📋 Block-level comments — Needs block ids first. Sidecar `.comments.yaml`.
- 📋 Block links (link to a specific block) — `[[ULID#blockId]]` anchor in renderer + scroll-into-view.
- 📋 Turn block into another block type — Needs slash menu (#1) and a block model.
- 📋 Text color and background color — Inline `<span style>` is the markdown-portable path; or a Quill-specific syntax with a writer that emits plain markdown when stripping styles.
- ✅ Bold, italic, underline, strikethrough — Bold/italic/strike via standard markdown; underline 📋 (no portable markdown — pick `__x__` or HTML and document).
- 📋 Block backgrounds and text colors — Callout-adjacent; same syntax decision as above.
- 📋 Bookmarks (rich link previews) — Fetch Open Graph metadata, cache in `.quill/cache/`, render rich card.
- 📋 Web bookmark blocks — Same.
- 📋 Buttons (templated multi-action blocks) — Custom fenced ```button block + handler registry in editor.
- 📋 Sub-page blocks — Pairs with hierarchy (#3).
- ✅ Link-to-page blocks — Via `[[ULID]]`.
- 📋 Table of contents block — Derive from `outline_rail.dart` already-extracted headings.
- 📋 Breadcrumb block — Derive from path.
- 📋 Columns and column lists — See multi-column layouts.

## Media Blocks

- 📋 Image upload and embed — Pick-next #6. Write file to `<vault>/attachments/<ULID>.<ext>`, emit `![alt](attachments/...)`. Drag-and-drop in `source_view.dart`.
- 📋 Image alignment, resize, full-width — Extension syntax `![alt|w=600](path)` or surrounding HTML attrs. Document the convention.
- 📋 Video upload and embed — Same write path; render with platform player.
- 📋 Audio upload and embed — Same.
- 📋 File attachments — Same write path; render as a download chip.
- 📋 PDF embed and preview — Same write path; `pdfx` package for inline preview.
- 🚧 Image galleries (via database) — Gallery view exists (M8). Needs `files & media` property type in `cell_renderers.dart` to actually show thumbnails.

## Databases

- ✅ Database creation (full-page or inline) — Full-page via `.database.yaml` discovery (M7). Inline (`%%db ...%%` block inside a page) is 📋.
- ✅ Multiple views per database (table, board, list, gallery, calendar, timeline) — M7+M8 cover table, board, gallery, timeline. List 📋 (table minus columns). Calendar 📋 (Pick-next #8).
- Property types:
  - ✅ text, number, select, multi-select, status, date, checkbox, URL, email, phone — In `cell_renderers.dart`.
  - ✅ relation — `[[ULID]]` resolved at render via `title_resolver`.
  - ✅ ID — ULID.
  - ✅ last edited time — file `mtime` (deliberately excluded from reindex idempotency snapshots).
  - 📋 files & media — Pick-next item.
  - 📋 formula — Pick-next #7. Implement a Notion formula v2 subset (`prop("x")`, arithmetic, conditionals, string/date helpers).
  - 📋 rollup — Pick-next #7. Aggregate over related rows.
  - 📋 created time — Use `ctime` where available; otherwise `created:` frontmatter set on first write.
  - 📋 created by, last edited by, person — Requires a user identity model. v1: read from `.quill.yaml` users list. Full multi-user is 🔮.
  - 📋 button — Custom fenced ```button block inside the row page.
- 📋 Sub-items (parent/child rows) — Schema field `parent: <relation-to-self>`; tree expansion in `frozen_column_table.dart`.
- 📋 Dependencies between rows — Used in timeline view; add `depends_on:` relation.
- 📋 Database templates (per-database row templates) — Schema `row_template: <path>`; copy on "New row".
- ✅ Filters (single and compound with AND/OR logic) — M19, `query_popovers.dart` + `apply_query.dart`.
- ✅ Sorts (multi-level) — M19.
- ✅ Grouping (by any property) — M19.
- 📋 Sub-grouping — Extend `apply_query.dart`.
- 📋 Hide/show properties per view — Schema `views[].visible: [...]`.
- 📋 Reorder properties — Drag handle in table header.
- 📋 Property width adjustment — Persist to `.database.yaml`.
- ✅ Frozen columns in table view — M7, `frozen_column_table.dart`.
- 📋 Calculations per column (sum, average, count, min, max, range, etc.) — Footer row in `frozen_column_table.dart`.
- 📋 Wrap cells / unwrap — Table view setting.
- ✅ Open row as a full page — Clicking a row navigates to the underlying `.md` page (table page → editor page).
- 📋 Row icons and covers — Frontmatter `icon:` / `cover:` like pages.
- 📋 Linked database views — A page-level block that references another database with its own view config.
- 📋 Database mentions / inline databases — Same.
- 🚧 Relations between databases (one-way and two-way) — One-way ✅ via `[[ULID]]`. Two-way 📋 — indexer auto-creates the reverse relation row.
- 📋 Rollups (aggregate from related rows) — See formula.
- 📋 Formulas (Notion formula language v2) — Pick-next #7.
- 📋 Buttons inside rows that trigger actions — See button property type.
- 🔮 Automations (no-code rules: when X changes, do Y) — Requires backend daemon (file-watch-only is insufficient because rules need to run on remote edits too).
- 📋 Database locking — Schema `locked: true`.
- 📋 CSV import — `lib/features/vault/data/datasources/` — add a converter that writes one `.md` per row + a `.database.yaml`.
- 📋 CSV export — Inverse of import. Reuse for "Include databases in export".
- ✅ Markdown export (with subpages and database CSVs) — M12. Currently exports row pages; CSV emission is 📋 (see CSV export).
- 📋 HTML export — Reuse `markdown_renderer.dart` → HTML serializer.
- 📋 PDF export — `printing` / `pdf` packages.

## Views

- ✅ Table view — M7.
- ✅ Board (Kanban) view — M8.
- 📋 List view — Table view minus columns; trivial.
- ✅ Gallery view (card grid) — M8.
- 📋 Calendar view — Pick-next #8.
- ✅ Timeline view (Gantt-style) — M8.
- 📋 Chart view (bar, line, donut) — Pick-next #8. `fl_chart` package.
- 🚧 View-specific filters, sorts, properties — Filters/sorts persist per view ✅. Property selection 📋.
- 🚧 Group and sub-group per view — Group ✅. Sub-group 📋.
- 📋 Customize card size, preview image, fields shown — Schema additions on the `views[]` entry.

## Search & Navigation

- 🚧 Global search (Cmd/Ctrl + P) — ⌘K palette exists (M9); FTS5 virtual table `pages_fts` is wired in drift schema; the palette doesn't actually `MATCH` against it yet. Wire `command_palette_cubit.dart` to query FTS for non-command queries.
- 📋 Quick find with filters (by author, date, in page) — Extend palette with filter chips.
- 🚧 Recent pages — Sidebar surface exists; persistence as `recent: [ULID, ...]` in `.quill.yaml` is 📋.
- 🚧 Sidebar with workspaces, favorites, private, shared, teamspaces — Vault tree ✅. Favorites 📋. Private/shared/teamspaces 🔮.
- 🔮 Teamspaces (group pages by team) — Multi-user concept.
- ✅ Keyboard shortcuts (extensive) — `vault_shell_page.dart` `CallbackShortcuts`; extend there.
- ✅ Cmd+K command menu — M9.

## Collaboration

- 🔮 Real-time multiplayer editing — Needs CRDT layer + backend.
- 🔮 Cursor presence (see others typing) — Same.
- 📋 Inline comments on text selection — Local-only v1 via sidecar; notifications 🔮.
- 📋 Page comments (general thread) — Same.
- 📋 Comment resolution — Sidecar field.
- 🚧 Mentions of people, pages, dates — Pages via `[[ULID]]` ✅. People mentions 🔮. Date mentions 📋 (parse `@2026-05-14`).
- 🔮 Guest access (per-page) — Needs auth.
- 🔮 Share permissions (full access, edit, comment, read, no access) — Same.
- 🚧 Workspace member management — Settings page has a stub section (M11). Local user list 📋; server-side 🔮.
- 🔮 Groups / permission groups (paid) — Same.
- 📋 Page-level permissions — Frontmatter `permissions:` block, enforced by `EditorBloc` for the local user.
- 🔮 Suggest edits / suggestion mode (newer feature) — Needs collaborative branch/PR model.

## Formatting & Writing

- ✅ Markdown shortcuts (# for heading, ** for bold, etc.) — Native to source-mode editing.
- 📋 Equation editor — Math support, see Block Editor.
- 🚧 Mention dates (creates reminders) — Date strings render; reminder creation 📋.
- 📋 Reminders (with notifications) — `flutter_local_notifications`; store `reminders:` in frontmatter.
- 🚧 Date with time and time zones — Date property exists; timezone support 📋.
- 📋 Date ranges — Property type extension.
- 🔮 Mention people (notifies them) — Notifications require backend.
- 🚧 @-mention pages, people, dates — Pages via `[[` ✅; `@`-trigger UX 📋; people 🔮; dates 📋.

## Customization

- ✅ Light, dark, system theme — M0+, `theme_cubit.dart`.
- 📋 Custom emojis (paid) — Frontmatter `icon:` already accepts arbitrary paths/URLs; just expose an emoji picker.
- 📋 Sidebar customization — Reorderable sections, hideable items.
- 📋 Compact mode / small text toggle — Theme extension toggle; persist in settings.
- 📋 Font choice (default, serif, mono) per page — Frontmatter `font:`; renderer reads it. Inter and JetBrains Mono are already vendored.
- 📋 Full-width page toggle — Frontmatter `full_width: true`; renderer drops the max-width constraint.

## Templates

- 📋 Built-in template gallery — Seed files in `assets/templates/`; settings entry to import.
- 📋 Custom page templates — Convention: `Templates/` folder at vault root.
- 📋 Custom database templates — Schema `row_template:` field.
- 📋 Template duplication — Trivial once templates exist.
- 📋 Workspace-level templates — Same.

## Import & Export

- 📋 Import from: Evernote, Google Docs, Word, CSV, HTML, Markdown, Trello, Asana, Confluence, Quip, Dropbox Paper, Workflowy, Roam, plain text — Markdown is trivial (drop the file in the vault). CSV → database is most useful next (see CSV import). The rest are one-off converters in `lib/features/vault/data/datasources/importers/`.
- ✅ Export single page or whole workspace — M12, `lib/features/vault/data/exporter.dart`.
- 🚧 Export formats: Markdown + CSV, PDF, HTML — Markdown ✅. CSV/PDF/HTML 📋.
- ✅ Include subpages in export — M12.
- 🚧 Include databases in export (as CSV) — Row pages are exported as `.md` today. CSV emission 📋.

## Mobile-Specific

- 🚧 Mobile apps (iOS, Android) — Builds verified (M14); responsive shell (M13/M20). UX-optimized editor and database pages 📋.
- 🔮 Web clipper (browser extension that saves URLs into Notion) — Separate package; can write to a remote vault only via backend.
- 📋 Share sheet integration (save to Notion from any app) — Platform channel that writes a new `.md` into a configured Inbox folder.
- ✅ Offline access to recently opened pages — Local-first by design; the whole vault is on disk.
- 📋 Widgets (iOS/Android home screen) — Platform-specific, write-only ("Add to Inbox") is the natural first widget.

## Admin & Workspace

- 🚧 Workspace settings — M11 settings page; most sections are visual stubs.
- 🔮 Member directory — Multi-user.
- 🔮 Roles (owner, member, guest) — Same.
- 📋 Workspace icon and name — Vault-root `.quill.yaml` fields.
- ✅ Multiple workspaces per account — Vault switching in the picker.
- 🚫 Audit log (Enterprise) — Out of v1 scope for a self-hosted single-user app.
- 🚫 SAML SSO (Enterprise) — Same.
- 🚫 SCIM provisioning (Enterprise) — Same.
- 🚫 Domain management (Enterprise) — Same.
- 🚫 Data residency options (Enterprise) — Same.

## Sites / Publishing

- 🔮 Publish any page as a public site — Needs backend hosting.
- 🚫 Custom domain (paid) — Out of v1 scope.
- 🚫 SEO settings (title, description, sitemap) — Same.
- 🔮 Password-protected sites (paid) — Needs backend.
- 🚫 Search indexing toggle — Out of v1 scope.
- 🚫 Custom site navigation — Same.

## Forms

- 🔮 Notion Forms (create a form that submits rows to a database) — Public submission needs a hosted endpoint.
- 🔮 Form fields mapped to database properties — Same.
- 🔮 Conditional logic in forms — Same.
- 🔮 Public form URLs — Same.

## Misc

- 📋 Math/equation rendering (LaTeX via KaTeX) — See Block Editor; Pick-next #5.
- 📋 Mermaid diagrams in code blocks — Render fenced ```mermaid blocks via `flutter_mermaid` or a webview fallback.
- 📋 Color and background highlights — See Block Editor text color.
- 📋 Emoji picker — For `icon:` field and `:emoji:` shortcodes.
- 🚧 Undo/redo (Cmd+Z) — `TextField` provides native undo in source mode. Block-level undo arrives with the editable block model.
- 📋 Multi-select blocks (Shift+click, Cmd+A) — Block model dependency.
- 📋 Drag to reorder list items — Block model dependency.
- 📋 Convert between block types in place — Slash menu (#1) does this.
- 🚫 Print to PDF via browser — Quill isn't a web app. Native print → PDF is 📋 via the `printing` package.

---

## Pick-next queue

Top 10, ordered. Each is sized for one or two milestone commits. The first six mirror `CLAUDE.md`'s "What is NOT implemented" list; the next four come from this reconciliation.

1. ✅ **Slash command menu (`/`)** — Shipped **M23**. Files: `lib/features/editor/{domain/slash_entries,presentation/cubit/slash_menu_cubit,presentation/widgets/slash_menu_overlay}.dart` + hook in `source_view.dart`. 13 entries.
2. 🚧 **WYSIWYG editing** — Shipped a tractable MVP in **M40**: paragraph / heading / blockquote blocks are tap-to-edit in rendered mode. Each `_Block` carries a `(sourceStart, sourceEnd)` range; `_EditableBlock` swaps the rendered widget for a TextField on tap, splices the new source into the body on commit. Lists / tables / code / math / hr still require Source-mode toggle — true `super_editor` integration with a markdown serializer remains future work for users who want block-level cursor navigation and drag-drop reordering.
3. ✅ **Page hierarchy UX** — Shipped **M24**. Right-click / long-press on tree rows opens a context menu (folders get "New page here" + "Reveal", files get "Reveal" + "Copy ULID" + "Move to trash"). Folders also have a hover `+` icon for new subpages. Editor breadcrumbs already render via `PageHeader`.
4. ✅ **Page icons + covers** — Shipped **M26**. `lib/shared/widgets/page_icon.dart` renders `icon:` (emoji / asset / file / URL) and `cover:` as a hero band. Sidebar tree icons are deferred (would require extending VaultFile + the indexer).
5. 🚧 **Math (KaTeX) + Mermaid** — Math shipped **M32** via `flutter_math_fork` (pure Dart). `$$ ... $$` blocks render in `markdown_renderer.dart`; the slash menu inserts the snippet. Mermaid still deferred (needs webview).
6. ✅ **Image upload** — Shipped **M27**. Slash menu has "Image"; chosen file copies to `<vault>/attachments/<ULID>.<ext>` via `AttachmentWriter`, splices `![image](...)`. `markdown_renderer.dart` detects standalone `![alt](path)` paragraphs and renders inline. Clipboard paste / drag-drop are still TODO.
7. ✅ **Formula property type** — Shipped **M31**. `lib/features/database/domain/formula/formula.dart` (lexer + Pratt parser + evaluator). Subset: prop / bare ident, arithmetic, string concat, comparisons, logic, if(), helpers (round, length, upper, lower, contains, format, today, etc.). Rollup still TODO — the syntax parses but execution needs multi-row aggregation at the call site.
8. ✅ **Calendar + chart views** — Both shipped. Calendar **M33** via `table_calendar` (groups rows by date col onto a month/week grid). Chart **M34** via `fl_chart` (bar chart of row counts grouped by select col, with optional numeric-sum tooltips).
9. ✅ **Trash with restore** — Shipped **M28**. File context menu has "Move to trash"; renames to `.trash/<YYYY-MM>/<basename>.md` with collision avoidance. `.trash` is in `_ignoredDirs` across `VaultFsDatasource`, `Indexer`, and `VaultWatcher`. Restore is manual today (drag back from OS file browser); a dedicated Trash route is bonus work.
10. ✅ **Page version history** — Shipped **M30**. `lib/features/editor/data/page_history.dart` shells out to `git log -z` + `git show <sha>:<file>`. File context menu has "Page history" → opens a dialog with commit list + content viewer. The `.history/<ULID>/` fallback for non-git vaults is still TODO; a "Restore this version" button is also bonus work.

**Recently-shipped extras** (not in original top-10):

- **FTS5 search verification** (M25) — the FTS5 `MATCH` query in `SearchPages` is wired end-to-end through the palette; tests in `test/features/relations/search_pages_fts_test.dart`.
- **CSV import** (M29) — `lib/features/database/data/datasources/csv_importer.dart` + a "Import CSV as database" action in the command palette. Type inference, RFC 4180 parsing, title-column detection.

After this queue the next tier is: file watching polish (✅ M16), properties panel for un-implemented property types, settings completion, mobile-optimized editor/database pages (✅ M20), security-scoped bookmark persistence on macOS, share-sheet integration on mobile, slash-menu-enabled blocks (toggle/callout/columns).

The 🔮 tier — multiplayer, presence, comments-with-notifications, sharing, automations — should wait until the backend (Dart Frog/Serverpod + Postgres + Docker + sync) exists. See the original plan at `~/.claude/plans/build-prompt-self-hosted-transient-bear.md` for the backend sketch.
