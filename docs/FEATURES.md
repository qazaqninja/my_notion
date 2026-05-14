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
- ✅ Page icons (emoji, custom upload, Notion gallery) — M26, `lib/shared/widgets/page_icon.dart` renders frontmatter `icon:` (emoji / asset / file / URL). Emoji picker (M62) at `lib/shared/widgets/emoji_picker.dart`. Sidebar row icon (M84) shows the same glyph in db row cells.
- ✅ Page covers (image upload, URL, Unsplash, gallery) — M26 (editor hero band) + M92 (gallery card thumbnails). Unsplash search would need API integration.
- ✅ Page templates (built-in and custom) — Pages under `Templates/` surface as "New page from template…" in the command palette (`vault_shell_page.dart`). Duplicate copies the frontmatter + body and regenerates `id:`.
- ✅ Duplicate page (with or without subpages) — `DuplicatePage` event in `vault_bloc.dart`; context-menu entry on every file in the sidebar.
- ✅ Move page to another location — M55, drag a tree node onto a folder → `MovePage` event. Wikilinks survive since they use ULIDs.
- ✅ Page history / version history — M30, `lib/features/editor/data/page_history.dart` shells out to `git log -z` + `git show <sha>:<file>` when vault is a git repo. File context menu has "Page history".
- ✅ Page locking — Frontmatter `locked: true`; `EditorBloc.isLocked` toggles read-only mode; lock icon in PageHeader.
- ✅ Favorites / pinning — Pin via context menu; persists to `<vault>/.quill.yaml` `favorites: [...]`; Favorites section in sidebar.
- ✅ Trash with restore — M28 + M61, file context menu → "Move to trash" renames to `.trash/<YYYY-MM>/...`; "Show trash" command palette entry opens a dialog with restore / delete-forever per row.
- ✅ Page comments (general thread) — M69, `<vault>/.quill/comments/<page-ulid>.yaml` sidecar; properties-panel "Comments" action opens a dialog. Inline (range-scoped) comments still 📋 — need block ids first.
- 🚧 Page mentions (@page-name) — `[[ULID]]` works (M5/M6). The `@` UX sugar to open the same picker is 📋. M103 added "Today's date" but not page mention.
- 🔮 Public page sharing via web link — Requires hosting backend.
- 🚫 Custom page URLs / domains (paid) — Quill is a desktop app, not a publishing platform.
- 🚫 Page analytics (views, visitors) — Same reason.
- 📋 Wiki mode (turn page into a wiki with owners and verification) — Frontmatter `wiki: true`, `owners: [...]`, `verified: <date>`. Render badge in editor header.
- 📋 Breadcrumb navigation — Derive from the file's path within the vault. Render at the top of `editor_page.dart`.
- ✅ Backlinks (auto-tracked references to a page) — M5, `lib/features/editor/presentation/widgets/backlinks_rail.dart`. Powered by `relations` table.

## Block Editor

- 🚧 Block-based editing (everything is a block) — Tap-to-edit MVP shipped M40 (paragraphs / headings / blockquotes); list / table / code / math need source-mode toggle. Full block-level cursor nav still needs super_editor.
- ✅ **Slash command menu (/)** — M23+. 19 entries including all block types, image picker, button (M70), inline database (M78), today's date (M103).
- ✅ Drag and drop blocks — M65, `_BlockDragWrap` on every block. Hover-revealed handle on the left margin; drop reorders via source-offset splicing.
- ✅ Multi-column layouts — M66, `:::cols` / `:::col` / `:::` fence.
- ✅ Toggle (collapsible) blocks — `<details><summary>` round-trips through the renderer; M81 also makes heading rows collapsible via a chevron icon.
- ✅ Toggle headings — M81, h1/h2/h3 each get a collapse chevron that hides blocks until the next same-or-higher heading.
- ✅ Headings (H1, H2, H3) — `markdown_renderer.dart`.
- ✅ Bulleted, numbered, and to-do lists — `markdown_renderer.dart`.
- ✅ Nested list indentation — `markdown_renderer.dart`.
- ✅ Quote blocks — `markdown_renderer.dart`.
- ✅ Callout blocks with custom icons and colors — GFM admonition `> [!NOTE|TIP|IMPORTANT|WARNING|CAUTION]` renders coloured blocks in `markdown_renderer.dart`.
- ✅ Divider lines — `markdown_renderer.dart`.
- ✅ Code blocks with syntax highlighting for 60+ languages — Code fence renders mono; language label (M93) + hover-revealed copy button (M91). Full highlighting via `flutter_highlight` queued.
- ✅ Inline code formatting — `markdown_renderer.dart`.
- ✅ Math equations (KaTeX) — block and inline — M32 via `flutter_math_fork`. `$inline$` and `$$block$$` both render.
- ✅ Tables (simple, non-database) — GFM pipe tables render in `markdown_renderer.dart`.
- ✅ Synced blocks (edit in one place, updates everywhere) — M67, `![[ULID]]` transclusion. Cycle-safe up to maxDepth = 3.
- 📋 Block-level comments — Needs block ids first; page-level comments shipped M69.
- ✅ Block links (link to a specific block) — M79, `[[ULID#heading-slug]]`. Slug derived from heading text; editor page scrolls to the target heading on load.
- ✅ Turn block into another block type — Slash menu (M23+) converts the current line via `linePrefix` substitution.
- ✅ Text color and background color — Inline `<span style="color:…;background-color:…">` round-trips through the renderer; `<mark>` (M80) gives a soft-yellow highlight pill.
- ✅ Bold, italic, underline, strikethrough — All four; underline via `<u>` (M80) which round-trips byte-identical.
- ✅ Block backgrounds and text colors — Callouts (above) plus inline `<span style>` for runs.
- ✅ Bookmarks (rich link previews) — M42, standalone http(s) URL on its own line renders as a bookmark card with host + URL.
- ✅ Web bookmark blocks — Same M42 card.
- ✅ Buttons (templated multi-action blocks) — M70, `:::button` fence; actions: url / copy / reveal / page.
- ✅ Sub-page blocks — Standalone `[[ULID]]` renders as a sub-page card (M-something) via `_SubpageCard`.
- ✅ Link-to-page blocks — Via `[[ULID]]`.
- ✅ Table of contents block — `[toc]` renders an outline with clickable jump-to-heading links (M68).
- 📋 Breadcrumb block — Derive from path. PageHeader already has breadcrumbs; a body-level block is still 📋.
- ✅ Columns and column lists — M66 (`:::cols` / `:::col` / `:::`).

## Media Blocks

- ✅ Image upload and embed — M27, slash-menu "Image" copies file to `<vault>/attachments/<ULID>.<ext>` and inserts `![alt](attachments/...)`.
- ✅ Image alignment, resize, full-width — M73, alt-text pipe modifiers `![Diagram|w=600|align=right](path)` / `|full`.
- 🚧 Video upload and embed — Detected as file attachment (M76) with movie icon, opens in OS player. Inline `<video>` rendering still 📋.
- 🚧 Audio upload and embed — Same as video; M76 chip with audio icon.
- ✅ File attachments — M76, `![label](path.ext)` for non-image extensions renders a clickable chip with extension icon + size.
- 🚧 PDF embed and preview — M76 renders as a chip that opens in OS default app. Inline preview via `pdfx` still 📋.
- ✅ Image galleries (via database) — M87, `_FileChip` renders image extensions as 22-px thumbnails so a `files`-typed cell looks like a micro-gallery.

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
