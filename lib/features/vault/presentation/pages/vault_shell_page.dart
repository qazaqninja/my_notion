import 'dart:io';
import 'dart:math' as math;

import '../../../../core/paths.dart';

import 'package:drift/drift.dart' as drift;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/db/quill_database.dart' as db_models
    show Page;
import '../../../../core/db/quill_database.dart' hide Page;
import '../../domain/usecases/pick_page.dart';
import '../../../../core/markdown/frontmatter_icon.dart';
import '../../../../core/markdown/yaml_scalar.dart';
import '../../../../core/platform/reveal.dart';
import '../../../../core/ulid/ulid_generator.dart';
import '../../../../shared/theme/quill_tokens.dart';
import '../../../../shared/widgets/quill_icon.dart';
import '../../../../shared/widgets/quill_overlays.dart';
import '../../../../shared/theme/tokens.dart';
import '../../../../shared/theme/app_theme_mode.dart';
import '../../../../shared/theme/theme_cubit.dart';
import '../../../commands/presentation/cubit/command_palette_cubit.dart';
import '../../../commands/presentation/widgets/command_palette_overlay.dart';
import '../../data/html_page_importer.dart';
import '../../data/opml_page_importer.dart';
import '../../data/asana_csv_importer.dart';
import '../../data/daily_note.dart';
import '../../data/docx_page_importer.dart';
import '../../data/enex_page_importer.dart';
import '../../data/quick_capture.dart';
import '../../data/roam_page_importer.dart';
import '../../data/text_page_importer.dart';
import '../../data/trello_database_importer.dart';
import '../../data/url_bookmark.dart';
import '../../../database/domain/repositories/database_repository.dart';
import '../../../relations/domain/usecases/search_pages.dart';
import '../../../../shared/widgets/responsive_layout.dart';
import '../../data/exporter.dart';
import '../../data/seed_templates.dart';
import '../../data/html_exporter.dart';
import '../../data/pdf_exporter.dart';
import '../bloc/vault_bloc.dart';
import '../bloc/vault_event.dart';
import '../bloc/vault_state.dart';
import '../widgets/mobile_chrome.dart';
import '../widgets/sidebar_widget.dart';
import '../widgets/trash_dialog.dart';

/// Desktop shell — sidebar on the left, child route content on the right,
/// ⌘K / Ctrl+K command palette on top.
class VaultShellPage extends StatefulWidget {
  const VaultShellPage({super.key, required this.child, this.activeUlid});

  final Widget child;
  final String? activeUlid;

  @override
  State<VaultShellPage> createState() => _VaultShellPageState();
}

class _VaultShellPageState extends State<VaultShellPage> {
  CommandPaletteCubit? _palette;
  final FocusNode _rootFocus = FocusNode(skipTraversal: true);
  bool _sidebarCollapsed = false;
  double _sidebarWidth = 260;
  static const double _minSidebar = 180;
  static const double _maxSidebar = 420;
  static const String _prefSidebarWidth = 'sidebar.width';

  @override
  void initState() {
    super.initState();
    _restoreSidebarWidth();
  }

