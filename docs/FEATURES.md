# Feature roadmap — Quill (my_notion)

> Reconciliation of every Notion feature against what Quill has actually shipped (M0–M1690+), what is partially done, what is queued, and what is explicitly out of scope. The goal is that any agent landing in this repo for the first time can open this file, pick an item, follow the file pointers it includes, and ship it as the next milestone (Mxxxx) without re-discovering the codebase.

Read `CLAUDE.md` first for invariants and conventions. Read `~/.claude/plans/1m-run-until-we-frolicking-thompson.md` for the current 1m-loop plan (Phase A foundation → B media → C platform → D WYSIWYG → E V2 backend); the original milestone plan at `~/.claude/plans/build-prompt-self-hosted-transient-bear.md` is the historical pre-M30 blueprint. Then come back here.

## How to use this doc

1. Scan the **Pick-next queue** at the bottom — it's the prioritized work list. The top item is what you should pick.
2. Find the item in the categorized list to see which file(s) and patterns to touch.
3. Follow the **Architecture invariants** below — they are non-negotiable and they tell you *where* state lives (markdown frontmatter vs. drift vs. nowhere).
4. Ship as the next milestone commit `Mxxxx: <feature>`, matching the style of the existing 1,690+ milestones (commits use 4-digit milestone IDs once the count crosses M1000).

## Status legend

- ✅ **Shipped** — landed somewhere in M0–M1186+. Commit hash in parens when notable.
- 🚧 **Partial** — some of it works, the rest is queued in the 1m-loop plan (Phase B onward).
- 📋 **Backlog** — ready to pick up. No backend or new architecture required.
- 🔮 **v2 — requires backend** — needs the Dart Frog/Serverpod + Postgres + Docker layer (Phase E of the 1m-loop plan).
- 🚫 **Out of scope for v1** — Quill is a desktop/mobile self-hosted markdown editor, not a publishing platform or SaaS admin console. Reason given inline.

## Architecture invariants (don't break these while shipping a feature)

1. **Markdown on disk is the source of truth.** Every persistent piece of state goes in either YAML frontmatter or the markdown body. New fields → frontmatter. Round-trip must remain byte-identical for unedited pages (`test/core/markdown/frontmatter_parser_test.dart`).
2. **Drift is a derived cache.** `Indexer.reindex(root)` must reproduce identical `(pages, relations, databases)` state from disk. Never store user data only in SQLite (`test/integration/reindex_idempotent_test.dart`).
3. **All relations use `[[ULID]]`.** Page identity is the ULID in the frontmatter `id:` field, not the title or path. Titles, paths, and folders may change freely.

If your feature wants to store something new, the answer is almost always "add a frontmatter field and make the parser/indexer aware of it" — not "add a Drift column".

---

## Pages & Content

