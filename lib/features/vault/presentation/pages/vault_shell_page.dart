import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/db/quill_database.dart' hide Page;
import '../../../../core/platform/reveal.dart';
import '../../../../core/ulid/ulid_generator.dart';
import '../../../../shared/theme/quill_tokens.dart';
import '../../../../shared/widgets/quill_icon.dart';
import '../../../../shared/theme/tokens.dart';
import '../../../../shared/theme/theme_cubit.dart';
import '../../../commands/presentation/cubit/command_palette_cubit.dart';
import '../../../commands/presentation/widgets/command_palette_overlay.dart';
import '../../../database/data/datasources/csv_importer.dart';
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
import '../../../database/data/repositories/database_repository_impl.dart';
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
      dbRepo: DatabaseRepositoryImpl(context.read<QuillDatabase>()),
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
          const SingleActivator(LogicalKeyboardKey.period, control: true): () =>
              _openQuickCapture(context),
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
                          foregroundColor: Colors.white,
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
    );
  }

  void _navigateBack(BuildContext context) {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
    }
  }

  Future<void> _showShortcuts(BuildContext context) async {
    if (!context.mounted) return;
    final tokens = QuillTokens.of(context);
    await showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: tokens.surface,
        child: SizedBox(
          width: 460,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('KEYBOARD SHORTCUTS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                      color: tokens.text3,
                    )),
                const SizedBox(height: 14),
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
                _kbRow(tokens, '⌘H', 'Home'),
                _kbRow(tokens, '?', 'This shortcut list'),
                const SizedBox(height: 10),
                _kbSection(tokens, 'Editor'),
                _kbRow(tokens, '⌘F', 'Find in page'),
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
                _kbRow(tokens, '⌘⇧H', 'Wrap selection in ==highlight== (source)'),
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
                _kbRow(tokens, '⌘⇧-', 'Insert --- horizontal rule on its own line (source)'),
                _kbRow(tokens, '↵', 'Continue list / increment number (source). ⇧↵ to break out.'),
                _kbRow(tokens, '⌫', 'Strip marker on an empty list item (source).'),
                _kbRow(tokens, '[[ULID]]', 'Wikilink chip'),
                _kbRow(tokens, '[[ULID#anchor]]', 'Link to heading'),
                _kbRow(tokens, '![[ULID]]', 'Transclude page body'),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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

  Future<void> _openRandomPage(BuildContext context) async {
    final db = context.read<QuillDatabase>();
    final messenger = ScaffoldMessenger.maybeOf(context);
    final router = GoRouter.of(context);
    final rows = await (db.select(db.pages)).get();
    if (rows.isEmpty) {
      messenger?.showSnackBar(const SnackBar(
        content: Text('No pages to pick from yet.'),
      ));
      return;
    }
    final pick =
        rows[(DateTime.now().microsecondsSinceEpoch % rows.length).abs()];
    router.go('/editor/${pick.ulid}');
  }

  Future<void> _promptAndBookmarkUrl(
      BuildContext context, String vaultPath) async {
    final controller = TextEditingController();
    final messenger = ScaffoldMessenger.maybeOf(context);
    final vaultBloc = context.read<VaultBloc>();
    final router = GoRouter.of(context);
    final url = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bookmark a URL'),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              hintText: 'https://...',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (v) => Navigator.of(ctx).pop(v),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Bookmark'),
          ),
        ],
      ),
    );
    if (url == null || url.trim().isEmpty) return;
    try {
      final result =
          await UrlBookmark.capture(url, Directory(vaultPath));
      vaultBloc.add(const ReindexVault());
      router.go('/editor/${result.ulid}');
    } catch (e) {
      messenger?.showSnackBar(
          SnackBar(content: Text('Bookmark failed: $e')));
    }
  }

  Future<void> _openQuickCapture(BuildContext context) async {
    final vaultBloc = context.read<VaultBloc>();
    final state = vaultBloc.state;
    if (state is! VaultLoaded) return;
    final controller = TextEditingController();
    final messenger = ScaffoldMessenger.maybeOf(context);
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quick capture'),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: controller,
            autofocus: true,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(
              hintText: 'Capture a thought — it lands at the top of '
                  'Inbox/Quick capture.md with a timestamp.',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (v) => Navigator.of(ctx).pop(v),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Capture'),
          ),
        ],
      ),
    );
    if (text == null || text.trim().isEmpty) return;
    try {
      await QuickCapture.append(text, Directory(state.rootPath));
      vaultBloc.add(const RefreshFromDisk());
      messenger?.showSnackBar(const SnackBar(
        content: Text('Captured → Inbox/Quick capture.md'),
        duration: Duration(seconds: 2),
      ));
    } catch (e) {
      messenger?.showSnackBar(
          SnackBar(content: Text('Capture failed: $e')));
    }
  }

  Future<void> _newPage(BuildContext context) async {
    final vaultBloc = context.read<VaultBloc>();
    if (vaultBloc.state is! VaultLoaded) return;
    final router = GoRouter.of(context);
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New page'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Title'),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(ctx).pop(controller.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (title == null || title.trim().isEmpty) return;
    vaultBloc.add(CreatePage(
      title: title.trim(),
      onCreated: (ulid) => router.go('/editor/$ulid'),
    ));
  }

  Future<void> _invokeAction(BuildContext context, String label) async {
    final vaultBloc = context.read<VaultBloc>();
    final themeCubit = context.read<ThemeCubit>();
    final vaultState = vaultBloc.state;
    final vaultPath = vaultState is VaultLoaded ? vaultState.rootPath : null;
    final messenger = ScaffoldMessenger.maybeOf(context);

    switch (label) {
      case 'Reveal vault in Finder':
        if (vaultPath == null) {
          messenger?.showSnackBar(
            const SnackBar(content: Text('No vault open')),
          );
          return;
        }
        final ok = await Reveal.show(vaultPath);
        if (!ok) {
          messenger?.showSnackBar(
            SnackBar(content: Text('Could not open $vaultPath')),
          );
        }
      case 'Export vault to folder':
        if (vaultPath == null) {
          messenger?.showSnackBar(
            const SnackBar(content: Text('No vault open')),
          );
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
          messenger?.showSnackBar(
            SnackBar(
              content: Text('Exported $n files to $dest'),
              duration: const Duration(seconds: 4),
            ),
          );
        } catch (e) {
          messenger?.showSnackBar(
            SnackBar(content: Text('Export failed: $e')),
          );
        }
      case 'Reindex vault':
        vaultBloc.add(const ReindexVault());
        messenger?.showSnackBar(
          const SnackBar(content: Text('Reindexing vault…')),
        );
      case 'Quick capture':
        await _openQuickCapture(context);
      case 'Bookmark a URL':
        if (vaultPath == null) {
          messenger?.showSnackBar(const SnackBar(content: Text('No vault open')));
          return;
        }
        await _promptAndBookmarkUrl(context, vaultPath);
      case 'Open random page':
        await _openRandomPage(context);
      case "Open today's daily note":
        if (vaultPath == null) {
          messenger?.showSnackBar(const SnackBar(content: Text('No vault open')));
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
          messenger?.showSnackBar(
              SnackBar(content: Text('Daily note failed: $e')));
        }
      case 'Toggle theme':
        await themeCubit.cycleMode();
      case 'Toggle compact mode':
        await themeCubit.toggleCompact();
      case 'Show trash':
        if (vaultPath == null) {
          messenger?.showSnackBar(const SnackBar(content: Text('No vault open')));
          return;
        }
        if (!context.mounted) return;
        await showDialog(
          context: context,
          builder: (_) => BlocProvider.value(
            value: vaultBloc,
            child: TrashDialog(vaultRoot: vaultPath),
          ),
        );
      case 'Export vault as PDF':
        if (vaultPath == null) {
          messenger?.showSnackBar(const SnackBar(content: Text('No vault open')));
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
          messenger?.showSnackBar(SnackBar(
            content: Text('Exported $n pages → $pickedPath'),
            duration: const Duration(seconds: 4),
          ));
        } catch (e) {
          messenger?.showSnackBar(SnackBar(content: Text('PDF export failed: $e')));
        }
      case 'Export vault as HTML':
        if (vaultPath == null) {
          messenger?.showSnackBar(const SnackBar(content: Text('No vault open')));
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
          messenger?.showSnackBar(SnackBar(
            content: Text('Exported $n pages → $dest'),
            duration: const Duration(seconds: 4),
          ));
        } catch (e) {
          messenger?.showSnackBar(SnackBar(content: Text('HTML export failed: $e')));
        }
      case 'Import CSV as database':
        if (vaultPath == null) {
          messenger?.showSnackBar(const SnackBar(content: Text('No vault open')));
          return;
        }
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: const ['csv'],
        );
        if (result == null || result.files.isEmpty) return;
        final picked = result.files.first.path;
        if (picked == null) return;
        try {
          final summary = await const CsvImporter().importTo(
            File(picked),
            Directory(vaultPath),
          );
          vaultBloc.add(const ReindexVault());
          messenger?.showSnackBar(SnackBar(
            content: Text(
                'Imported ${summary.rowsWritten} rows · ${summary.columns} cols → ${summary.folderPath.split('/').last}'),
            duration: const Duration(seconds: 4),
          ));
        } catch (e) {
          messenger?.showSnackBar(SnackBar(content: Text('CSV import failed: $e')));
        }
      case 'Import HTML file as page':
        if (vaultPath == null) {
          messenger?.showSnackBar(const SnackBar(content: Text('No vault open')));
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
          messenger?.showSnackBar(SnackBar(
            content: Text('Imported HTML → ${summary.relativePath}'),
            duration: const Duration(seconds: 4),
          ));
        } catch (e) {
          messenger?.showSnackBar(
              SnackBar(content: Text('HTML import failed: $e')));
        }
      case 'Import Word .docx as page':
        if (vaultPath == null) {
          messenger?.showSnackBar(const SnackBar(content: Text('No vault open')));
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
          messenger?.showSnackBar(SnackBar(
            content: Text('Imported → ${summary.relativePath}'),
            duration: const Duration(seconds: 4),
          ));
        } catch (e) {
          messenger?.showSnackBar(
              SnackBar(content: Text('Word import failed: $e')));
        }
      case 'Import Evernote .enex notebook':
        if (vaultPath == null) {
          messenger?.showSnackBar(const SnackBar(content: Text('No vault open')));
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
          messenger?.showSnackBar(SnackBar(
            content: Text(
                'Imported ${summary.notes.length} notes → ${summary.folder}/'),
            duration: const Duration(seconds: 4),
          ));
        } catch (e) {
          messenger?.showSnackBar(
              SnackBar(content: Text('Evernote import failed: $e')));
        }
      case 'Import Asana CSV as database':
        if (vaultPath == null) {
          messenger?.showSnackBar(const SnackBar(content: Text('No vault open')));
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
          messenger?.showSnackBar(SnackBar(
            content: Text(
                'Imported ${summary.tasks.length} tasks → ${summary.folder}/'),
            duration: const Duration(seconds: 4),
          ));
        } catch (e) {
          messenger?.showSnackBar(
              SnackBar(content: Text('Asana import failed: $e')));
        }
      case 'Import Trello board as database':
        if (vaultPath == null) {
          messenger?.showSnackBar(const SnackBar(content: Text('No vault open')));
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
          messenger?.showSnackBar(SnackBar(
            content: Text(
                'Imported ${summary.cards.length} cards → ${summary.folder}/'),
            duration: const Duration(seconds: 4),
          ));
        } catch (e) {
          messenger?.showSnackBar(
              SnackBar(content: Text('Trello import failed: $e')));
        }
      case 'Import Roam JSON export':
        if (vaultPath == null) {
          messenger?.showSnackBar(const SnackBar(content: Text('No vault open')));
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
          messenger?.showSnackBar(SnackBar(
            content: Text(
                'Imported ${summary.pages.length} pages → ${summary.folder}/'),
            duration: const Duration(seconds: 4),
          ));
        } catch (e) {
          messenger?.showSnackBar(
              SnackBar(content: Text('Roam import failed: $e')));
        }
      case 'Import OPML outline as page':
        if (vaultPath == null) {
          messenger?.showSnackBar(const SnackBar(content: Text('No vault open')));
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
          messenger?.showSnackBar(SnackBar(
            content: Text('Imported OPML → ${summary.relativePath}'),
            duration: const Duration(seconds: 4),
          ));
        } catch (e) {
          messenger?.showSnackBar(
              SnackBar(content: Text('OPML import failed: $e')));
        }
      case 'Import text file as page':
      case 'Import Markdown file as page':
        if (vaultPath == null) {
          messenger?.showSnackBar(const SnackBar(content: Text('No vault open')));
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
          messenger?.showSnackBar(SnackBar(
            content: Text('Imported → ${summary.relativePath}'),
            duration: const Duration(seconds: 4),
          ));
        } catch (e) {
          messenger?.showSnackBar(
              SnackBar(content: Text('Import failed: $e')));
        }
      case 'New page from template…':
        if (vaultPath == null) {
          messenger?.showSnackBar(const SnackBar(content: Text('No vault open')));
          return;
        }
        final db = context.read<QuillDatabase>();
        final templates = await (db.select(db.pages)
              ..where((p) => p.relativePath.like('Templates/%') |
                  p.relativePath.like('Templates\\%')))
            .get();
        if (templates.isEmpty) {
          messenger?.showSnackBar(const SnackBar(
            content: Text(
                'No templates yet. Create a Templates/ folder at the vault root and add .md files.'),
            duration: Duration(seconds: 4),
          ));
          return;
        }
        if (!context.mounted) return;
        final picked = await showDialog<String>(
          context: context,
          builder: (ctx) {
            final t = QuillTokens.of(ctx);
            return SimpleDialog(
              title: const Text('New page from template'),
              children: [
                for (final tpl in templates)
                  SimpleDialogOption(
                    onPressed: () => Navigator.of(ctx).pop(tpl.ulid),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tpl.title,
                              style: TextStyle(
                                  fontSize: 13.5, color: t.text)),
                          Text(tpl.relativePath,
                              style: TextStyle(
                                  fontSize: 11, color: t.text3)),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        );
        if (picked == null) return;
        if (!context.mounted) return;
        final router = GoRouter.of(context);
        vaultBloc.add(DuplicatePage(
          picked,
          targetFolder: '',
          onCreated: (newUlid) => router.go('/editor/$newUlid'),
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
          messenger?.showSnackBar(const SnackBar(content: Text('No vault open')));
          return;
        }
        if (!context.mounted) return;
        await _createDatabase(context, Directory(vaultPath));
      case 'Install built-in templates':
        if (vaultPath == null) {
          messenger?.showSnackBar(const SnackBar(content: Text('No vault open')));
          return;
        }
        try {
          final n = await const SeedTemplates().install(Directory(vaultPath));
          messenger?.showSnackBar(SnackBar(
            content: Text(
              n == 0
                  ? 'Templates already installed.'
                  : 'Installed $n templates → Templates/',
            ),
            duration: const Duration(seconds: 4),
          ));
          vaultBloc.add(const RefreshFromDisk());
        } catch (e) {
          messenger?.showSnackBar(SnackBar(
              content: Text('Could not install templates: $e')));
        }
    }
  }

  Future<void> _createDatabase(
      BuildContext context, Directory vaultRoot) async {
    final ctl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New database'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Quill creates a folder under your vault and seeds it with a '
              'minimal .database.yaml. Each .md inside the folder becomes '
              'a row.',
              style: TextStyle(fontSize: 12.5),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctl,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Database name',
              ),
              onSubmitted: (v) => Navigator.of(ctx).pop(v),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(ctl.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty) return;
    final safe = name.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final folder = Directory('${vaultRoot.path}/$safe');
    if (await folder.exists()) {
      if (!context.mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text('Folder already exists: $safe')),
      );
      return;
    }
    final ulids = const UlidGenerator();
    final id = ulids.generate();
    final yaml = '''id: $id
name: $name
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
    final messenger = ScaffoldMessenger.maybeOf(context);
    context.read<VaultBloc>().add(const ReindexVault());
    messenger?.showSnackBar(
      SnackBar(
        content: Text('Created database: $safe'),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _showVaultStats(BuildContext context) async {
    final db = context.read<QuillDatabase>();
    final pages = await db.select(db.pages).get();
    final databases = await db.select(db.databases).get();
    final relations = await db.select(db.relations).get();
    final totalBytes =
        pages.fold<int>(0, (sum, p) => sum + (p.bodyText.length + p.frontmatterJson.length).toInt());
    final largest = [...pages]
      ..sort((a, b) => b.bodyText.length.compareTo(a.bodyText.length));
    // Aggregate frontmatter `tags:` lists across pages → frequency map.
    final tagCounts = <String, int>{};
    for (final p in pages) {
      if (p.frontmatterJson.isEmpty) continue;
      try {
        final m = jsonDecode(p.frontmatterJson);
        if (m is! Map) continue;
        final raw = m['tags'];
        if (raw is List) {
          for (final t in raw) {
            final s = '$t'.trim();
            if (s.isNotEmpty) {
              tagCounts[s] = (tagCounts[s] ?? 0) + 1;
            }
          }
        } else if (raw is String && raw.trim().isNotEmpty) {
          tagCounts[raw.trim()] = (tagCounts[raw.trim()] ?? 0) + 1;
        }
      } catch (_) {/* malformed cached frontmatter */}
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
    final tokens = QuillTokens.of(context);
    await showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: tokens.surface,
        child: SizedBox(
          width: 420,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('VAULT STATS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                      color: tokens.text3,
                    )),
                const SizedBox(height: 14),
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
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(p.title,
                                style: TextStyle(
                                    fontSize: 12, color: tokens.text2),
                                overflow: TextOverflow.ellipsis),
                          ),
                          Text('${(p.bodyText.length / 1024).toStringAsFixed(1)} KB',
                              style: mono(
                                  fontSize: 11, color: tokens.text3)),
                        ],
                      ),
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
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(pageByUlid[h.key]!.title,
                                style: TextStyle(
                                    fontSize: 12, color: tokens.text2),
                                overflow: TextOverflow.ellipsis),
                          ),
                          Text('← ${h.value}',
                              style: mono(
                                  fontSize: 11, color: tokens.text3)),
                        ],
                      ),
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
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(p.title,
                                style: TextStyle(
                                    fontSize: 12, color: tokens.text2),
                                overflow: TextOverflow.ellipsis),
                          ),
                          Text(p.relativePath,
                              style: mono(
                                  fontSize: 10.5, color: tokens.text3),
                              overflow: TextOverflow.ellipsis),
                        ],
                      ),
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
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
    return CommandPaletteOverlay(
      onPickPage: (p) {
        context.read<CommandPaletteCubit>().dismiss();
        context.go('/editor/${p.ulid}');
      },
      onPickDatabase: (d) {
        context.read<CommandPaletteCubit>().dismiss();
        context.go('/db/${d.id}');
      },
      onInvokeAction: (a) {
        context.read<CommandPaletteCubit>().dismiss();
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
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: (d) => onDrag(d.delta.dx),
        onHorizontalDragEnd: (_) => onDragEnd(),
        child: const SizedBox(width: 4, height: double.infinity),
      ),
    );
  }
}