  Future<void> _restoreSidebarWidth() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getDouble(_prefSidebarWidth);
    if (v == null || !mounted) return;
    setState(() {
      _sidebarWidth = v.clamp(_minSidebar, _maxSidebar);
    });
  }

  Future<void> _saveSidebarWidth(double w) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_prefSidebarWidth, w);
  }

  CommandPaletteCubit _cubit(BuildContext context) {
    return _palette ??= CommandPaletteCubit(
      searchPages: SearchPages(context.read<QuillDatabase>()),
      dbRepo: context.read<DatabaseRepository>(),
      db: context.read<QuillDatabase>(),
    );
  }

  @override
  void dispose() {
    _palette?.close();
    _rootFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    return BlocProvider<CommandPaletteCubit>.value(
      value: _cubit(context),
      child: BlocListener<VaultBloc, VaultState>(
        // Global VaultError → snackbar so the bloc's transient
        // VaultError → VaultLoaded re-emit (Move / Duplicate / Folder
        // create) doesn't fail silently.
        listenWhen: (prev, next) => next is VaultError && prev is! VaultError,
        listener: (context, state) {
          if (state is! VaultError) return;
          context.toastError(state.message);
        },
        child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () {
            _cubit(context).open();
          },
          const SingleActivator(LogicalKeyboardKey.keyK, control: true): () {
            _cubit(context).open();
          },
          const SingleActivator(LogicalKeyboardKey.keyR, meta: true): () {
            _invokeAction(context, 'Reindex vault');
          },
          const SingleActivator(LogicalKeyboardKey.keyR, control: true): () {
            _invokeAction(context, 'Reindex vault');
          },
          const SingleActivator(LogicalKeyboardKey.keyR, meta: true, shift: true): () {
            _invokeAction(context, 'Reveal vault in Finder');
          },
          const SingleActivator(LogicalKeyboardKey.keyR, control: true, shift: true): () {
            _invokeAction(context, 'Reveal vault in Finder');
          },
          const SingleActivator(LogicalKeyboardKey.keyN, meta: true): () =>
              _newPage(context),
          const SingleActivator(LogicalKeyboardKey.keyN, control: true): () =>
              _newPage(context),
          const SingleActivator(LogicalKeyboardKey.keyN,
              meta: true, shift: true): () =>
              _invokeAction(context, "Open today's daily note"),
          const SingleActivator(LogicalKeyboardKey.keyN,
              control: true, shift: true): () =>
              _invokeAction(context, "Open today's daily note"),
          const SingleActivator(LogicalKeyboardKey.slash, shift: true): () =>
              _showShortcuts(context),
          // Cmd/Ctrl + ? mirrors `?` but survives inside text fields
          // (where bare ? is a normal character). Common macOS / VS Code
          // convention for "show shortcut help".
          const SingleActivator(LogicalKeyboardKey.slash,
              shift: true, meta: true): () => _showShortcuts(context),
          const SingleActivator(LogicalKeyboardKey.slash,
              shift: true, control: true): () => _showShortcuts(context),
          const SingleActivator(LogicalKeyboardKey.backslash, meta: true): () =>
              setState(() => _sidebarCollapsed = !_sidebarCollapsed),
          const SingleActivator(LogicalKeyboardKey.backslash, control: true): () =>
              setState(() => _sidebarCollapsed = !_sidebarCollapsed),
          const SingleActivator(LogicalKeyboardKey.bracketLeft, meta: true): () =>
              _navigateBack(context),
          const SingleActivator(LogicalKeyboardKey.bracketLeft, control: true): () =>
              _navigateBack(context),
          const SingleActivator(LogicalKeyboardKey.comma, meta: true): () =>
              context.go('/settings'),
          const SingleActivator(LogicalKeyboardKey.comma, control: true): () =>
              context.go('/settings'),
          const SingleActivator(LogicalKeyboardKey.keyH, meta: true): () =>
              context.go('/home'),
          const SingleActivator(LogicalKeyboardKey.keyH, control: true): () =>
              context.go('/home'),
          const SingleActivator(LogicalKeyboardKey.period, meta: true): () =>
              _openQuickCapture(context),
          // ⌘1..⌘9 — jump to the Nth pinned page (1-based). Power-user
          // shortcut common in browsers / Notion. No-op when the
          // workspace has fewer than N favorites.
          const SingleActivator(LogicalKeyboardKey.digit1, meta: true): () =>
              _jumpToFavorite(context, 1),
          const SingleActivator(LogicalKeyboardKey.digit2, meta: true): () =>
              _jumpToFavorite(context, 2),
          const SingleActivator(LogicalKeyboardKey.digit3, meta: true): () =>
              _jumpToFavorite(context, 3),
          const SingleActivator(LogicalKeyboardKey.digit4, meta: true): () =>
              _jumpToFavorite(context, 4),
          const SingleActivator(LogicalKeyboardKey.digit5, meta: true): () =>
              _jumpToFavorite(context, 5),
          const SingleActivator(LogicalKeyboardKey.digit6, meta: true): () =>
              _jumpToFavorite(context, 6),
          const SingleActivator(LogicalKeyboardKey.digit7, meta: true): () =>
              _jumpToFavorite(context, 7),
          const SingleActivator(LogicalKeyboardKey.digit8, meta: true): () =>
              _jumpToFavorite(context, 8),
          const SingleActivator(LogicalKeyboardKey.digit9, meta: true): () =>
              _jumpToFavorite(context, 9),
          const SingleActivator(LogicalKeyboardKey.digit1, control: true): () =>
              _jumpToFavorite(context, 1),
          const SingleActivator(LogicalKeyboardKey.digit2, control: true): () =>
              _jumpToFavorite(context, 2),
          const SingleActivator(LogicalKeyboardKey.digit3, control: true): () =>
              _jumpToFavorite(context, 3),
          const SingleActivator(LogicalKeyboardKey.digit4, control: true): () =>
              _jumpToFavorite(context, 4),
          const SingleActivator(LogicalKeyboardKey.digit5, control: true): () =>
              _jumpToFavorite(context, 5),
          const SingleActivator(LogicalKeyboardKey.digit6, control: true): () =>
              _jumpToFavorite(context, 6),
          const SingleActivator(LogicalKeyboardKey.digit7, control: true): () =>
              _jumpToFavorite(context, 7),
          const SingleActivator(LogicalKeyboardKey.digit8, control: true): () =>
              _jumpToFavorite(context, 8),
          const SingleActivator(LogicalKeyboardKey.digit9, control: true): () =>
              _jumpToFavorite(context, 9),
          const SingleActivator(LogicalKeyboardKey.period, control: true): () =>
              _openQuickCapture(context),
          const SingleActivator(LogicalKeyboardKey.keyO,
              meta: true, shift: true): () => _openRandomPage(context),
          const SingleActivator(LogicalKeyboardKey.keyO,
              control: true, shift: true): () => _openRandomPage(context),
        },
        child: Focus(
          focusNode: _rootFocus,
          autofocus: true,
          child: ResponsiveLayout(
            desktop: Scaffold(
              backgroundColor: tokens.bg,
              body: Stack(
                children: [
                  Row(
                    children: [
                      if (!_sidebarCollapsed) ...[
                        SidebarWidget(
                          activeUlid: widget.activeUlid,
                          width: _sidebarWidth,
                        ),
                        _SidebarDragHandle(
                          onDrag: (dx) {
                            setState(() {
                              _sidebarWidth = (_sidebarWidth + dx)
                                  .clamp(_minSidebar, _maxSidebar);
                            });
                          },
                          onDragEnd: () => _saveSidebarWidth(_sidebarWidth),
                        ),
                      ],
                      Expanded(child: widget.child),
                    ],
                  ),
                  if (_sidebarCollapsed)
                    Positioned(
                      top: 14,
                      left: 8,
                      child: Material(
                        color: Colors.transparent,
                        child: IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(
                              minWidth: 32, minHeight: 32),
                          onPressed: () => setState(
                              () => _sidebarCollapsed = false),
                          icon: QuillIcon('sidebar',
                              size: 16,
                              strokeWidth: 1.7,
                              color: tokens.text3),
                          tooltip: 'Show sidebar (⌘\\)',
                        ),
                      ),
                    ),
                  _paletteOverlay(context),
                ],
              ),
            ),
            mobile: Scaffold(
              backgroundColor: tokens.bg,
              drawer: Drawer(
                width: 300,
                backgroundColor: tokens.sidebar,
                child: SidebarWidget(activeUlid: widget.activeUlid, width: 300),
              ),
              floatingActionButton:
                  context.watch<VaultBloc>().state is VaultLoaded
                      ? FloatingActionButton(
                          backgroundColor: tokens.accent,
                          foregroundColor:
                              Theme.of(context).colorScheme.onPrimary,
                          tooltip: 'New page',
                          onPressed: () => _newPage(context),
                          child: const Icon(Icons.add, size: 22),
                        )
                      : null,
              body: Stack(
                children: [
                  Column(
                    children: [
                      Expanded(child: widget.child),
                      const MobileTabBar(),
                    ],
                  ),
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 4,
                    left: 4,
                    child: Builder(
                      builder: (innerContext) => IconButton(
                        icon: Icon(Icons.menu, color: tokens.text2, size: 18),
                        onPressed: () => Scaffold.of(innerContext).openDrawer(),
                        tooltip: 'Open navigation drawer',
                      ),
                    ),
                  ),
                  _paletteOverlay(context),
                ],
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }

  void _navigateBack(BuildContext context) {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
    }
  }

  /// Jump to the Nth pinned page (1-based) from `.quill.yaml` favorites.
  /// Out-of-range no-ops silently so the user isn't surprised when they
  /// hold ⌘1 with no favorites yet.
  void _jumpToFavorite(BuildContext context, int oneBasedIndex) {
    final state = context.read<VaultBloc>().state;
    if (state is! VaultLoaded) return;
    final favorites = state.workspace.favorites;
    final i = oneBasedIndex - 1;
    if (i < 0 || i >= favorites.length) return;
    context.go('/editor/${favorites[i]}');
  }

  Future<void> _showShortcuts(BuildContext context) async {
    if (!context.mounted) return;
    final maxH = MediaQuery.of(context).size.height * 0.85;
    await showQuillModal<void>(
      context,
      builder: (ctx) {
        final tokens = QuillTokens.of(ctx);
        return QuillModal(
          width: 460,
          header: QuillModalHeader(
            title: 'Keyboard shortcuts',
            sub: 'Workspace and editor bindings.',
            icon: 'edit',
            onClose: () => Navigator.of(ctx).pop(),
          ),
          footer: Row(
            children: [
              const Spacer(),
              QuillSecondaryButton(
                label: 'Close',
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                _kbSection(tokens, 'Workspace'),
                _kbRow(tokens, '⌘K', 'Open command palette'),
                _kbRow(tokens, '⌘N', 'New page'),
                _kbRow(tokens, '⌘⇧N', "Open today's daily note"),
                _kbRow(tokens, '⌘R', 'Reindex vault'),
                _kbRow(tokens, '⌘⇧R', 'Reveal vault in Finder'),
                _kbRow(tokens, '⌘\\', 'Toggle sidebar'),
                _kbRow(tokens, '⌘[', 'Back'),
                _kbRow(tokens, '⌘,', 'Settings'),
                _kbRow(tokens, '⌘.', 'Quick capture → Inbox/Quick capture.md'),
                _kbRow(tokens, '⌘⇧O', 'Open a random page'),
                _kbRow(tokens, '⌘H', 'Home'),
                _kbRow(tokens, '? / ⌘?', 'This shortcut list (⌘? works in source mode too)'),
                const SizedBox(height: 10),
                _kbSection(tokens, 'Editor'),
                _kbRow(tokens, '⌘F', 'Find in page'),
                _kbRow(tokens, '⌘S', 'Force-save current page (debounced auto-save already runs)'),
                _kbRow(tokens, '⌘G', 'Find next match'),
                _kbRow(tokens, '⌘⇧G', 'Find previous match'),
                _kbRow(tokens, '⌘⇧L', 'Toggle page lock'),
                _kbRow(tokens, '⌘E', 'Toggle rendered / source'),
                _kbRow(tokens, '⌘⇧P', 'Toggle properties panel'),
                _kbRow(tokens, '⌘⌥R', 'Reveal current page in Finder'),
                _kbRow(tokens, '⌘⇧W', 'Toggle full-width page'),
                _kbRow(tokens, '⌘⇧D', 'Pin / unpin current page'),
                _kbRow(tokens, '⌘Z', 'Undo last edit'),
                _kbRow(tokens, '⌘⇧Z', 'Redo'),
                _kbRow(tokens, '⌘A', 'Select all blocks (rendered mode)'),
                _kbRow(tokens, '⌘⌫', 'Delete selected blocks'),
                _kbRow(tokens, 'Esc', 'Clear block selection'),
                _kbRow(tokens, '⌘⇧\\', 'Toggle outline rail'),
                _kbRow(tokens, 'Esc', 'Close find / dialogs'),
                _kbRow(tokens, '/', 'Open slash menu (source mode)'),
                _kbRow(tokens, '⌘B', 'Wrap selection in **bold** (source)'),
                _kbRow(tokens, '⌘I', 'Wrap selection in *italic* (source)'),
                _kbRow(tokens, '⌘⇧X', 'Wrap selection in ~~strikethrough~~ (source)'),
                _kbRow(tokens, '⌘⇧C', 'Wrap selection in `inline code` (source)'),
                _kbRow(tokens, 'F2', 'Rename current page file'),
                _kbRow(tokens, '⇥ Tab', 'Pick the highlighted entry in slash menu / relation picker'),
                _kbRow(tokens, '⌘P', 'Print current page'),
                _kbRow(tokens, '⌘V', 'Smart paste — wraps selection as [sel](url) if clipboard is a URL (source)'),
                _kbRow(tokens, '⌘⇧S', 'Sort selected lines ascending (source)'),
                _kbRow(tokens, '⌘⌥D', 'Dedupe selected lines — keeps first occurrence (source)'),
                _kbRow(tokens, '⌘1..9', 'Jump to the Nth pinned page (favorites)'),
                _kbRow(tokens, '⌘⇧H', 'Wrap selection in ==highlight== (source)'),
                _kbRow(tokens, '⌘K', 'Insert link — URL pre-fills from clipboard (source)'),
                _kbRow(tokens, '⌘D', 'Duplicate current line (source)'),
                _kbRow(tokens, '⌥↑', 'Move current line up (source)'),
                _kbRow(tokens, '⌥↓', 'Move current line down (source)'),
                _kbRow(tokens, '⌘/', 'Toggle HTML comment on current line (source)'),
                _kbRow(tokens, '⌘⇧K', 'Delete current line (source)'),
                _kbRow(tokens, '⌘L', 'Select current line (source)'),
                _kbRow(tokens, '⌘J', 'Join current line with the next (source)'),
                _kbRow(tokens, '⌘⇧1', 'Convert current line to # heading (source)'),
                _kbRow(tokens, '⌘⇧2', 'Convert current line to ## heading (source)'),
                _kbRow(tokens, '⌘⇧3', 'Convert current line to ### heading (source)'),
                _kbRow(tokens, '⌘⇧0', 'Strip block marker — back to plain paragraph (source)'),
                _kbRow(tokens, '⌘⇧.', 'Convert current line to > blockquote (source)'),
                _kbRow(tokens, '⌘⇧8', 'Convert current line to - bullet (source)'),
                _kbRow(tokens, '⌘⇧7', 'Convert current line to 1. numbered (source)'),
                _kbRow(tokens, '⌘⇧T', 'Convert current line to - [ ] todo (source)'),
                _kbRow(tokens, '⌘⇧M', 'Convert current line to > [!NOTE] callout (source)'),
                _kbRow(tokens, '⌘↵', 'Toggle - [ ] ↔ - [x] on current todo line (source)'),
                _kbRow(tokens, '⌘⇧-', 'Insert --- horizontal rule on its own line (source)'),
                _kbRow(tokens, '↵', 'Continue list / increment number (source). ⇧↵ to break out.'),
                _kbRow(tokens, '⌫', 'Strip marker on an empty list item (source).'),
                _kbRow(tokens, '[[ULID]]', 'Wikilink chip'),
                _kbRow(tokens, '[[ULID#anchor]]', 'Link to heading'),
                _kbRow(tokens, '![[ULID]]', 'Transclude page body'),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      );
      },
    );
  }

  Widget _kbSection(QuillTokens tokens, String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 4),
      child: Text(label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
            color: tokens.text3,
          )),
    );
  }

  Widget _kbRow(QuillTokens tokens, String keys, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(keys, style: mono(fontSize: 12, color: tokens.text2)),
          ),
          Expanded(
            child: Text(label,
                style: TextStyle(fontSize: 12.5, color: tokens.text2)),
          ),
        ],
      ),
    );
  }

  /// Map the Drift `Page` row set to the [PageRef] subset the
  /// domain-layer pickers operate on. One conversion site keeps the
  /// presentation handlers tiny and the pure pickers Drift-free.
  List<PageRef> _toPageRefs(List<db_models.Page> rows) => [
        for (final p in rows)
          (
            ulid: p.ulid,
            title: p.title,
            bodyLen: p.bodyText.length,
            mtimeMs: p.mtimeMs,
            tags: listValueFromFrontmatterJson(p.frontmatterJson, 'tags'),
            bodyText: p.bodyText,
            relativePath: p.relativePath,
          ),
      ];

  Future<void> _openRandomUntaggedPage(BuildContext context) async {
    final db = context.read<QuillDatabase>();
    final router = GoRouter.of(context);
    final untagged =
        filterUntagged(_toPageRefs(await db.select(db.pages).get()));
    final pick = pickRandom(
      untagged,
      math.Random(DateTime.now().microsecondsSinceEpoch.abs()),
    );
    if (pick == null) {
      if (context.mounted) {
        context.toastInfo('Every page is tagged. Nothing to triage.');
      }
      return;
    }
    if (context.mounted) {
      context.toastInfo(
        'Untagged · ${untagged.length} candidate${untagged.length == 1 ? "" : "s"}',
        sub: pick.title.isEmpty ? '(Untitled)' : pick.title,
      );
    }
    router.go('/editor/${pick.ulid}');
  }

  Future<void> _openSmallestPage(BuildContext context) async {
    final db = context.read<QuillDatabase>();
    final router = GoRouter.of(context);
    final pick = pickSmallest(_toPageRefs(await db.select(db.pages).get()));
    if (pick == null) {
      if (context.mounted) context.toastInfo('No pages to pick from yet.');
      return;
    }
    if (context.mounted) {
      context.toastInfo(
        'Smallest page · ${pick.bodyLen} chars',
        sub: pick.title.isEmpty ? '(Untitled)' : pick.title,
      );
    }
    router.go('/editor/${pick.ulid}');
  }

  Future<void> _openMostLinkedPage(BuildContext context) async {
    final db = context.read<QuillDatabase>();
    final router = GoRouter.of(context);
    final pages = await db.select(db.pages).get();
    final relations = await db.select(db.relations).get();
    if (pages.isEmpty) {
      if (context.mounted) context.toastInfo('No pages to pick from yet.');
      return;
    }
    final result = pickMostLinked(
      _toPageRefs(pages),
      [for (final r in relations) (fromUlid: r.fromUlid, toUlid: r.toUlid)],
    );
    if (result == null) {
      if (context.mounted) {
        context.toastInfo('No wikilinks yet — every page has zero backlinks.');
      }
      return;
    }
    if (context.mounted) {
      context.toastInfo(
        'Most linked · ${result.inboundCount} inbound '
        '${result.inboundCount == 1 ? "link" : "links"}',
        sub: result.ref.title.isEmpty ? '(Untitled)' : result.ref.title,
      );
    }
    router.go('/editor/${result.ref.ulid}');
  }

  Future<void> _openLargestPage(BuildContext context) async {
    final db = context.read<QuillDatabase>();
    final router = GoRouter.of(context);
    final pick = pickLargest(_toPageRefs(await db.select(db.pages).get()));
    if (pick == null) {
      if (context.mounted) context.toastInfo('No pages to pick from yet.');
      return;
    }
    if (context.mounted) {
      context.toastInfo(
        'Largest page · ${pick.bodyLen} chars',
        sub: pick.title.isEmpty ? '(Untitled)' : pick.title,
      );
    }
    router.go('/editor/${pick.ulid}');
  }

  Future<void> _openOldestInFolderPrompt(BuildContext context) async {
    final db = context.read<QuillDatabase>();
    final router = GoRouter.of(context);
    final scope = context;
    final folder = await showQuillPrompt(
      context,
      title: 'Open oldest page in folder',
      icon: 'clock',
      label: 'Folder',
      placeholder: 'e.g. Operations',
      confirmLabel: 'Open',
    );
    if (folder == null || folder.trim().isEmpty) return;
    final refs = _toPageRefs(await db.select(db.pages).get());
    final pick = oldestInFolder(refs, folder);
    if (pick == null) {
      if (scope.mounted) {
        scope.toastError('No pages in "$folder/"');
      }
      return;
    }
    final days = DateTime.now()
            .difference(DateTime.fromMillisecondsSinceEpoch(pick.mtimeMs))
            .inDays;
    if (scope.mounted) {
      scope.toastInfo(
        '"$folder/" · oldest · $days ${days == 1 ? "day" : "days"} ago',
        sub: pick.title.isEmpty ? '(Untitled)' : pick.title,
      );
    }
    router.go('/editor/${pick.ulid}');
  }

  Future<void> _resumeLatestInFolderPrompt(BuildContext context) async {
    final db = context.read<QuillDatabase>();
    final router = GoRouter.of(context);
    final scope = context;
    final folder = await showQuillPrompt(
      context,
      title: 'Resume latest page in folder',
      icon: 'note',
      label: 'Folder',
      placeholder: 'e.g. Operations',
      confirmLabel: 'Open',
    );
    if (folder == null || folder.trim().isEmpty) return;
    final refs = _toPageRefs(await db.select(db.pages).get());
    final pick = latestInFolder(refs, folder);
    if (pick == null) {
      if (scope.mounted) {
        scope.toastError('No pages in "$folder/"');
      }
      return;
    }
    final days = DateTime.now()
            .difference(DateTime.fromMillisecondsSinceEpoch(pick.mtimeMs))
            .inDays;
    if (scope.mounted) {
      scope.toastInfo(
        '"$folder/" · last edited $days ${days == 1 ? "day" : "days"} ago',
        sub: pick.title.isEmpty ? '(Untitled)' : pick.title,
      );
    }
    router.go('/editor/${pick.ulid}');
  }

  Future<void> _resumeLatestByTagPrompt(BuildContext context) async {
    final db = context.read<QuillDatabase>();
    final router = GoRouter.of(context);
    final scope = context;
    final tag = await showQuillPrompt(
      context,
      title: 'Resume latest page by tag',
      icon: 'tag',
      label: 'Tag',
      placeholder: 'e.g. work',
      confirmLabel: 'Open',
    );
    if (tag == null || tag.trim().isEmpty) return;
    final refs = _toPageRefs(await db.select(db.pages).get());
    final pick = latestByTag(refs, tag);
    if (pick == null) {
      if (scope.mounted) {
        scope.toastError('No pages tagged "$tag"');
      }
      return;
    }
    final days = DateTime.now()
            .difference(DateTime.fromMillisecondsSinceEpoch(pick.mtimeMs))
            .inDays;
    if (scope.mounted) {
      scope.toastInfo(
        'Tagged "$tag" · last edited $days ${days == 1 ? "day" : "days"} ago',
        sub: pick.title.isEmpty ? '(Untitled)' : pick.title,
      );
    }
    router.go('/editor/${pick.ulid}');
  }

  Future<void> _openRandomPageInFolderPrompt(BuildContext context) async {
    final db = context.read<QuillDatabase>();
    final router = GoRouter.of(context);
    final scope = context;
    final folder = await showQuillPrompt(
      context,
      title: 'Open random page in folder',
      icon: 'note',
      label: 'Folder',
      placeholder: 'e.g. Operations',
      confirmLabel: 'Open',
    );
    if (folder == null || folder.trim().isEmpty) return;
    final refs = _toPageRefs(await db.select(db.pages).get());
    final matches = filterByFolder(refs, folder);
    final pick = pickRandom(
      matches,
      math.Random(DateTime.now().microsecondsSinceEpoch.abs()),
    );
    if (pick == null) {
      if (scope.mounted) {
        scope.toastError('No pages in "$folder/"');
      }
      return;
    }
    if (scope.mounted) {
      scope.toastInfo(
        '"$folder/" · ${matches.length} ${matches.length == 1 ? "page" : "pages"}',
        sub: pick.title.isEmpty ? '(Untitled)' : pick.title,
      );
    }
    router.go('/editor/${pick.ulid}');
  }

  Future<void> _openRandomPageByTitlePrefixPrompt(BuildContext context) async {
    final db = context.read<QuillDatabase>();
    final router = GoRouter.of(context);
    final scope = context;
    final prefix = await showQuillPrompt(
      context,
      title: 'Open random page by title prefix',
      icon: 'note',
      label: 'Prefix',
      placeholder: 'e.g. Project:',
      confirmLabel: 'Open',
    );
    if (prefix == null || prefix.trim().isEmpty) return;
    final refs = _toPageRefs(await db.select(db.pages).get());
    final matches = filterTitleStartsWith(refs, prefix);
    final pick = pickRandom(
      matches,
      math.Random(DateTime.now().microsecondsSinceEpoch.abs()),
    );
    if (pick == null) {
      if (scope.mounted) {
        scope.toastError('No page title starts with "$prefix"');
      }
      return;
    }
    if (scope.mounted) {
      scope.toastInfo(
        '"$prefix…" · ${matches.length} ${matches.length == 1 ? "page" : "pages"}',
        sub: pick.title.isEmpty ? '(Untitled)' : pick.title,
      );
    }
    router.go('/editor/${pick.ulid}');
  }

  Future<void> _openRandomPageByTagPrompt(BuildContext context) async {
    final db = context.read<QuillDatabase>();
    final router = GoRouter.of(context);
    final scope = context;
    final tag = await showQuillPrompt(
      context,
      title: 'Open random page by tag',
      icon: 'tag',
      label: 'Tag',
      placeholder: 'e.g. reading-list',
      confirmLabel: 'Open',
    );
    if (tag == null || tag.trim().isEmpty) return;
    final refs = _toPageRefs(await db.select(db.pages).get());
    final tagged = filterByTag(refs, tag);
    final pick = pickRandom(
      tagged,
      math.Random(DateTime.now().microsecondsSinceEpoch.abs()),
    );
    if (pick == null) {
      if (scope.mounted) {
        scope.toastError('No pages tagged "$tag"');
      }
      return;
    }
    if (scope.mounted) {
      scope.toastInfo(
        'Tagged "$tag" · ${tagged.length} ${tagged.length == 1 ? "page" : "pages"}',
        sub: pick.title.isEmpty ? '(Untitled)' : pick.title,
      );
    }
    router.go('/editor/${pick.ulid}');
  }

  Future<void> _openPageByTitlePrompt(BuildContext context) async {
    final db = context.read<QuillDatabase>();
    final router = GoRouter.of(context);
    final scope = context;
    final title = await showQuillPrompt(
      context,
      title: 'Open page by title',
      icon: 'note',
      label: 'Title',
      placeholder: 'Exact title (case-insensitive)',
      confirmLabel: 'Open',
    );
    if (title == null || title.trim().isEmpty) return;
    final refs = _toPageRefs(await db.select(db.pages).get());
    final pick = pickByTitle(refs, title);
    if (pick == null) {
      if (scope.mounted) {
        scope.toastError('No page named "$title"');
      }
      return;
    }
    if (scope.mounted) {
      scope.toastInfo(
        'Opened',
        sub: pick.title.isEmpty ? '(Untitled)' : pick.title,
      );
    }
    router.go('/editor/${pick.ulid}');
  }

  Future<void> _openOldestPage(BuildContext context) async {
    final db = context.read<QuillDatabase>();
    final router = GoRouter.of(context);
    final pick = pickOldest(_toPageRefs(await db.select(db.pages).get()));
    if (pick == null) {
      if (context.mounted) context.toastInfo('No pages to pick from yet.');
      return;
    }
    final days = DateTime.now()
            .difference(DateTime.fromMillisecondsSinceEpoch(pick.mtimeMs))
            .inDays;
    if (context.mounted) {
      context.toastInfo(
        'Oldest page · last touched $days ${days == 1 ? "day" : "days"} ago',
        sub: pick.title.isEmpty ? '(Untitled)' : pick.title,
      );
    }
    router.go('/editor/${pick.ulid}');
  }

  Future<void> _openLastEditedPage(BuildContext context) async {
    final db = context.read<QuillDatabase>();
    final router = GoRouter.of(context);
    final pick = pickLastEdited(_toPageRefs(await db.select(db.pages).get()));
    if (pick == null) {
      if (context.mounted) context.toastInfo('No pages to pick from yet.');
      return;
    }
    if (context.mounted) {
      context.toastInfo(
        'Last edited',
        sub: pick.title.isEmpty ? '(Untitled)' : pick.title,
      );
    }
    router.go('/editor/${pick.ulid}');
  }

  Future<void> _openRandomPage(BuildContext context) async {
    final db = context.read<QuillDatabase>();
    final router = GoRouter.of(context);
    final refs = _toPageRefs(await db.select(db.pages).get());
    final pick = pickRandom(
      refs,
      math.Random(DateTime.now().microsecondsSinceEpoch.abs()),
    );
    if (pick == null) {
      if (context.mounted) context.toastInfo('No pages to pick from yet.');
      return;
    }
    if (context.mounted) {
      context.toastInfo(
        'Random pick from ${refs.length} ${refs.length == 1 ? "page" : "pages"}',
        sub: pick.title.isEmpty ? '(Untitled)' : pick.title,
      );
    }
    router.go('/editor/${pick.ulid}');
  }

  Future<void> _promptAndBookmarkUrl(
      BuildContext context, String vaultPath) async {
    final vaultBloc = context.read<VaultBloc>();
    final router = GoRouter.of(context);
    final url = await showQuillPrompt(
      context,
      title: 'Bookmark a URL',
      icon: 'link',
      label: 'URL',
      placeholder: 'https://...',
      mono: true,
      confirmLabel: 'Bookmark',
    );
    if (url == null) return;
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;
    try {
      final result =
          await UrlBookmark.capture(trimmed, Directory(vaultPath));
      vaultBloc.add(const ReindexVault());
      if (context.mounted) {
        context.toastSuccess('Bookmarked "${result.title}"',
            sub: 'ULID: ${result.ulid}', subMono: true);
      }
      router.go('/editor/${result.ulid}');
    } catch (e) {
      if (context.mounted) context.toastError('Bookmark failed', sub: '$e');
    }
  }

  Future<void> _openQuickCapture(BuildContext context) async {
    final vaultBloc = context.read<VaultBloc>();
    final state = vaultBloc.state;
    if (state is! VaultLoaded) return;
    final text = await showQuillPrompt(
      context,
      title: 'Quick capture',
      icon: 'inbox',
      label: 'Note',
      hint: 'Lands at the top of Inbox/Quick capture.md with a timestamp.',
      placeholder: 'Capture a thought…',
      confirmLabel: 'Capture',
    );
    if (text == null) return;
    // Whitespace-only used to slip past the isEmpty check and hit
    // QuickCapture.append, which throws FormatException('empty
    // capture') — the user saw 'Capture failed: ...' rather than
    // 'nothing to capture'. Trim once, bail silently if empty.
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    try {
      await QuickCapture.append(trimmed, Directory(state.rootPath));
      vaultBloc.add(const RefreshFromDisk());
      if (context.mounted) {
        final preview = trimmed.replaceAll(RegExp(r'\s+'), ' ');
        final excerpt = preview.length > 60
            ? '${preview.substring(0, 60)}…'
            : preview;
        context.toastSuccess('Captured → Inbox/Quick capture.md',
            sub: excerpt);
      }
    } catch (e) {
      if (context.mounted) context.toastError('Capture failed', sub: '$e');
    }
  }

  Future<void> _newPage(BuildContext context) async {
    final vaultBloc = context.read<VaultBloc>();
    if (vaultBloc.state is! VaultLoaded) return;
    final router = GoRouter.of(context);
    final scope = context;
    final title = await showQuillPrompt(
      context,
      title: 'New page',
      icon: 'file-md',
      label: 'Title',
      placeholder: 'Untitled',
      confirmLabel: 'Create',
    );
    if (title == null) return;
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    vaultBloc.add(CreatePage(
      title: trimmed,
      onCreated: (ulid) {
        if (scope.mounted) {
          scope.toastSuccess('Created "$trimmed"',
              sub: 'ULID: $ulid', subMono: true);
        }
        router.go('/editor/$ulid');
      },
    ));
  }

  Future<void> _invokeAction(BuildContext context, String label) async {
    final vaultBloc = context.read<VaultBloc>();
    final themeCubit = context.read<ThemeCubit>();
    final vaultState = vaultBloc.state;
    final vaultPath = vaultState is VaultLoaded ? vaultState.rootPath : null;

    switch (label) {
      case 'Reveal vault in Finder':
        if (vaultPath == null) {
          context.toastError('No vault open');
          return;
        }
        final ok = await Reveal.show(vaultPath);
        if (!ok && context.mounted) {
          context.toastError('Could not open', sub: vaultPath, subMono: true);
        }
      case 'Copy vault path':
        if (vaultPath == null) {
          context.toastError('No vault open');
          return;
        }
        await Clipboard.setData(ClipboardData(text: vaultPath));
        if (context.mounted) {
          context.toastSuccess('Copied vault path', sub: vaultPath, subMono: true);
        }
      case 'Export vault to folder':
        if (vaultPath == null) {
          context.toastError('No vault open');
          return;
        }
        final dest = await FilePicker.platform.getDirectoryPath(
          dialogTitle: 'Export vault to…',
        );
        if (dest == null) return;
        try {
          final n = await const VaultExporter().export(
            src: Directory(vaultPath),
            dest: Directory(dest),
          );
          if (context.mounted) {
            context.toastSuccess(
              'Exported $n ${n == 1 ? 'file' : 'files'}',
              sub: dest,
              subMono: true,
            );
          }
        } catch (e) {
          if (context.mounted) context.toastError('Export failed', sub: '$e');
        }
      case 'Reindex vault':
        vaultBloc.add(const ReindexVault());
        context.toastInfo('Reindexing vault…');
      case 'Quick capture':
        await _openQuickCapture(context);
      case 'Bookmark a URL':
        if (vaultPath == null) {
          context.toastError('No vault open');
          return;
        }
        await _promptAndBookmarkUrl(context, vaultPath);
      case 'Open random page':
        await _openRandomPage(context);
      case 'Open last edited page':
        await _openLastEditedPage(context);
      case 'Open oldest page':
        await _openOldestPage(context);
      case 'Open page by title…':
        await _openPageByTitlePrompt(context);
      case 'Open random page by tag…':
        await _openRandomPageByTagPrompt(context);
      case 'Open random page by title prefix…':
        await _openRandomPageByTitlePrefixPrompt(context);
      case 'Open random page in folder…':
        await _openRandomPageInFolderPrompt(context);
      case 'Resume latest page by tag…':
        await _resumeLatestByTagPrompt(context);
      case 'Resume latest page in folder…':
        await _resumeLatestInFolderPrompt(context);
      case 'Open oldest page in folder…':
        await _openOldestInFolderPrompt(context);
      case 'Open largest page':
        await _openLargestPage(context);
      case 'Open most-linked page':
        await _openMostLinkedPage(context);
      case 'Open smallest page':
        await _openSmallestPage(context);
      case 'Open random untagged page':
        await _openRandomUntaggedPage(context);
      case "Open today's daily note":
        if (vaultPath == null) {
          context.toastError('No vault open');
          return;
        }
        try {
          final result =
              await DailyNote.openTodaysNote(Directory(vaultPath));
          if (!result.alreadyExisted) {
            vaultBloc.add(const ReindexVault());
          }
          if (!context.mounted) return;
          GoRouter.of(context).go('/editor/${result.ulid}');
        } catch (e) {
          if (context.mounted) context.toastError('Daily note failed', sub: '$e');
        }
      case 'Toggle theme':
        await themeCubit.cycleMode();
        if (!context.mounted) return;
        final modeLabel = switch (themeCubit.state.mode) {
          AppThemeMode.light => 'Light',
          AppThemeMode.dark => 'Dark',
          AppThemeMode.system => 'System',
        };
        context.toastSuccess('Theme: $modeLabel');
      case 'Toggle compact mode':
        await themeCubit.toggleCompact();
        if (!context.mounted) return;
        context.toastSuccess(themeCubit.state.compact
            ? 'Compact mode on'
            : 'Compact mode off');
      case 'Show orphan pages':
        if (!context.mounted) return;
        await _showOrphansDialog(context);
      case 'Show untagged pages':
        if (!context.mounted) return;
        await _showUntaggedDialog(context);
      case 'Show pages without a title':
        if (!context.mounted) return;
        await _showUntitledDialog(context);
      case 'Show broken wikilinks':
        if (!context.mounted) return;
        await _showBrokenLinksDialog(context);
      case 'Show stale pages (90+ days)':
        if (!context.mounted) return;
        await _showStaleDialog(context);
      case 'Show pages with open todos':
        if (!context.mounted) return;
        await _showOpenTodosDialog(context);
      case 'Show duplicate page titles':
        if (!context.mounted) return;
        await _showDuplicateTitlesDialog(context);
      case 'Show heaviest pages':
        if (!context.mounted) return;
        await _showHeaviestPagesDialog(context);
      case 'Show hub pages (most backlinks)':
        if (!context.mounted) return;
        await _showHubPagesDialog(context);
      case 'Show empty pages':
        if (!context.mounted) return;
        await _showEmptyPagesDialog(context);
      case 'Show trash':
        if (vaultPath == null) {
          context.toastError('No vault open');
          return;
        }
        if (!context.mounted) return;
        await showQuillModal<void>(
          context,
          builder: (_) => BlocProvider.value(
            value: vaultBloc,
            child: TrashDialog(vaultRoot: vaultPath),
          ),
        );
      case 'Export vault as PDF':
        if (vaultPath == null) {
          context.toastError('No vault open');
          return;
        }
        final pickedPath = await FilePicker.platform.saveFile(
          dialogTitle: 'Save PDF…',
          fileName: 'vault.pdf',
          type: FileType.custom,
          allowedExtensions: const ['pdf'],
        );
        if (pickedPath == null) return;
        try {
          final n = await const PdfExporter().export(
            src: Directory(vaultPath),
            dest: File(pickedPath),
          );
          if (context.mounted) {
            context.toastSuccess(
              'Exported $n ${n == 1 ? 'page' : 'pages'}',
              sub: pickedPath,
              subMono: true,
            );
          }
        } catch (e) {
          if (context.mounted) context.toastError('PDF export failed', sub: '$e');
        }
      case 'Export vault as HTML':
        if (vaultPath == null) {
          context.toastError('No vault open');
          return;
        }
        final dest = await FilePicker.platform.getDirectoryPath(
          dialogTitle: 'Export HTML site to…',
        );
        if (dest == null) return;
        try {
          final n = await const HtmlExporter().export(
            src: Directory(vaultPath),
            dest: Directory(dest),
          );
          if (context.mounted) {
            context.toastSuccess(
              'Exported $n ${n == 1 ? 'page' : 'pages'}',
              sub: dest,
              subMono: true,
            );
          }
        } catch (e) {
          if (context.mounted) context.toastError('HTML export failed', sub: '$e');
        }
      case 'Import CSV as database':
        if (vaultPath == null) {
          context.toastError('No vault open');
          return;
        }
        final dbRepo = context.read<DatabaseRepository>();
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: const ['csv'],
        );
        if (result == null || result.files.isEmpty) return;
        final picked = result.files.first.path;
        if (picked == null) return;
        try {
          final summary = await dbRepo.importCsv(
            source: File(picked),
            vaultRoot: Directory(vaultPath),
          );
          vaultBloc.add(const ReindexVault());
          if (context.mounted) {
            context.toastSuccess(
              'Imported ${summary.rowsWritten} ${summary.rowsWritten == 1 ? 'row' : 'rows'} · ${summary.columns} ${summary.columns == 1 ? 'col' : 'cols'}',
              sub: '→ ${summary.folderPath.split('/').last}',
              subMono: true,
            );
          }
        } catch (e) {
          if (context.mounted) context.toastError('CSV import failed', sub: '$e');
        }
      case 'Import HTML file as page':
        if (vaultPath == null) {
          context.toastError('No vault open');
          return;
        }
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: const ['html', 'htm'],
        );
        if (result == null || result.files.isEmpty) return;
        final picked = result.files.first.path;
        if (picked == null) return;
        try {
          final summary = await HtmlPageImporter.importTo(
            File(picked),
            Directory(vaultPath),
          );
          vaultBloc.add(const ReindexVault());
          if (context.mounted) {
            context.toastSuccess('Imported HTML',
                sub: summary.relativePath, subMono: true);
          }
        } catch (e) {
          if (context.mounted) context.toastError('HTML import failed', sub: '$e');
        }
      case 'Import Word .docx as page':
        if (vaultPath == null) {
          context.toastError('No vault open');
          return;
        }
        final docxPick = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: const ['docx'],
        );
        if (docxPick == null || docxPick.files.isEmpty) return;
        final docxPath = docxPick.files.first.path;
        if (docxPath == null) return;
        try {
          final summary = await DocxPageImporter.importTo(
            File(docxPath),
            Directory(vaultPath),
          );
          vaultBloc.add(const ReindexVault());
          if (context.mounted) {
            context.toastSuccess('Imported',
                sub: summary.relativePath, subMono: true);
          }
        } catch (e) {
          if (context.mounted) context.toastError('Word import failed', sub: '$e');
        }
      case 'Import Evernote .enex notebook':
        if (vaultPath == null) {
          context.toastError('No vault open');
          return;
        }
        final enexPick = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: const ['enex', 'xml'],
        );
        if (enexPick == null || enexPick.files.isEmpty) return;
        final enexPath = enexPick.files.first.path;
        if (enexPath == null) return;
        try {
          final summary = await EnexPageImporter.importTo(
            File(enexPath),
            Directory(vaultPath),
          );
          vaultBloc.add(const ReindexVault());
          if (context.mounted) {
            context.toastSuccess(
              'Imported ${summary.notes.length} ${summary.notes.length == 1 ? 'note' : 'notes'}',
              sub: '${summary.folder}/',
              subMono: true,
            );
          }
        } catch (e) {
          if (context.mounted) context.toastError('Evernote import failed', sub: '$e');
        }
      case 'Import Asana CSV as database':
        if (vaultPath == null) {
          context.toastError('No vault open');
          return;
        }
        final asanaPick = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: const ['csv'],
        );
        if (asanaPick == null || asanaPick.files.isEmpty) return;
        final asanaPath = asanaPick.files.first.path;
        if (asanaPath == null) return;
        try {
          final summary = await AsanaCsvImporter.importTo(
            File(asanaPath),
            Directory(vaultPath),
          );
          vaultBloc.add(const ReindexVault());
          if (context.mounted) {
            context.toastSuccess(
              'Imported ${summary.tasks.length} ${summary.tasks.length == 1 ? 'task' : 'tasks'}',
              sub: '${summary.folder}/',
              subMono: true,
            );
          }
        } catch (e) {
          if (context.mounted) context.toastError('Asana import failed', sub: '$e');
        }
      case 'Import Trello board as database':
        if (vaultPath == null) {
          context.toastError('No vault open');
          return;
        }
        final trPick = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: const ['json'],
        );
        if (trPick == null || trPick.files.isEmpty) return;
        final trPath = trPick.files.first.path;
        if (trPath == null) return;
        try {
          final summary = await TrelloDatabaseImporter.importTo(
            File(trPath),
            Directory(vaultPath),
          );
          vaultBloc.add(const ReindexVault());
          if (context.mounted) {
            context.toastSuccess(
              'Imported ${summary.cards.length} ${summary.cards.length == 1 ? 'card' : 'cards'}',
              sub: '${summary.folder}/',
              subMono: true,
            );
          }
        } catch (e) {
          if (context.mounted) context.toastError('Trello import failed', sub: '$e');
        }
      case 'Import Roam JSON export':
        if (vaultPath == null) {
          context.toastError('No vault open');
          return;
        }
        final roamPick = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: const ['json'],
        );
        if (roamPick == null || roamPick.files.isEmpty) return;
        final roamPath = roamPick.files.first.path;
        if (roamPath == null) return;
        try {
          final summary = await RoamPageImporter.importTo(
            File(roamPath),
            Directory(vaultPath),
          );
          vaultBloc.add(const ReindexVault());
          if (context.mounted) {
            context.toastSuccess(
              'Imported ${summary.pages.length} ${summary.pages.length == 1 ? 'page' : 'pages'}',
              sub: '${summary.folder}/',
              subMono: true,
            );
          }
        } catch (e) {
          if (context.mounted) context.toastError('Roam import failed', sub: '$e');
        }
      case 'Import OPML outline as page':
        if (vaultPath == null) {
          context.toastError('No vault open');
          return;
        }
        final opmlPick = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: const ['opml', 'xml'],
        );
        if (opmlPick == null || opmlPick.files.isEmpty) return;
        final opmlPath = opmlPick.files.first.path;
        if (opmlPath == null) return;
        try {
          final summary = await OpmlPageImporter.importTo(
            File(opmlPath),
            Directory(vaultPath),
          );
          vaultBloc.add(const ReindexVault());
          if (context.mounted) {
            context.toastSuccess('Imported OPML',
                sub: summary.relativePath, subMono: true);
          }
        } catch (e) {
          if (context.mounted) context.toastError('OPML import failed', sub: '$e');
        }
      case 'Import text file as page':
      case 'Import Markdown file as page':
        if (vaultPath == null) {
          context.toastError('No vault open');
          return;
        }
        final exts = label == 'Import Markdown file as page'
            ? const ['md', 'markdown']
            : const ['txt', 'text'];
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: exts,
        );
        if (result == null || result.files.isEmpty) return;
        final picked = result.files.first.path;
        if (picked == null) return;
        try {
          final summary = await TextPageImporter.importTo(
            File(picked),
            Directory(vaultPath),
          );
          vaultBloc.add(const ReindexVault());
          if (context.mounted) {
            context.toastSuccess('Imported',
                sub: summary.relativePath, subMono: true);
          }
        } catch (e) {
          if (context.mounted) context.toastError('Import failed', sub: '$e');
        }
      case 'New page from template…':
        if (vaultPath == null) {
          context.toastError('No vault open');
          return;
        }
        final db = context.read<QuillDatabase>();
        final templates = await (db.select(db.pages)
              ..where((p) => p.relativePath.like('Templates/%') |
                  p.relativePath.like('Templates\\%')))
            .get();
        if (templates.isEmpty) {
          if (context.mounted) {
            context.toastInfo(
              'No templates yet',
              sub:
                  'Create a Templates/ folder at the vault root and add .md files.',
            );
          }
          return;
        }
        if (!context.mounted) return;
        final picked = await showQuillChoice<String>(
          context,
          title: 'New page from template',
          icon: 'note',
          options: [
            for (final tpl in templates)
              QuillChoiceOption<String>(
                value: tpl.ulid,
                label: tpl.title,
                hint: stripMdExtension(tpl.relativePath),
                icon: 'file-md',
              ),
          ],
        );
        if (picked == null) return;
        if (!context.mounted) return;
        final router = GoRouter.of(context);
        final scope = context;
        final tplTitle = templates
                .firstWhere((t) => t.ulid == picked,
                    orElse: () => templates.first)
                .title;
        vaultBloc.add(DuplicatePage(
          picked,
          targetFolder: '',
          onCreated: (newUlid) {
            if (scope.mounted) {
              scope.toastSuccess(
                  tplTitle.isEmpty
                      ? 'New page from template'
                      : 'New page from "$tplTitle"',
                  sub: 'New ULID: $newUlid',
                  subMono: true);
            }
            router.go('/editor/$newUlid');
          },
        ));
      case 'Vault stats':
        if (!context.mounted) return;
        await _showVaultStats(context);
      case 'Browse all databases':
        if (!context.mounted) return;
        GoRouter.of(context).go('/databases');
      case 'Browse tags':
        if (!context.mounted) return;
        GoRouter.of(context).go('/tags');
      case 'New database…':
        if (vaultPath == null) {
          context.toastError('No vault open');
          return;
        }
        if (!context.mounted) return;
        await _createDatabase(context, Directory(vaultPath));
      case 'Show keyboard shortcuts':
        if (!context.mounted) return;
        await _showShortcuts(context);
      case 'Install built-in templates':
        if (vaultPath == null) {
          context.toastError('No vault open');
          return;
        }
        try {
          final n = await const SeedTemplates().install(Directory(vaultPath));
          if (context.mounted) {
            if (n == 0) {
              context.toastInfo('Templates already installed.');
            } else {
              context.toastSuccess(
                'Installed $n ${n == 1 ? 'template' : 'templates'}',
                sub: 'Templates/',
                subMono: true,
              );
            }
          }
          vaultBloc.add(const RefreshFromDisk());
        } catch (e) {
          if (context.mounted) {
            context.toastError('Could not install templates', sub: '$e');
          }
        }
    }
  }

  Future<void> _createDatabase(
      BuildContext context, Directory vaultRoot) async {
    final name = await showQuillPrompt(
      context,
      title: 'New database',
      icon: 'database',
      label: 'Database name',
      hint:
          'Quill creates a folder under your vault and seeds it with a minimal .database.yaml. Each .md inside the folder becomes a row.',
      placeholder: 'Deals',
      confirmLabel: 'Create',
    );
    if (name == null) return;
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final safe = trimmed.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final folder = Directory('${vaultRoot.path}/$safe');
    if (await folder.exists()) {
      if (!context.mounted) return;
      context.toastError('Folder already exists', sub: safe, subMono: true);
      return;
    }
    final ulids = const UlidGenerator();
    final id = ulids.generate();
    // yamlSafeScalar wraps the name in double quotes only when needed
    // — same correctness contract as M685's inline escape, less
    // bespoke logic.
    final yaml = '''id: $id
name: ${yamlSafeScalar(trimmed)}
icon: 📊
color: "#6B8E7F"
schema:
  status:
    type: select
    options: [todo, doing, done]
  notes:
    type: text
views:
  - id: main
    name: All
    type: table
''';
    await folder.create(recursive: true);
    await File('${folder.path}/.database.yaml').writeAsString(yaml);
    if (!context.mounted) return;
    context.read<VaultBloc>().add(const ReindexVault());
    context.toastSuccess('Created database "$trimmed"',
        sub: safe == trimmed ? null : '→ $safe/',
        subMono: safe != trimmed);
  }

  Future<void> _showStaleDialog(BuildContext context) async {
    final db = context.read<QuillDatabase>();
    final pages = await db.select(db.pages).get();
    final cutoff =
        DateTime.now().subtract(const Duration(days: 90)).millisecondsSinceEpoch;
    final pickedUlids = {
      for (final ref in filterStale(_toPageRefs(pages), cutoff)) ref.ulid,
    };
    final stale = [
      for (final p in pages) if (pickedUlids.contains(p.ulid)) p,
    ]..sort((a, b) => a.mtimeMs.compareTo(b.mtimeMs));
    if (!context.mounted) return;
    await _showHygieneDialog(
      context: context,
      pages: stale,
      headingFull: 'STALE PAGES',
      headingEmpty: 'NO STALE PAGES',
      subtitleFull:
          'Pages not edited in 90+ days. Oldest first — candidates for archive or refresh.',
      subtitleEmpty:
          'Every indexed page has been edited within the last 90 days.',
    );
  }

  Future<void> _showEmptyPagesDialog(BuildContext context) async {
    final db = context.read<QuillDatabase>();
    final pages = await db.select(db.pages).get();
    // "Empty" means: no body content (whitespace-only counts as empty).
    // Title and frontmatter are preserved — these are the placeholder
    // pages that got created but never filled in. Distinct from
    // "orphan" (no links) and "without a title" (no name).
    final pickedUlids = {
      for (final ref in filterEmpty(_toPageRefs(pages))) ref.ulid,
    };
    final empties = [
      for (final p in pages) if (pickedUlids.contains(p.ulid)) p,
    ]..sort((a, b) => b.mtimeMs.compareTo(a.mtimeMs));
    if (!context.mounted) return;
    await _showHygieneDialog(
      context: context,
      pages: empties,
      headingFull: 'EMPTY PAGES',
      headingEmpty: 'NO EMPTY PAGES',
      subtitleFull:
          'Pages with a title but no body content. Drafts to flesh out — or orphans to delete.',
      subtitleEmpty:
          'Every indexed page has at least some body content.',
    );
  }

  Future<void> _showHubPagesDialog(BuildContext context) async {
    final db = context.read<QuillDatabase>();
    final pages = await db.select(db.pages).get();
    final relations = await db.select(db.relations).get();
    // Top-20 sort lives in the M1023 picker. Preserve its order
    // (inbound-count-desc with mtime tie-break) by iterating the
    // picker's ULID list and looking up the matching Drift row.
    final byUlid = {for (final p in pages) p.ulid: p};
    final topHubs = [
      for (final ref in topByBacklinkCount(
        _toPageRefs(pages),
        [for (final r in relations) (fromUlid: r.fromUlid, toUlid: r.toUlid)],
        20,
      ))
        byUlid[ref.ulid]!,
    ];
    if (!context.mounted) return;
    await _showHygieneDialog(
      context: context,
      pages: topHubs,
      headingFull: 'HUB PAGES',
      headingEmpty: 'NO HUB PAGES',
      subtitleFull:
          'Top 20 pages by inbound `[[wikilink]]` count. The structural anchors of the vault — review, refactor, or split deliberately.',
      subtitleEmpty:
          'No page has incoming wikilinks yet. Start cross-linking and they will surface here.',
    );
  }

  Future<void> _showHeaviestPagesDialog(BuildContext context) async {
    final db = context.read<QuillDatabase>();
    final pages = await db.select(db.pages).get();
    // Top-20 sort lives in the M1023 picker. Preserve its order
    // (size-desc with mtime tie-break) by iterating the picker's
    // ULID list and looking up the matching Drift row.
    final byUlid = {for (final p in pages) p.ulid: p};
    final topPages = [
      for (final ref in topByBodyLen(_toPageRefs(pages), 20))
        byUlid[ref.ulid]!,
    ];
    if (!context.mounted) return;
    await _showHygieneDialog(
      context: context,
      pages: topPages,
      headingFull: 'HEAVIEST PAGES',
      headingEmpty: 'NO PAGES',
      subtitleFull:
          'Top 20 pages by markdown body size. Candidates for splitting, archiving, or a database column.',
      subtitleEmpty:
          'The vault has no indexed pages yet.',
    );
  }

  Future<void> _showDuplicateTitlesDialog(BuildContext context) async {
    final db = context.read<QuillDatabase>();
    final pages = await db.select(db.pages).get();
    // Detection + sort lives in the M1018 picker usecase. Preserve
    // its output order (alphabetical buckets, freshest-first within
    // each bucket) by iterating the picker's ULID list and looking
    // up the matching Drift row.
    final byUlid = {for (final p in pages) p.ulid: p};
    final dups = [
      for (final ref in filterDuplicateTitles(_toPageRefs(pages)))
        byUlid[ref.ulid]!,
    ];
    if (!context.mounted) return;
    await _showHygieneDialog(
      context: context,
      pages: dups,
      headingFull: 'DUPLICATE TITLES',
      headingEmpty: 'NO DUPLICATE TITLES',
      subtitleFull:
          'Pages whose title (case-insensitive) is shared by another page. Sorted by title, then last-edited.',
      subtitleEmpty:
          'Every page title is unique across the vault (case-insensitive). Nice.',
    );
  }

  Future<void> _showOpenTodosDialog(BuildContext context) async {
    final db = context.read<QuillDatabase>();
    final pages = await db.select(db.pages).get();
    // Detection logic lives in the M1018 picker usecase
    // (`filterPagesWithOpenTodos`); map Drift → PageRef → filter →
    // ULID set → back to the Drift rows the shared dialog wants.
    final pickedUlids = {
      for (final ref in filterPagesWithOpenTodos(_toPageRefs(pages)))
        ref.ulid,
    };
    final withTodos = [
      for (final p in pages) if (pickedUlids.contains(p.ulid)) p,
    ]..sort((a, b) => b.mtimeMs.compareTo(a.mtimeMs));
    if (!context.mounted) return;
    await _showHygieneDialog(
      context: context,
      pages: withTodos,
      headingFull: 'OPEN TODOS',
      headingEmpty: 'NO OPEN TODOS',
      subtitleFull:
          'Pages containing at least one unchecked `- [ ] ` item. Sorted by last-edited.',
      subtitleEmpty:
          'No indexed page has an open `- [ ] ` todo. Inbox zero, or nothing tracked yet.',
    );
  }

  Future<void> _showBrokenLinksDialog(BuildContext context) async {
    final db = context.read<QuillDatabase>();
    final pages = await db.select(db.pages).get();
    final relations = await db.select(db.relations).get();
    final knownUlids = {for (final p in pages) p.ulid};
    // Collect unique source pages whose body links to a target ULID
    // that no longer exists in the index.
    final brokenFromUlids = <String>{};
    for (final r in relations) {
      if (!knownUlids.contains(r.toUlid)) {
        brokenFromUlids.add(r.fromUlid);
      }
    }
    final broken = [
      for (final p in pages)
        if (brokenFromUlids.contains(p.ulid)) p,
    ]..sort((a, b) => b.mtimeMs.compareTo(a.mtimeMs));
    if (!context.mounted) return;
    await _showHygieneDialog(
      context: context,
      pages: broken,
      headingFull: 'PAGES WITH BROKEN WIKILINKS',
      headingEmpty: 'NO BROKEN WIKILINKS',
      subtitleFull:
          'Pages whose body links to a `[[ULID]]` that no longer exists in the index. Sorted by last-edited.',
      subtitleEmpty:
          'Every wikilink in the vault resolves to a known page.',
    );
  }

  Future<void> _showUntitledDialog(BuildContext context) async {
    final db = context.read<QuillDatabase>();
    final pages = await db.select(db.pages).get();
    bool hasExplicitTitle(String json) =>
        hasNonEmptyFrontmatterValue(json, 'title');

    final untitled = [
      for (final p in pages)
        if (!hasExplicitTitle(p.frontmatterJson)) p,
    ]..sort((a, b) => b.mtimeMs.compareTo(a.mtimeMs));
    if (!context.mounted) return;
    await _showHygieneDialog(
      context: context,
      pages: untitled,
      headingFull: 'PAGES WITHOUT A TITLE',
      headingEmpty: 'EVERY PAGE HAS A TITLE',
      subtitleFull:
          'Pages with no `title:` frontmatter (the displayed title falls back to the filename). Sorted by last-edited.',
      subtitleEmpty:
          'Every indexed page declares a `title:` in its frontmatter.',
    );
  }

  Future<void> _showUntaggedDialog(BuildContext context) async {
    final db = context.read<QuillDatabase>();
    final pages = await db.select(db.pages).get();
    final pickedUlids = {
      for (final ref in filterUntagged(_toPageRefs(pages))) ref.ulid,
    };
    final untagged = [
      for (final p in pages) if (pickedUlids.contains(p.ulid)) p,
    ]..sort((a, b) => b.mtimeMs.compareTo(a.mtimeMs));
    if (!context.mounted) return;
    await _showHygieneDialog(
      context: context,
      pages: untagged,
      headingFull: 'UNTAGGED PAGES',
      headingEmpty: 'EVERY PAGE IS TAGGED',
      subtitleFull:
          'Pages with no `tags:` frontmatter. Sorted by last-edited (most recent first).',
      subtitleEmpty:
          'Every indexed page has at least one tag in its frontmatter.',
    );
  }

  Future<void> _showOrphansDialog(BuildContext context) async {
    final db = context.read<QuillDatabase>();
    final pages = await db.select(db.pages).get();
    final relations = await db.select(db.relations).get();
    final pickedUlids = {
      for (final ref in filterOrphan(
        _toPageRefs(pages),
        [for (final r in relations) (fromUlid: r.fromUlid, toUlid: r.toUlid)],
      ))
        ref.ulid,
    };
    final orphans = [
      for (final p in pages) if (pickedUlids.contains(p.ulid)) p,
    ]..sort((a, b) => b.mtimeMs.compareTo(a.mtimeMs));
    if (!context.mounted) return;
    await _showHygieneDialog(
      context: context,
      pages: orphans,
      headingFull: 'ORPHAN PAGES',
      headingEmpty: 'NO ORPHAN PAGES',
      subtitleFull:
          'Pages with no incoming or outgoing wikilinks. Sorted by last-edited (most recent first).',
      subtitleEmpty:
          'Every indexed page has at least one wikilink coming in or going out. Nice.',
    );
  }

  /// Shared dialog for vault-hygiene lists (orphans, untagged, …). All
  /// callers boil down to the same template: heading + subtitle, then a
  /// scrollable list of clickable `_StatsPageRow`s that navigate to the
  /// page on tap.
  Future<void> _showHygieneDialog({
    required BuildContext context,
    required List<db_models.Page> pages,
    required String headingFull,
    required String headingEmpty,
    required String subtitleFull,
    required String subtitleEmpty,
  }) async {
    final size = MediaQuery.of(context).size;
    final w = size.width < 500 ? size.width - 32 : 460.0;
    final h = size.height < 580 ? size.height - 60 : 540.0;
    await showQuillModal<void>(
      context,
      builder: (ctx) {
        final tokens = QuillTokens.of(ctx);
        return QuillModal(
          width: w,
          header: QuillModalHeader(
            title: pages.isEmpty ? headingEmpty : headingFull,
            sub: pages.isEmpty ? subtitleEmpty : subtitleFull,
            icon: 'note',
            onClose: () => Navigator.of(ctx).pop(),
          ),
          footer: Row(
            children: [
              const Spacer(),
              QuillSecondaryButton(
                label: 'Close',
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
          child: SizedBox(
            height: h,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              itemCount: pages.length,
              itemBuilder: (_, i) {
                final p = pages[i];
                return _StatsPageRow(
                  title: p.title,
                  trailing: stripMdExtension(p.relativePath),
                  ulid: p.ulid,
                  mono: true,
                  tokens: tokens,
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _showVaultStats(BuildContext context) async {
    final db = context.read<QuillDatabase>();
    final pages = await db.select(db.pages).get();
    final databases = await db.select(db.databases).get();
    final relations = await db.select(db.relations).get();
    final totalBytes = pages.fold<int>(
      0,
      (sum, p) => sum + p.bodyText.length + p.frontmatterJson.length,
    );
    final largest = [...pages]
      ..sort((a, b) => b.bodyText.length.compareTo(a.bodyText.length));
    // Aggregate frontmatter `tags:` lists across pages → frequency map.
    final tagCounts = <String, int>{};
    for (final p in pages) {
      for (final t in listValueFromFrontmatterJson(p.frontmatterJson, 'tags')) {
        final s = t.trim();
        if (s.isNotEmpty) tagCounts[s] = (tagCounts[s] ?? 0) + 1;
      }
    }
    final topTags = tagCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    // Aggregate page count per top-level folder. Pages at the vault
    // root are bucketed under "(root)".
    final folderCounts = <String, int>{};
    for (final p in pages) {
      final slash = p.relativePath.indexOf('/');
      final folder =
          slash == -1 ? '(root)' : p.relativePath.substring(0, slash);
      folderCounts[folder] = (folderCounts[folder] ?? 0) + 1;
    }
    final topFolders = folderCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    // Orphan detection: pages with no incoming AND no outgoing wikilinks.
    // Templates / `.trash/` / `_meta/` would inflate this count but the
    // indexer already excludes them, so the count is a clean hygiene
    // signal.
    final linked = <String>{};
    for (final r in relations) {
      linked.add(r.fromUlid);
      linked.add(r.toUlid);
    }
    final orphans = [
      for (final p in pages)
        if (!linked.contains(p.ulid)) p,
    ]..sort((a, b) => b.mtimeMs.compareTo(a.mtimeMs));
    // "Most-linked" hub pages: count inbound wikilinks per ULID and
    // surface the top few by backlink count. Useful for finding the
    // implicit table-of-contents-style notes in the vault.
    final inboundCounts = <String, int>{};
    for (final r in relations) {
      inboundCounts[r.toUlid] = (inboundCounts[r.toUlid] ?? 0) + 1;
    }
    final pageByUlid = {for (final p in pages) p.ulid: p};
    final hubs = inboundCounts.entries
        .where((e) => pageByUlid.containsKey(e.key))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (!context.mounted) return;
    final size = MediaQuery.of(context).size;
    final w = size.width < 460 ? size.width - 32 : 420.0;
    final maxH = size.height * 0.85;
    await showQuillModal<void>(
      context,
      builder: (ctx) {
        final tokens = QuillTokens.of(ctx);
        return QuillModal(
          width: w,
          header: QuillModalHeader(
            title: 'Vault stats',
            sub:
                '${pages.length} ${pages.length == 1 ? "page" : "pages"} · ${databases.length} ${databases.length == 1 ? "database" : "databases"} · ${relations.length} ${relations.length == 1 ? "relation" : "relations"}.',
            icon: 'database',
            onClose: () => Navigator.of(ctx).pop(),
          ),
          footer: Row(
            children: [
              const Spacer(),
              QuillSecondaryButton(
                label: 'Close',
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                _statRow(tokens, 'Pages indexed', '${pages.length}'),
                _statRow(tokens, 'Databases', '${databases.length}'),
                _statRow(tokens, 'Relations', '${relations.length}'),
                _statRow(tokens, 'Approx size',
                    '${(totalBytes / 1024).toStringAsFixed(1)} KB'),
                const SizedBox(height: 12),
                if (largest.isNotEmpty) ...[
                  Text('LARGEST PAGES',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                        color: tokens.text3,
                      )),
                  const SizedBox(height: 6),
                  for (final p in largest.take(5))
                    _StatsPageRow(
                      title: p.title,
                      trailing:
                          '${(p.bodyText.length / 1024).toStringAsFixed(1)} KB',
                      ulid: p.ulid,
                      mono: true,
                      tokens: tokens,
                    ),
                ],
                if (topTags.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('TOP TAGS',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                        color: tokens.text3,
                      )),
                  const SizedBox(height: 6),
                  for (final t in topTags.take(8))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text('#${t.key}',
                                style: mono(
                                    fontSize: 12, color: tokens.text2),
                                overflow: TextOverflow.ellipsis),
                          ),
                          Text('${t.value}',
                              style: mono(
                                  fontSize: 11, color: tokens.text3)),
                        ],
                      ),
                    ),
                ],
                if (hubs.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('MOST LINKED · hub pages by backlink count',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                        color: tokens.text3,
                      )),
                  const SizedBox(height: 6),
                  for (final h in hubs.take(5))
                    _StatsPageRow(
                      title: pageByUlid[h.key]!.title,
                      trailing: '← ${h.value}',
                      ulid: h.key,
                      mono: true,
                      tokens: tokens,
                    ),
                ],
                if (orphans.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                      'ORPHANS · ${orphans.length} page${orphans.length == 1 ? '' : 's'} with no wikilinks',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                        color: tokens.text3,
                      )),
                  const SizedBox(height: 6),
                  for (final p in orphans.take(5))
                    _StatsPageRow(
                      title: p.title,
                      trailing: p.relativePath,
                      ulid: p.ulid,
                      mono: true,
                      tokens: tokens,
                    ),
                ],
                if (topFolders.length > 1) ...[
                  const SizedBox(height: 12),
                  Text('PAGES BY FOLDER',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                        color: tokens.text3,
                      )),
                  const SizedBox(height: 6),
                  for (final f in topFolders.take(8))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(f.key,
                                style: TextStyle(
                                    fontSize: 12, color: tokens.text2),
                                overflow: TextOverflow.ellipsis),
                          ),
                          Text('${f.value}',
                              style: mono(
                                  fontSize: 11, color: tokens.text3)),
                        ],
                      ),
                    ),
                ],
                const SizedBox(height: 6),
              ],
            ),
          ),
          ),
        );
      },
    );
  }

  Widget _statRow(QuillTokens tokens, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(fontSize: 12.5, color: tokens.text2)),
          ),
          Text(value,
              style: mono(fontSize: 12.5, color: tokens.text)),
        ],
      ),
    );
  }

  Widget _paletteOverlay(BuildContext context) {
    final cubit = _cubit(context);
    return CommandPaletteOverlay(
      onPickPage: (p) {
        cubit.dismiss();
        context.go('/editor/${p.ulid}');
      },
      onPickDatabase: (d) {
        cubit.dismiss();
        context.go('/db/${d.id}');
      },
      onInvokeAction: (a) {
        cubit.dismiss();
        _invokeAction(context, a.label);
      },
    );
  }
}