- ✅ Hierarchical nested pages (infinite depth) — Folder tree renders as page tree (`lib/features/vault/presentation/widgets/tree_node_widget.dart`). "New page here" subpage action via folder context menu + hover plus button (M24). M232 adds "New subfolder…" to the same folder context menu — creates an empty `Directory` via a new `CreateFolder` bloc event and emits an updated tree so the sidebar refreshes immediately. M233 routes the Workspace head's `+` button through a 2-choice `SimpleDialog` ("New page" / "New folder") so users can create a top-level folder without needing an existing parent. Breadcrumb already in PageHeader.
- ✅ Subpages and page-in-page — Folder-tree nesting + breadcrumb (above). Inline page cards via standalone `[[ULID]]` paragraphs (`_SubpageCard`); inline transclusion via `![[ULID]]` (`_TranscludedBlock`).
- ✅ Page icons (emoji, custom upload, Notion gallery) — M26, `lib/shared/widgets/page_icon.dart` renders frontmatter `icon:` (emoji / asset / file / URL). Emoji picker (M62) at `lib/shared/widgets/emoji_picker.dart`. Sidebar row icon (M84) shows the same glyph in db row cells. M253–M263 also surface page emoji icons in every place a page is listed: Workspace tree (M253), Favorites + Recent sidebar lists (M254), command palette page rows (M255), right-rail backlink cards (M256), standalone sub-page cards (M257), database Board / Timeline / Calendar views (M258 / M259), home-page Pinboard tiles + Recently-edited list (M263). All six "data-side" surfaces share the central `emojiFromFrontmatterJson` helper at `lib/core/markdown/frontmatter_icon.dart` (M262); the three "title-prefix" surfaces share `displayTitle(row)` / `rowIconString(row)` (M260 / M261). Asset / URL icons stay invisible everywhere since a 12–22px row can't render an async-loaded image.
- ✅ Page covers (image upload, URL, Unsplash, gallery) — M26 (editor hero band) + M92 (gallery card thumbnails). Unsplash search would need API integration.
- ✅ Page templates (built-in and custom) — Pages under `Templates/` surface as "New page from template…" in the command palette (`vault_shell_page.dart`). Duplicate copies the frontmatter + body and regenerates `id:`.
- ✅ Duplicate page (with or without subpages) — `DuplicatePage` event in `vault_bloc.dart`; context-menu entry on every file in the sidebar.
- ✅ Move page to another location — M55, drag a tree node onto a folder → `MovePage` event. Wikilinks survive since they use ULIDs. M231 adds a "Move to folder…" entry to the editor kebab — opens a `SimpleDialog` with every folder in the vault tree so users can relocate the open page without leaving the editor (useful on mobile where drag/drop is awkward).
- ✅ Page history / version history — M30, `lib/features/editor/data/page_history.dart` shells out to `git log -z` + `git show <sha>:<file>` when vault is a git repo. File context menu has "Page history".
- ✅ Page locking — Frontmatter `locked: true`; `EditorBloc.isLocked` toggles read-only mode; lock icon in PageHeader.
- ✅ Favorites / pinning — Pin via context menu; persists to `<vault>/.quill.yaml` `favorites: [...]`; Favorites section in sidebar. M252 also surfaces a small accent-coloured ★ glyph on each pinned page in the main Workspace tree so users see the pin state in-line without scrolling up to Favorites.
- ✅ Trash with restore — M28 + M61, file context menu → "Move to trash" renames to `.trash/<YYYY-MM>/...`; "Show trash" command palette entry opens a dialog with restore / delete-forever per row. M247 extends the database table row context menu with "Copy ULID" + "Move to trash" alongside the existing Open / Copy [[link]] / Duplicate entries.
- ✅ Page comments (general thread) — M69, `<vault>/.quill/comments/<page-ulid>.yaml` sidecar; properties-panel "Comments" action opens a dialog. Block-anchored comments shipped M180–M186.
- ✅ Page mentions (@page-name) — M5/M6 (`[[ULID]]` source format) + source_view.dart already opens the relation picker on a boundary `@` (line 136). Pick replaces the `@`-trigger with `[[ULID]]`, which the renderer shows as a clickable chip.
- ✅ Public page sharing via web link — Shipped at **E16/E17/E21/E43/E44** (Phase E backend). Frontmatter `public: true` exposes the page through the Dart Frog `GET /public/<ulid>` route (`backend/lib/public/routes.dart` + `markdown_html.dart` for the server-side renderer). Editor kebab "Publish" toggle flips the flag (`lib/features/sync/domain/usecases/build_public_password_entries.dart` and the wire-in at `editor_page.dart`). Password protection via `public_password:` frontmatter + bcrypt-checked cookie (E43/E44). Walkthrough: `docs/phase-e-sanity-checklist.md`.
- 🚫 Custom page URLs / domains (paid) — Quill is a desktop app, not a publishing platform.
- 🚫 Page analytics (views, visitors) — Same reason.
- ✅ Wiki mode (turn page into a wiki with owners and verification) — M159, frontmatter `wiki: true`, `owners: [...]`, `verified: <date>`. Editor PageHeader renders a colour-coded pill with owners + verified tooltip; flips to "wiki · stale" past 90 days.
- ✅ Breadcrumb navigation — PageHeader splits `page.relativePath` on `/` (M5+), `editor_page.dart:406`.
- ✅ Backlinks (auto-tracked references to a page) — M5, `lib/features/editor/presentation/widgets/backlinks_rail.dart`. Powered by `relations` table.

## Block Editor