/// 4-px wide drag strip between the sidebar and the body. Cursor
/// flips to resizeColumn on hover; dragging horizontally tells the
/// parent to grow/shrink the sidebar width. The strip is otherwise
/// transparent so the visual divider stays on the SidebarWidget.
class _SidebarDragHandle extends StatelessWidget {
  const _SidebarDragHandle({required this.onDrag, required this.onDragEnd});
  final void Function(double dx) onDrag;
  final VoidCallback onDragEnd;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: Tooltip(
        message: 'Drag to resize sidebar',
        waitDuration: const Duration(milliseconds: 800),
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragUpdate: (d) => onDrag(d.delta.dx),
          onHorizontalDragEnd: (_) => onDragEnd(),
          child: const SizedBox(width: 4, height: double.infinity),
        ),
      ),
    );
  }
}

/// Row used by `_showVaultStats` for clickable page lists (largest /
/// most-linked / orphans). Tapping closes the dialog and navigates to
/// the corresponding editor route. Pulled out into its own widget so
/// the dialog body stays readable and so the gesture wiring lives in
/// one place.
class _StatsPageRow extends StatefulWidget {
  const _StatsPageRow({
    required this.title,
    required this.trailing,
    required this.ulid,
    required this.mono,
    required this.tokens,
  });

  final String title;
  final String trailing;
  final String ulid;
  final bool mono;
  final QuillTokens tokens;

  @override
  State<_StatsPageRow> createState() => _StatsPageRowState();
}

class _StatsPageRowState extends State<_StatsPageRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).pop();
          context.go('/editor/${widget.ulid}');
        },
        child: Container(
          color: _hover ? tokens.accentTint : null,
          padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
          child: Row(
            children: [
              Expanded(
                child: Tooltip(
                  message: widget.title,
                  waitDuration: const Duration(milliseconds: 600),
                  child: Text(
                    widget.title,
                    style: TextStyle(
                        fontSize: 12,
                        color: _hover ? tokens.accent : tokens.text2),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Tooltip(
                message: widget.trailing,
                waitDuration: const Duration(milliseconds: 600),
                child: Text(
                  widget.trailing,
                  style: widget.mono
                      ? Theme.of(context).textTheme.bodySmall?.merge(
                          TextStyle(
                              fontSize: 11,
                              color: tokens.text3,
                              fontFamily: 'JetBrainsMono'))
                      : TextStyle(fontSize: 11, color: tokens.text3),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