- ✅ Block-based editing (everything is a block) — Tap-to-edit M40 (paragraphs / headings / blockquotes), M176 (list items with auto-renumber), M198 (code + math), M199 (tables — all via per-block source mode). hr is decorative-only. Full block-level cursor nav lands via the D29-default `EditorBetaPage` (super_editor at `/editor/:ulid` with the `editor.useBeta` toggle defaulting to `true` after M1670). The legacy per-block source-mode editor stays reachable through the opt-out toggle (Settings → Advanced) until D30 cutover deletes it.
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
- ✅ Block-level comments — Page-level M69. Block-id storage M180/M181, renderer-side `^<ULID>` suffix stripping M182, `CommentsDialog` blockId scope + per-row block badge M185, hover comment chip on rendered blocks M186 (auto-mints + splices a ULID if absent; opens scoped dialog).
- ✅ Block links (link to a specific block) — M79, `[[ULID#heading-slug]]`. Slug derived from heading text; editor page scrolls to the target heading on load.
- ✅ Turn block into another block type — Slash menu (M23+) converts the current line via `linePrefix` substitution.
- ✅ Text color and background color — Inline `<span style="color:…;background-color:…">` round-trips through the renderer; `<mark>` (M80) gives a soft-yellow highlight pill. M243 adds the `==text==` extension recognised by Obsidian / Pandoc — same soft-yellow rendering, also rewritten to `<mark>` in the HTML exporter, with a matching "Highlight" slash entry. M244 adds the Pandoc `~text~` / `^text^` extensions for subscript / superscript — single-line, single-delimiter, lower priority than `~~strike~~`. Renderer uses `FontFeature.subscripts() / .superscripts()` plus a smaller size; HTML emits `<sub>` / `<sup>`. Matching slash entries "Subscript" / "Superscript".
- ✅ Bold, italic, underline, strikethrough — All four; underline via `<u>` (M80) which round-trips byte-identical.
- ✅ Block backgrounds and text colors — Callouts (above) plus inline `<span style>` for runs.
- ✅ Bookmarks (rich link previews) — M42, standalone http(s) URL on its own line renders as a bookmark card with host + URL.
- ✅ Web bookmark blocks — Same M42 card.
- ✅ Buttons (templated multi-action blocks) — M70, `:::button` fence; actions: url / copy / reveal / page.
- ✅ Sub-page blocks — Standalone `[[ULID]]` renders as a sub-page card (M-something) via `_SubpageCard`.
- ✅ Link-to-page blocks — Via `[[ULID]]`.
- ✅ Table of contents block — `[toc]` renders an outline with clickable jump-to-heading links (M68).
- ✅ Breadcrumb block — M162, a line containing `[breadcrumb]` (or `[[breadcrumb]]`) renders the page's vault-relative path inline as mono crumbs. Slash menu entry; relativePath threaded through MarkdownRenderer.
- ✅ Columns and column lists — M66 (`:::cols` / `:::col` / `:::`).

## Media Blocks

- ✅ Image upload and embed — M27, slash-menu "Image" copies file to `<vault>/attachments/<ULID>.<ext>` and inserts `![alt](attachments/...)`.
- ✅ Image alignment, resize, full-width — M73, alt-text pipe modifiers `![Diagram|w=600|align=right](path)` / `|full`.
- ✅ Video upload and embed — File attachment chip M76 with movie icon. M201 renders video files as a prominent card (terracotta band). M1218 wires `VideoInlinePlayer` (`package:video_player`) into the card's top band for local mp4/mov/webm/avi/mkv files; tap-on-video toggles play/pause inline, tap-on-metadata still opens externally via `Reveal.openUrl`.
- ✅ Audio upload and embed — Same as video. M201 renders audio files as a prominent card (blue band). M1220 wires `AudioInlinePlayer` (`package:audioplayers`) into the band — play/pause + scrubber + duration label; tap on metadata still opens externally.
- ✅ File attachments — M76, `![label](path.ext)` for non-image extensions renders a clickable chip with extension icon + size.
- ✅ PDF embed and preview — M76 renders as a chip. M201 promotes PDFs to a prominent card (sage band). M1222 wires `PdfInlinePreview` (`package:pdfx`) into the card's sage band — renders the first page as a static thumbnail; tap on metadata still opens the full PDF externally.
- ✅ Image galleries (via database) — M87, `_FileChip` renders image extensions as 22-px thumbnails so a `files`-typed cell looks like a micro-gallery.

## Databases

- ✅ Database creation (full-page or inline) — Full-page via `.database.yaml` discovery (M7); inline embed via `:::db <folder>` fence (M78).
- ✅ Multiple views per database (table, board, list, gallery, calendar, timeline) — All six shipped (table M7, board M8, list M71, gallery M8, calendar M33, timeline M8) + chart (M34).
- Property types:
  - ✅ text, number, select, multi-select, status, date, checkbox, URL, email, phone — In `cell_renderers.dart`.
  - ✅ relation — `[[ULID]]` resolved at render via `title_resolver`.
  - ✅ ID — ULID.
  - ✅ last edited time — file `mtime`.
  - ✅ files & media — M87, image thumbnails + chip fallback for non-image extensions.
  - ✅ formula — M31, Pratt parser + evaluator subset of Notion formula v2.
  - ✅ rollup — M168, `type: rollup` columns with `relation:` + `target:` + `agg: sum|avg|min|max|count|list`. Pure RollupCompute runs before ApplyQuery so filters/sorts can use rollup values.
  - ✅ created time — `createdTime` column type added in earlier milestone; reads `created_at:` frontmatter.
  - ✅ created by, last edited by, person — M169 person column + PersonChip widget; M172 `.quill.yaml` `users:` list + EditorBloc auto-stamps `created_by:` (once) and `last_edited_by:` (every save) with `WorkspaceConfig.currentUserName`. Full server-side multi-user is 🔮.
  - ✅ button — M70 `:::button` fence renders inside any page (including row pages).
- ✅ Sub-items (parent/child rows) — Parent relation column + depth indent (frozen_column_table.dart). M166 adds the chevron toggle on rows that have children + a visible-rows filter that hides descendants of collapsed parents.
- ✅ Dependencies between rows — M163, frontmatter `depends_on: [[ULID]], …`. Timeline view shows a "↳ N" pill in the frozen column with tooltip, plus L-shaped connector arrows between bars.
- ✅ Database templates (per-database row templates) — `row_template:` in schema; `createRow` copies the template's frontmatter + body.
- ✅ Filters (single and compound with AND/OR logic) — M19.
- ✅ Sorts (multi-level) — M19. M245 adds the quick-sort UX: clicking a column header in the table view cycles that column through asc → desc → off, writes through `DatabaseQuery.sorts`, and the header gains a bold name + ▲/▼ glyph while sorted. M246 adds a right-click / long-press context menu on the same headers — Sort ascending / descending / clear, Group by this column / Ungroup, Filter by this column…, Hide column. The "Filter" entry routes to the existing FilterPopover so multi-rule filters are still composable.
- ✅ Grouping (by any property) — M19.
- ✅ Sub-grouping — M86 BoardView, M177 TableView, M183 GalleryView, M184 ListView, M187 TimelineView, M195 CalendarView, M196 ChartView (stacked bars + legend). All seven views.
- ✅ Hide/show properties per view — M72, Properties popover; persists per-database (M96).
- ✅ Reorder properties — Long-press-drag column headers (M63); persistence per-database in SharedPreferences (M97).
- ✅ Property width adjustment — Resize handle on the right edge (M56); persisted per-database in SharedPreferences (M97).
- ✅ Frozen columns in table view — M7.
- ✅ Calculations per column (sum, average, count, min, max, range, etc.) — M43 footer row.
- ✅ Wrap cells / unwrap — Toggle in toolbar; persists per-database (M95).
- ✅ Open row as a full page — Click a row → /editor/<ulid>.
- ✅ Row icons and covers — M84 table/list/gallery read `icon:` frontmatter; M92 gallery cards render `cover:`.
- ✅ Linked database views — M88 extends `:::db` with `view:` + `limit:` props inside the fence.
- ✅ Database mentions / inline databases — M78 + M88, `:::db <folder>` fence with optional view config.
- ✅ Relations between databases (one-way and two-way) — One-way ✅ via `[[ULID]]`. Two-way ✅ M173 via `inverse_of: <key>` on the relation column; the repo propagates ULID adds/removes to the linked page's inverse column on every updateCell.
- ✅ Rollups (aggregate from related rows) — M168, see the `rollup` bullet in the column-type list above.
- ✅ Formulas (Notion formula language v2) — M31.
- ✅ Buttons inside rows that trigger actions — M70.
- 🔮 Automations (no-code rules: when X changes, do Y) — Requires backend daemon.
- ✅ Database locking — M161, schema `locked: true` in `.database.yaml`. Table view drops edit/add/duplicate callbacks and the header shows a "locked" pill.
- ✅ CSV import — M29.
- ✅ CSV export — M45.
- ✅ Markdown export (with subpages) — M12.
- ✅ HTML export — M44 `HtmlExporter`.
- ✅ PDF export — M50 `PdfExporter`.

## Views

- ✅ Table view — M7.
- ✅ Board (Kanban) view — M8.
- ✅ List view — M71, compact one-line-per-row.
- ✅ Gallery view (card grid) — M8 + M92 cover images.
- ✅ Calendar view — M33 via `table_calendar`.
- ✅ Timeline view (Gantt-style) — M8.
- ✅ Chart view (bar, line, donut) — M34 via `fl_chart`.
- ✅ View-specific filters, sorts, properties — Property selection via Properties popover (M72) + per-database persistence (M96).
- ✅ Group and sub-group per view — Group ✅. Sub-group BoardView M86, TableView M177, GalleryView M183, ListView M184, TimelineView M187, CalendarView M195, ChartView M196.
- ✅ Customize card size, preview image, fields shown — Cover images M92, card-size S/M/L M165 (per-database persisted), configurable fields M167 via `views[].card_fields: [...]` (renderer special-cases stage/status/priority → TagChip, arr/mrr/revenue → $k, ISO date → mono pill).

## Search & Navigation

- ✅ Global search (Cmd/Ctrl + P) — M25, ⌘K palette runs FTS5 `MATCH` against `pages_fts` for non-command queries; M85 adds in-page Cmd+F.
- ✅ Quick find with filters (by author, date, in page) — In-page filter via Cmd+F (M85). M249 adds ⌘G / ⌘⇧G to step to next / previous match without leaving the keyboard. Cross-vault chips `db:`, `tag:`, `in:` / `path:` / `folder:` (with optional `@` prefix) in Cmd+K (M164).
- ✅ Recent pages — Sidebar Recent section reads drift by `mtime`.
- ✅ Sidebar with workspaces, favorites, private, shared, teamspaces — Vault tree ✅. Favorites ✅. Sidebar filter (M90), workspace icon picker (M107). Private/shared/teamspaces 🔮.
- 🔮 Teamspaces (group pages by team) — Multi-user concept.
- ✅ Keyboard shortcuts (extensive) — `vault_shell_page.dart` `CallbackShortcuts`; M99 dialog (`?`) lists every binding.
- ✅ Cmd+K command menu — M9.

## Collaboration

- 🔮 Real-time multiplayer editing — Needs CRDT layer + backend.
- 🔮 Cursor presence (see others typing) — Same.
- ✅ Inline comments on text selection — Block-level M180–M186 is the closest analogue: each rendered block (paragraph / heading) can carry its own anchored thread. True character-range inline comments (mid-paragraph highlights) are out of scope for v1.
- ✅ Page comments (general thread) — M69 sidecar at `<vault>/.quill/comments/<page-ulid>.yaml`; "Comments" action in properties panel.
- ✅ Comment resolution — `resolved: true` field on each comment; M69 toggle in the dialog.
- ✅ Mentions of people, pages, dates — Pages via `[[ULID]]` + anchor variant (M79). Date pills via inline `@YYYY-MM-DD` (M83 relative-time variants). People mentions 🔮.
- 🔮 Guest access (per-page) — Needs auth.
- 🔮 Share permissions (full access, edit, comment, read, no access) — Same.
- 🚧 Workspace member management — Settings → Users pane (M188) lists `.quill.yaml` `users:`, lets the user add / remove / toggle the default. Server-side identity / invites / per-page ACLs remain 🔮.
- 🔮 Groups / permission groups (paid) — Same.
- ✅ Page-level permissions — M170, frontmatter `permissions: read_only` / `read-only` / `readonly` / `locked` makes the page read-only (case-insensitive). Other values (`private`, `team_only`) are documentation-only — full multi-user enforcement is 🔮.
- 🔮 Suggest edits / suggestion mode (newer feature) — Needs collaborative branch/PR model.

## Formatting & Writing

- ✅ Markdown shortcuts (# for heading, ** for bold, etc.) — Native to source-mode editing.
- ✅ Equation editor — M32 inline + block via `flutter_math_fork`.
- ✅ Mention dates (creates reminders) — Date pills render (M83). M89 surfaces a `reminder:` frontmatter badge in PageHeader. M211 lists upcoming reminders on the home page (7-day window, overdue → red). M230 adds a "Set reminder…" entry to the editor kebab. M1224-M1230 ship OS notification dispatch via `flutter_local_notifications` + `lib/features/reminders/` Bloc + presentation-layer bridge in `editor_page.dart`.
- ✅ Reminders (with notifications) — M89 / M211 / M230 surface badge / list / kebab; M1224-M1230 ship OS notifications via `flutter_local_notifications ^20.1.0`, `lib/features/reminders/` (NotificationScheduler datasource + RemindersBloc with sequential transformer), and a presentation-layer BlocListener in `editor_page.dart` that bridges EditorBloc `reminder:` frontmatter changes to RemindersBloc. Android POST_NOTIFICATIONS permission declared in manifest; iOS/macOS request via DarwinInitializationSettings.
- ✅ Date with time and time zones — M82, ISO `YYYY-MM-DDTHH:MM[(Z|±HH:MM)]` formatted as `YYYY-MM-DD · HH:MM tz` in DB cells.
- ✅ Date ranges — M74, `YYYY-MM-DD..YYYY-MM-DD` renders with arrow.
- 🔮 Mention people (notifies them) — Notifications require backend.
- ✅ @-mention pages, people, dates — `@` trigger opens the page picker in source mode (same overlay as `[[`); date pill via `@YYYY-MM-DD`; today's date via slash menu (M103). People mentions 🔮.
- ✅ Word count + reading time per page — PageFooter renders `<n> words · <n> chars · ~<n> min read` below the editor body. M248 adds a "Set word count goal…" entry to the editor kebab — writes `goal: <N>` to frontmatter so the footer's existing progress bar surfaces. Empty input clears the goal.

## Customization

- ✅ Light, dark, system theme — M0+; settings UI in M100.
- ✅ Custom emojis (via picker) — M62 emoji picker; works for both page icons (M26) and workspace icon (M107). M242 adds an "Emoji…" slash menu entry — the same picker pops over the editor and inserts the chosen glyph at the caret.
- ✅ Sidebar customization — Filter (M90), collapse (M109), favorites pinning, reorderable + hideable sections via `.quill.yaml` `sidebar.order:` / `sidebar.hidden:` (M171); Settings → Sidebar pane UI for the same (M204).
- ✅ Compact mode / small text toggle — M57 + M100 settings UI.
- ✅ Font choice (default, serif, mono) per page — M160, frontmatter `font: serif | mono | default`. MarkdownRenderer wraps the body in DefaultTextStyle.merge with Georgia / JetBrainsMono.
- ✅ Full-width page toggle — M46 frontmatter `full_width: true`.

## Templates

- ✅ Built-in template gallery — M106, "Install built-in templates" command writes five curated templates (Meeting / Weekly Review / Decision log / Project plan / Reading notes) into `<vault>/Templates/`.
- ✅ Custom page templates — Anything dropped under `Templates/` shows in "New page from template…".
- ✅ Custom database templates — `row_template:` in `.database.yaml` seeds new rows' frontmatter + body.
- ✅ Template duplication — Reuses DuplicatePage; the "New from template…" flow is a duplicate-then-rename.
- ✅ Workspace-level templates — Same.

## Import & Export

- ✅ Import from: Evernote, Google Docs, Word, CSV, HTML, Markdown, Trello, Asana, Confluence, Quip, Dropbox Paper, Workflowy, Roam, plain text — CSV → database M29. HTML → page M175 (also works for Quip / Dropbox Paper / Google Docs HTML / Confluence storage-format HTML via the generic converter). Markdown + plain text → page M178. OPML / Workflowy outlines → page M189. Roam JSON → multi-page M190. Trello board JSON → database (with board view) M191. Asana CSV → database (with kanban) M192. Evernote .enex → multi-page M193. Word .docx (OOXML ZIP/XML) → page M194.
- ✅ Export single page or whole workspace — M12 (single page → .md from editor kebab), M229 adds single-page → .html (self-contained, CSS inlined).
- ✅ Export formats: Markdown + CSV, PDF, HTML — Markdown M12, CSV M45, HTML M44 (whole vault) + M229 (single page), PDF M50. All wired into Settings → Export & Backup (M101).
- ✅ Include subpages in export — M12.
- ✅ Include databases in export (as CSV) — M45 CSV exporter.

## Mobile-Specific

- ✅ Mobile apps (iOS, Android) — Builds verified (M14); responsive shell (M13/M20). New page FAB on the mobile shell (M197). Responsive command palette + slash menu widths (M206, M207). Mobile database table auto-falls-back to list rendering (M209). Outline + footer auto-show on mobile.
- 🔮 Web clipper (browser extension that saves URLs into Notion) — Separate package; can write to a remote vault only via backend.
- 🚧 Share sheet integration (save to Notion from any app) — In-app Quick capture analogue M210 (⌘. opens a dialog → prepends to `Inbox/Quick capture.md` with a timestamp). **Outbound** OS share-sheet shipped at M1240 (`share_plus`, editor-kebab "Share…" routes current page through OS sheet). **Inbound** share (open-in-Quill from Safari etc.) requires iOS share extension Xcode setup; remains on the backlog as a follow-up slice.
- ✅ Offline access to recently opened pages — Local-first by design; the whole vault is on disk.
- 📋 Widgets (iOS/Android home screen) — Platform-specific, write-only ("Add to Inbox") is the natural first widget.

## Admin & Workspace

- ✅ Workspace settings — M11 → M100 (Appearance) / M101 (Export) / M102 (Advanced). Vault pane has name + path + stats.
- 🔮 Member directory — Multi-user.
- 🔮 Roles (owner, member, guest) — Same.
- ✅ Workspace icon and name — M107 (icon picker) + M108 (name override) write to `<vault>/.quill.yaml`.
- ✅ Multiple workspaces per account — Vault switching in the picker; CloseVault (M75) returns to picker.
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

- ✅ Math/equation rendering (LaTeX via KaTeX) — M32, `flutter_math_fork`.
- ✅ Mermaid diagrams in code blocks — M200 styles fenced ```mermaid blocks with an accent border. M1232-M1234 wire native rendering via `webview_flutter` hosting a vendored `assets/mermaid/mermaid.min.js` (mermaid@10.9.4, offline-only — no CDN dependency for the macOS sandbox). iOS/Android/macOS render the diagram; Linux/Windows fall back to a styled source-text card.
- ✅ Color and background highlights — Inline `<span style>` for colours + `<mark>` (M80) for soft-yellow highlight; callouts for block-level colour.
- ✅ Emoji picker — M62, `lib/shared/widgets/emoji_picker.dart`. Used by page icons (M26) and workspace icon (M107).
- ✅ Undo/redo (Cmd+Z) — Native TextField undo in source mode + bloc-level `UndoEdit`/`RedoEdit` (M179): bounded 50-entry stacks, ⌘Z / ⌘⇧Z, every body + frontmatter mutation pushes the prior Page snapshot.
- ✅ Multi-select blocks — M203, hover-checkbox per block + floating `_SelectionToolbar` (Select all / Copy / Delete / Cancel). Selected blocks gain a left-accent border. M205 adds the ⌘A / ⌘⌫ / Esc keyboard shortcuts and surfaces them in the shortcut help dialog.
- ✅ Drag to reorder list items — Block-level drag M65; item-within-list drag M174 (`_ListItemDragWrap` + pure `ListReorder` helpers; ordered lists renumber on drop).
- ✅ Convert between block types in place — Slash menu's linePrefix substitution.
- ✅ Native print → PDF — M50 via `pdf` + `printing` packages.

---

## Pick-next queue

Top 10, ordered. Each is sized for one or two milestone commits. The first six mirror `CLAUDE.md`'s "What is NOT implemented" list; the next four come from this reconciliation.

1. ✅ **Slash command menu (`/`)** — Shipped **M23**. Files: `lib/features/editor/{domain/slash_entries,presentation/cubit/slash_menu_cubit,presentation/widgets/slash_menu_overlay}.dart` + hook in `source_view.dart`. 13 entries.
2. 🚧 **WYSIWYG editing** — MVP M40 (paragraph / heading / blockquote tap-to-edit) extended M176 (list items, ul + ol with auto-renumber), M198 (code + math), M199 (tables — all via per-block source mode). Each `_Block` carries a `(sourceStart, sourceEnd)` range; `_EditableBlock` / `_EditableListItem` swap the rendered widget for a TextField on tap, splice the new source via `ListReorder.emit` (renumbers ol) and dispatch `onBodyChange`. Hover chrome grows a per-block delete chip M202 + comment chip M186 alongside the drag handle M65. hr is decorative. True `super_editor` integration with a markdown serializer remains future work for users who want block-level cursor navigation and drag-drop reordering.
3. ✅ **Page hierarchy UX** — Shipped **M24**. Right-click / long-press on tree rows opens a context menu (folders get "New page here" + "Reveal", files get "Reveal" + "Copy ULID" + "Move to trash"). Folders also have a hover `+` icon for new subpages. Editor breadcrumbs already render via `PageHeader`.
4. ✅ **Page icons + covers** — Shipped **M26**. `lib/shared/widgets/page_icon.dart` renders `icon:` (emoji / asset / file / URL) and `cover:` as a hero band. Sidebar tree icons are deferred (would require extending VaultFile + the indexer).
5. ✅ **Math (KaTeX) + Mermaid** — Math shipped **M32** via `flutter_math_fork` (pure Dart). `$$ ... $$` blocks render in `markdown_renderer.dart`; the slash menu inserts the snippet. Mermaid native rendering shipped at **C1** (`lib/shared/widgets/mermaid_view.dart`) — `webview_flutter: ^4.13.1` host with the vendored `assets/mermaid/mermaid.min.js` (3.3 MB) inlined into a `loadHtmlString` scaffold. `_MermaidPlaceholder` (M200) was replaced by `MermaidView` and is now called from `markdown_renderer.dart:2588` for both editor modes. Linux / Windows / web / test environments fall back to a styled source-text card (the original M200 behaviour). M1686 extracted the HTML scaffold into a `mermaidHtmlFor()` pure-Dart helper for direct unit-test coverage of escaping + not-vendored fallback invariants.

### Source-mode markdown shortcuts (M234)

Cmd/Ctrl + B → wrap selection in `**bold**`. Cmd/Ctrl + I → wrap selection in `*italic*`. Cmd/Ctrl + Shift + X → wrap selection in `~~strikethrough~~`. Cmd/Ctrl + Shift + C → wrap selection in `` `inline code` ``. All four reuse the same `_wrapSelection(pre, post)` helper in `source_view.dart`; if no selection is active the caret lands between the inserted markers.

### Source-mode line ops (M235 – M240)

Cmd/Ctrl + D duplicates the line under the caret and keeps the caret at the same column on the copy. Alt + ↑ / Alt + ↓ (M236) swap the current line with the one above / below; the trailing-newline empty line is treated as non-content so the down-swap no-ops at end-of-file. Cmd/Ctrl + / (M237) toggles an HTML comment around the current line — wraps with `<!-- ` / ` -->` (markdown renderers treat that as a no-op so the content stays in the source but disappears from the rendered view), and unwraps round-trip when re-invoked. Cmd/Ctrl + Shift + K (M238) deletes the line under the caret and re-anchors the caret at the same column on the line that takes its place. Cmd/Ctrl + L (M239) selects the current line — handy as a precursor to ⌘B / ⌘I / ⌘⇧X / ⌘⇧C wrap actions.

Enter on a list line (M240) continues the list with the same marker — bullets (`- `, `* `), ordered (`<n>. ` auto-increments), unchecked todos (`- [ ] `), and checked todos (`- [x] ` continues as a fresh `- [ ] `). Pressing Enter on an empty list item strips the marker and lands the caret on a bare new line — the standard "press Enter twice to exit the list" UX. Shift + Enter keeps the platform's plain-newline behaviour. Indentation is preserved across continuations.

Backspace on an empty list item (M241) strips the marker but keeps the indent — the other half of the "exit the bullet" UX. Only fires when the caret sits at the end of the marker with no body content and no modifier keys held; everything else falls through to platform Backspace.

Cmd/Ctrl + J (M250) joins the current line with the next — replaces the separating `\n` with a single space (or nothing if the current line already ends in whitespace) and strips leading whitespace from the next line so the join reads as flowing prose. Caret lands at the join point. No-op on the final content line.

Cmd/Ctrl + Shift + 1/2/3 (M268) converts the current line to a `#`/`##`/`###` heading. Idempotent — replaces any existing heading/list/quote/todo marker rather than stacking, so ⌘⇧2 on `# foo` produces `## foo` (not `## # foo`). Built on a pure `applyLinePrefix(text, caret, prefix)` helper that's also reusable for other one-key block-type conversions later.

All ten transformations live in pure helpers (`duplicateLineAt`, `moveLineUp`, `moveLineDown`, `toggleCommentLine`, `deleteLineAt`, `lineRangeAt`, `continueListAtNewline`, `backspaceListMarker`, `joinLineWithNext`, `applyLinePrefix`) at `lib/features/editor/domain/source_line_ops.dart` and are unit-tested independently of the widget tree (60 cases).
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
