import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';

import '../../../../core/db/quill_database.dart' hide Page;
import '../../../../core/paths.dart';
import '../../../../core/platform/reveal.dart';
import '../../../../shared/theme/quill_tokens.dart';
import '../../../../shared/theme/tokens.dart';
import '../../../../shared/widgets/emoji_picker.dart';
import '../../../../shared/widgets/page_icon.dart';
import '../../../../shared/widgets/quill_icon.dart';
import '../../../../shared/widgets/responsive_layout.dart';
import '../../../../shared/widgets/segment.dart';
import '../../../vault/data/daily_note.dart';
import '../../../vault/data/html_exporter.dart';
import '../../../vault/data/indexer.dart';
import '../../../vault/data/pdf_exporter.dart';
import '../../../vault/domain/entities/frontmatter_entry.dart';
import '../../../vault/domain/entities/vault_tree.dart';
import '../../../vault/domain/repositories/vault_repository.dart';
// ignore: unused_import — Indexer used via context.read
import '../../../vault/presentation/bloc/vault_bloc.dart';
import '../../../vault/presentation/bloc/vault_event.dart';
import '../../../vault/presentation/bloc/vault_state.dart';
import '../../../vault/presentation/widgets/page_header.dart';
import '../../domain/strip_markdown.dart';
import '../bloc/editor_bloc.dart';
import '../bloc/editor_event.dart';
import '../bloc/editor_state.dart';
import '../widgets/backlinks_rail.dart';
import '../widgets/comments_dialog.dart';
import '../widgets/frontmatter_card.dart';
import '../widgets/page_history_dialog.dart';
import '../widgets/markdown_renderer.dart';
import '../widgets/outline_rail.dart';
import '../widgets/page_title_field.dart';
import '../widgets/properties_panel.dart';
import '../widgets/source_view.dart';

class EditorPage extends StatelessWidget {
  const EditorPage({super.key, required this.ulid, this.anchor});
  final String ulid;

  /// When non-null, the editor scrolls to the first heading whose
  /// slugified text matches. Populated from `?anchor=…` in the URL.
  final String? anchor;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<EditorBloc>(
      key: ValueKey(ulid),
      create: (context) {
        final bloc = EditorBloc(
          repo: context.read<VaultRepository>(),
          indexer: context.read<Indexer>(),
          db: context.read<QuillDatabase>(),
        );
        final vaultState = context.read<VaultBloc>().state;
        if (vaultState is VaultLoaded) {
          bloc.setVaultRoot(Directory(vaultState.rootPath));
          bloc.setCurrentUser(vaultState.workspace.currentUserName);
        }
        bloc.add(OpenEditor(ulid));
        return bloc;
      },
      child: _EditorBody(anchor: anchor),
    );
  }
}

class _EditorBody extends StatefulWidget {
  const _EditorBody({this.anchor});
  final String? anchor;

  @override
  State<_EditorBody> createState() => _EditorBodyState();
}

/// "saved Xs ago" / "Xm ago" / "Xh ago" / "Xd ago" / "now" — formats a
/// timestamp from frontmatter mtime to a tiny relative string the page
/// header can show without a Timer (cached per build is good enough).
String _relativeMtime(int mtimeMs) {
  final now = DateTime.now().millisecondsSinceEpoch;
  final secs = ((now - mtimeMs) ~/ 1000).clamp(0, 1 << 30);
  if (secs < 5) return 'just now';
  if (secs < 60) return '${secs}s ago';
  final mins = secs ~/ 60;
  if (mins < 60) return '${mins}m ago';
  final hrs = mins ~/ 60;
  if (hrs < 24) return '${hrs}h ago';
  final days = hrs ~/ 24;
  return '${days}d ago';
}

/// Heading slug: lowercase, runs of non-word collapsed to `-`, trimmed.
/// Mirrors the common GFM heading-anchor convention.
String _slugify(String s) {
  final lower = s.toLowerCase();
  final cleaned = lower.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  return cleaned.replaceAll(RegExp(r'(^-+)|(-+$)'), '');
}

bool _isFullWidth(dynamic frontmatter) {
  final v = frontmatter.get('full_width');
  if (v == true) return true;
  return '${v ?? ''}'.toLowerCase() == 'true';
}

class _EditorBodyState extends State<_EditorBody> {
  bool _propertiesOpen = false;
  bool _rightRailHidden = false;
  final ScrollController _scroll = ScrollController();
  bool _anchorJumped = false;

  // Find-in-page state (M85). Visible only when _findOpen; matches are
  // (lineIdx) entries into the body, recomputed on every query change.
  bool _findOpen = false;
  final TextEditingController _findCtl = TextEditingController();
  final FocusNode _findFocus = FocusNode();
  List<int> _findMatches = const [];
  int _findCursor = 0;

  @override
  void dispose() {
    _scroll.dispose();
    _findCtl.dispose();
    _findFocus.dispose();
    super.dispose();
  }

  void _openFind() {
    setState(() => _findOpen = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _findFocus.requestFocus();
      _findCtl.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _findCtl.text.length,
      );
    });
  }

  void _closeFind() {
    setState(() {
      _findOpen = false;
      _findMatches = const [];
      _findCursor = 0;
    });
  }

  void _recomputeFind(String body) {
    final q = _findCtl.text.trim();
    if (q.isEmpty) {
      setState(() {
        _findMatches = const [];
        _findCursor = 0;
      });
      return;
    }
    final lower = body.toLowerCase();
    final needle = q.toLowerCase();
    final lines = body.split('\n');
    final hits = <int>[];
    int searchFrom = 0;
    while (true) {
      final idx = lower.indexOf(needle, searchFrom);
      if (idx < 0) break;
      // Convert byte offset to line index.
      final before = body.substring(0, idx);
      final lineIdx = '\n'.allMatches(before).length;
      if (hits.isEmpty || hits.last != lineIdx) hits.add(lineIdx);
      searchFrom = idx + needle.length;
    }
    setState(() {
      _findMatches = hits;
      _findCursor = hits.isEmpty ? 0 : 0;
    });
    if (hits.isNotEmpty) _scrollToMatch(lines.length);
  }

  void _step(int delta, String body) {
    if (_findMatches.isEmpty) return;
    final next = (_findCursor + delta) % _findMatches.length;
    setState(() => _findCursor = next < 0 ? next + _findMatches.length : next);
    _scrollToMatch(body.split('\n').length);
  }

  void _scrollToMatch(int totalLines) {
    if (_findMatches.isEmpty || !_scroll.hasClients) return;
    final lineIdx = _findMatches[_findCursor];
    final frac = totalLines == 0 ? 0.0 : lineIdx / totalLines;
    final pos = _scroll.position;
    final target = (pos.maxScrollExtent * frac)
        .clamp(pos.minScrollExtent, pos.maxScrollExtent);
    pos.animateTo(target,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut);
  }

  /// After the body lays out, scroll to the heading line whose slug
  /// matches `anchor`. We approximate the offset as
  ///   (lineIdx / totalLines) * maxScrollExtent
  /// — same heuristic the TOC links use (M68) — which is close enough
  /// for monospace-tall heading rows and degrades gracefully for
  /// pages with mixed block heights.
  void _jumpToAnchorIfNeeded(String body) {
    if (_anchorJumped) return;
    final anchor = widget.anchor;
    if (anchor == null || anchor.isEmpty) return;
    _anchorJumped = true;
    final lines = body.split('\n');
    int? hit;
    for (var i = 0; i < lines.length; i++) {
      final l = lines[i];
      String? heading;
      if (l.startsWith('# ')) {
        heading = l.substring(2);
      } else if (l.startsWith('## ')) {
        heading = l.substring(3);
      } else if (l.startsWith('### ')) {
        heading = l.substring(4);
      }
      if (heading != null && _slugify(heading) == anchor) {
        hit = i;
        break;
      }
    }
    if (hit == null) return;
    final frac = lines.isEmpty ? 0.0 : hit / lines.length;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final pos = _scroll.position;
      final target = (pos.maxScrollExtent * frac)
          .clamp(pos.minScrollExtent, pos.maxScrollExtent);
      pos.animateTo(target,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOut);
    });
  }

  Future<void> _pickIcon(BuildContext context, EditorLoaded loaded) async {
    final bloc = context.read<EditorBloc>();
    final picked = await pickEmoji(context);
    if (picked == null) return; // dismissed without choosing
    final fm = loaded.page.frontmatter;
    final existing = fm.find('icon');
    if (picked.isEmpty) {
      // "Clear" — remove the icon entry entirely.
      if (existing != null) {
        bloc.add(const RemoveFrontmatterField('icon'));
      }
      return;
    }
    if (existing == null) {
      bloc.add(AddFrontmatterField(FrontmatterEntry(
        key: 'icon',
        rawScalar: picked,
        type: FrontmatterType.text,
        value: picked,
      )));
    } else {
      bloc.add(EditFrontmatterField(
        'icon',
        existing.copyWith(rawScalar: picked, value: picked),
      ));
    }
  }

  Future<void> _showPageMenu(BuildContext context, EditorLoaded loaded) async {
    final box = context.findRenderObject() as RenderBox?;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null) return;
    final pos = box.localToGlobal(box.size.bottomLeft(Offset.zero),
        ancestor: overlay);
    final ulid = loaded.page.ulid;
    final action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx, 0),
      items: const [
        PopupMenuItem(value: 'copy-ulid', child: Text('Copy ULID')),
        PopupMenuItem(value: 'copy-link', child: Text('Copy [[link]]')),
        PopupMenuItem(value: 'reveal', child: Text('Reveal in Finder')),
        PopupMenuItem(value: 'duplicate', child: Text('Duplicate page')),
        PopupMenuItem(value: 'move', child: Text('Move to folder…')),
        PopupMenuItem(value: 'history', child: Text('Page history…')),
        PopupMenuItem(value: 'copy-body', child: Text('Copy page body')),
        PopupMenuItem(value: 'copy-plain', child: Text('Copy as plain text')),
        PopupMenuItem(value: 'export-md', child: Text('Export as .md…')),
        PopupMenuItem(value: 'export-html', child: Text('Export as .html…')),
        PopupMenuItem(value: 'print-page', child: Text('Print page…')),
        PopupMenuDivider(),
        PopupMenuItem(value: 'add-tags', child: Text('Add tags…')),
        PopupMenuItem(value: 'set-font', child: Text('Set page font…')),
        PopupMenuItem(value: 'set-reminder', child: Text('Set reminder…')),
        PopupMenuItem(value: 'set-goal', child: Text('Set word count goal…')),
        PopupMenuDivider(),
        PopupMenuItem(value: 'trash', child: Text('Move to trash')),
        PopupMenuItem(value: 'reindex', child: Text('Reindex vault')),
      ],
    );
    if (action == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    switch (action) {
      case 'copy-ulid':
        await Clipboard.setData(ClipboardData(text: ulid));
        messenger?.showSnackBar(
          SnackBar(content: Text('Copied $ulid'),
              duration: const Duration(seconds: 2)),
        );
      case 'copy-link':
        await Clipboard.setData(ClipboardData(text: '[[$ulid]]'));
        messenger?.showSnackBar(
          SnackBar(content: Text('Copied [[$ulid]]'),
              duration: const Duration(seconds: 2)),
        );
      case 'reveal':
        final vault = context.read<VaultBloc>().state;
        if (vault is VaultLoaded) {
          await Reveal.show('${vault.rootPath}/${loaded.page.relativePath}');
        }
      case 'history':
        await _showPageHistory(context, loaded);
      case 'copy-body':
        await Clipboard.setData(ClipboardData(text: loaded.page.body));
        messenger?.showSnackBar(
          SnackBar(
            content: Text(
                'Copied ${loaded.page.body.length} chars to clipboard'),
            duration: const Duration(seconds: 2),
          ),
        );
      case 'copy-plain':
        final plain = stripMarkdown(loaded.page.body);
        await Clipboard.setData(ClipboardData(text: plain));
        messenger?.showSnackBar(
          SnackBar(
            content: Text('Copied ${plain.length} chars as plain text'),
            duration: const Duration(seconds: 2),
          ),
        );
      case 'export-md':
        await _exportPageAsMarkdown(context, loaded);
      case 'export-html':
        await _exportPageAsHtml(context, loaded);
      case 'print-page':
        await _printPage(context, loaded);
      case 'add-tags':
        await _addTags(context, loaded);
      case 'set-font':
        await _setFont(context, loaded);
      case 'set-reminder':
        await _setReminder(context, loaded);
      case 'set-goal':
        await _setWordGoal(context, loaded);
      case 'move':
        await _moveToFolder(context, loaded);
      case 'duplicate':
        final router = GoRouter.of(context);
        context.read<VaultBloc>().add(DuplicatePage(
              ulid,
              onCreated: (newUlid) {
                messenger?.showSnackBar(
                  const SnackBar(
                    content: Text('Page duplicated'),
                    duration: Duration(seconds: 2),
                  ),
                );
                router.go('/editor/$newUlid');
              },
            ));
      case 'trash':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Move to trash?'),
            content: Text(
                'The .md file moves to .trash/<YYYY-MM>/${loaded.page.relativePath}. '
                'You can restore it from the Trash dialog later.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style:
                    TextButton.styleFrom(foregroundColor: const Color(0xFFCB5A4F)),
                child: const Text('Move to trash'),
              ),
            ],
          ),
        );
        if (confirmed != true || !context.mounted) return;
        context.read<VaultBloc>().add(MoveToTrash(ulid));
        GoRouter.of(context).go('/home');
      case 'reindex':
        if (!context.mounted) return;
        context.read<VaultBloc>().add(const ReindexVault());
        messenger?.showSnackBar(
          const SnackBar(content: Text('Reindexing vault…')),
        );
    }
  }

  Future<void> _showPageHistory(
      BuildContext context, EditorLoaded loaded) async {
    final vault = context.read<VaultBloc>().state;
    if (vault is! VaultLoaded) return;
    await showDialog<void>(
      context: context,
      builder: (_) => PageHistoryDialog(
        vaultRoot: vault.rootPath,
        relativePath: loaded.page.relativePath,
      ),
    );
  }

  Future<void> _printPage(BuildContext context, EditorLoaded loaded) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final bytes = await const PdfExporter().exportSingle(
        title: loaded.page.title,
        body: loaded.page.body,
      );
      await Printing.layoutPdf(
        name: loaded.page.title,
        onLayout: (_) async => Uint8List.fromList(bytes),
      );
    } catch (e) {
      messenger?.showSnackBar(SnackBar(content: Text('Print failed: $e')));
    }
  }

  Future<void> _moveToFolder(
      BuildContext context, EditorLoaded loaded) async {
    final vault = context.read<VaultBloc>().state;
    if (vault is! VaultLoaded) return;
    final folders = <String>{};
    void walk(VaultNode n) {
      if (n is VaultFolder) {
        folders.add(n.relativePath);
        for (final c in n.children) {
          walk(c);
        }
      }
    }
    for (final n in vault.tree.topLevel) {
      walk(n);
    }
    final sorted = folders.toList()..sort();
    // Drop the folder the page is already in — moving there is a no-op.
    final currentFolder = loaded.page.relativePath.contains('/')
        ? loaded.page.relativePath
            .substring(0, loaded.page.relativePath.lastIndexOf('/'))
        : '';
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final tokens = QuillTokens.of(ctx);
        return SimpleDialog(
          title: const Text('Move to folder'),
          children: [
            if (currentFolder != '')
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, ''),
                child: Text('(vault root)',
                    style: TextStyle(color: tokens.text2)),
              ),
            for (final f in sorted)
              if (f != currentFolder)
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, f),
                  child: Text(f),
                ),
          ],
        );
      },
    );
    if (picked == null) return;
    if (!context.mounted) return;
    context.read<VaultBloc>().add(
        MovePage(ulid: loaded.page.ulid, targetFolder: picked));
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      SnackBar(
          content: Text(picked.isEmpty
              ? 'Moved to vault root'
              : 'Moved to $picked'),
          duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _setFont(
      BuildContext context, EditorLoaded loaded) async {
    final fm = loaded.page.frontmatter;
    final existing = fm.find('font');
    final current = existing?.rawScalar.trim().toLowerCase() ?? '';
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Page font'),
        children: [
          for (final option in const [
            ('sans', 'Sans-serif (default)'),
            ('serif', 'Serif (Georgia)'),
            ('mono', 'Monospace (JetBrainsMono)'),
          ])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, option.$1),
              child: Row(
                children: [
                  if (current == option.$1 ||
                      (current.isEmpty && option.$1 == 'sans'))
                    const Icon(Icons.check, size: 14)
                  else
                    const SizedBox(width: 14),
                  const SizedBox(width: 8),
                  Text(option.$2),
                ],
              ),
            ),
        ],
      ),
    );
    if (picked == null || !context.mounted) return;
    final bloc = context.read<EditorBloc>();
    if (picked == 'sans') {
      // Default — strip the frontmatter entry entirely.
      if (existing != null) {
        bloc.add(const RemoveFrontmatterField('font'));
      }
      return;
    }
    if (existing == null) {
      bloc.add(AddFrontmatterField(FrontmatterEntry(
        key: 'font',
        rawScalar: picked,
        type: FrontmatterType.text,
        value: picked,
      )));
    } else {
      bloc.add(EditFrontmatterField(
        'font',
        existing.copyWith(rawScalar: picked, value: picked),
      ));
    }
  }

  Future<void> _addTags(
      BuildContext context, EditorLoaded loaded) async {
    final fm = loaded.page.frontmatter;
    final existing = fm.find('tags');
    final currentTags = <String>[];
    if (existing != null) {
      final v = existing.value;
      if (v is List) {
        for (final t in v) {
          final s = '$t'.trim();
          if (s.isNotEmpty) currentTags.add(s);
        }
      } else if (v is String && v.trim().isNotEmpty) {
        currentTags.add(v.trim());
      }
    }
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add tags'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (currentTags.isNotEmpty) ...[
              Text(
                'Current: ${currentTags.join(', ')}',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 8),
            ],
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'tag1, tag2',
                helperText: 'Comma-separated. New tags are merged with current.',
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
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (result == null) return;
    final added = <String>[
      for (final t in result.split(','))
        if (t.trim().isNotEmpty) t.trim(),
    ];
    if (added.isEmpty) return;
    // Merge + dedupe, preserving order: current first, then new.
    final merged = <String>[...currentTags];
    for (final t in added) {
      if (!merged.contains(t)) merged.add(t);
    }
    if (!context.mounted) return;
    final bloc = context.read<EditorBloc>();
    final raw = '[${merged.join(', ')}]';
    if (existing == null) {
      bloc.add(AddFrontmatterField(FrontmatterEntry(
        key: 'tags',
        rawScalar: raw,
        type: FrontmatterType.multi,
        value: merged,
      )));
    } else {
      bloc.add(EditFrontmatterField(
        'tags',
        existing.copyWith(rawScalar: raw, value: merged),
      ));
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      SnackBar(
        content: Text('Tags: ${merged.join(', ')}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _setWordGoal(
      BuildContext context, EditorLoaded loaded) async {
    final fm = loaded.page.frontmatter;
    final existing = fm.find('goal');
    final initial = existing?.rawScalar ?? '';
    final controller = TextEditingController(text: initial);
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set word count goal'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
              hintText: 'e.g. 500',
              helperText: 'Empty to clear. The footer will show progress.'),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (picked == null || !context.mounted) return;
    final trimmed = picked.trim();
    final bloc = context.read<EditorBloc>();
    if (trimmed.isEmpty) {
      if (existing != null) {
        bloc.add(const RemoveFrontmatterField('goal'));
      }
      return;
    }
    final n = int.tryParse(trimmed);
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (n == null || n < 1) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('Goal must be a positive whole number')),
      );
      return;
    }
    if (existing == null) {
      bloc.add(AddFrontmatterField(FrontmatterEntry(
        key: 'goal',
        rawScalar: '$n',
        type: FrontmatterType.number,
        value: n,
      )));
    } else {
      bloc.add(EditFrontmatterField(
        'goal',
        existing.copyWith(rawScalar: '$n', value: n),
      ));
    }
    messenger?.showSnackBar(
      SnackBar(content: Text('Word count goal: $n'),
          duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _setReminder(
      BuildContext context, EditorLoaded loaded) async {
    final fm = loaded.page.frontmatter;
    final existing = fm.find('reminder');
    final now = DateTime.now();
    DateTime initial = DateTime(now.year, now.month, now.day);
    if (existing != null) {
      final parsed = DateTime.tryParse(existing.rawScalar);
      if (parsed != null) initial = parsed;
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      helpText: 'Set page reminder',
    );
    if (picked == null) return;
    if (!context.mounted) return;
    final iso =
        '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    final bloc = context.read<EditorBloc>();
    if (existing == null) {
      bloc.add(AddFrontmatterField(FrontmatterEntry(
        key: 'reminder',
        rawScalar: iso,
        type: FrontmatterType.date,
        value: iso,
      )));
    } else {
      bloc.add(EditFrontmatterField(
        'reminder',
        existing.copyWith(rawScalar: iso, value: iso),
      ));
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      SnackBar(content: Text('Reminder set for $iso'),
          duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _exportPageAsHtml(
      BuildContext context, EditorLoaded loaded) async {
    final safeName = loaded.page.title
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .trim();
    final picked = await FilePicker.platform.saveFile(
      dialogTitle: 'Export page as HTML…',
      fileName: '${safeName.isEmpty ? 'page' : safeName}.html',
      type: FileType.custom,
      allowedExtensions: const ['html'],
    );
    if (picked == null) return;
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final html = HtmlExporter.renderStandalonePage(
        title: loaded.page.title,
        body: loaded.page.body,
      );
      await File(picked).writeAsString(html);
      messenger?.showSnackBar(
        SnackBar(content: Text('Exported to $picked')),
      );
    } catch (e) {
      messenger?.showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  Future<void> _exportPageAsMarkdown(
      BuildContext context, EditorLoaded loaded) async {
    final vault = context.read<VaultBloc>().state;
    if (vault is! VaultLoaded) return;
    final relPath = loaded.page.relativePath;
    final source = File('${vault.rootPath}/$relPath');
    if (!await source.exists()) return;
    final safeName = loaded.page.title
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .trim();
    final picked = await FilePicker.platform.saveFile(
      dialogTitle: 'Export page as Markdown…',
      fileName: '${safeName.isEmpty ? 'page' : safeName}.md',
      type: FileType.custom,
      allowedExtensions: const ['md'],
    );
    if (picked == null) return;
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await source.copy(picked);
      messenger?.showSnackBar(
        SnackBar(content: Text('Exported to $picked')),
      );
    } catch (e) {
      messenger?.showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  Future<void> _revealCurrentPage(
      BuildContext context, EditorLoaded loaded) async {
    final vault = context.read<VaultBloc>().state;
    if (vault is! VaultLoaded) return;
    await Reveal.show('${vault.rootPath}/${loaded.page.relativePath}');
  }

  Future<void> _openBlockComments(
      BuildContext context, String pageUlid, String blockId) async {
    final vault = context.read<VaultBloc>().state;
    if (vault is! VaultLoaded) return;
    await showDialog<void>(
      context: context,
      builder: (_) => CommentsDialog(
        vaultRoot: vault.rootPath,
        pageUlid: pageUlid,
        defaultAuthor: vault.workspace.currentUserName ?? 'You',
        blockId: blockId,
      ),
    );
  }

  void _flushSave(BuildContext context, EditorLoaded loaded) {
    final bloc = context.read<EditorBloc>();
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (loaded.dirty) {
      bloc.add(const SaveNow());
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('Saving…'),
          duration: Duration(seconds: 1),
        ),
      );
    } else {
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('Already saved'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  void _toggleEditorMode(BuildContext context, EditorLoaded loaded) {
    final next = loaded.mode == EditorMode.rendered
        ? EditorMode.source
        : EditorMode.rendered;
    context.read<EditorBloc>().add(ToggleEditorMode(next));
  }

  void _toggleLock(BuildContext context, EditorLoaded loaded) {
    final bloc = context.read<EditorBloc>();
    final wasLocked = EditorBloc.isLocked(loaded);
    final fm = loaded.page.frontmatter;
    final existing = fm.find('locked');
    final next = wasLocked ? 'false' : 'true';
    if (existing == null) {
      bloc.add(AddFrontmatterField(FrontmatterEntry(
        key: 'locked',
        rawScalar: next,
        type: FrontmatterType.checkbox,
        value: !wasLocked,
      )));
    } else {
      bloc.add(EditFrontmatterField(
        'locked',
        existing.copyWith(rawScalar: next, value: !wasLocked),
      ));
    }
  }

  void _togglePin(BuildContext context, EditorLoaded loaded) {
    final vault = context.read<VaultBloc>();
    final messenger = ScaffoldMessenger.maybeOf(context);
    final ulid = loaded.page.ulid;
    if (ulid.isEmpty) return;
    final state = vault.state;
    final wasPinned = state is VaultLoaded
        ? state.workspace.favorites.contains(ulid)
        : false;
    vault.add(ToggleFavorite(ulid));
    messenger?.showSnackBar(SnackBar(
      content:
          Text(wasPinned ? 'Unpinned from favorites' : 'Pinned to favorites'),
      duration: const Duration(seconds: 2),
    ));
  }

  void _toggleFullWidth(BuildContext context, EditorLoaded loaded) {
    final bloc = context.read<EditorBloc>();
    final fm = loaded.page.frontmatter;
    final wasFull = _isFullWidth(fm);
    final existing = fm.find('full_width');
    final next = wasFull ? 'false' : 'true';
    if (existing == null) {
      bloc.add(AddFrontmatterField(FrontmatterEntry(
        key: 'full_width',
        rawScalar: next,
        type: FrontmatterType.checkbox,
        value: !wasFull,
      )));
    } else {
      bloc.add(EditFrontmatterField(
        'full_width',
        existing.copyWith(rawScalar: next, value: !wasFull),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    return BlocBuilder<EditorBloc, EditorState>(
      builder: (context, state) {
        if (state is EditorLoading || state is EditorIdle) {
          return Center(
            child: SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 1.5, color: tokens.text2),
            ),
          );
        }
        if (state is EditorError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                state.message,
                style: TextStyle(color: tokens.text2, fontSize: 14),
              ),
            ),
          );
        }
        final loaded = state as EditorLoaded;
        final page = loaded.page;
        // Strip the `.md` extension from the trailing breadcrumb so
        // the header reads "Operations / Customers / Acmeco" instead
        // of "… / Acmeco.md". File-on-disk path is still surfaced via
        // the editor kebab → Reveal in Finder for power users.
        final crumbs = stripMdExtension(page.relativePath).split('/');
        final mobile = isMobileWidth(context);
        final locked = EditorBloc.isLocked(loaded);
        return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.keyF, meta: true): () =>
                _openFind(),
            const SingleActivator(LogicalKeyboardKey.keyF, control: true): () =>
                _openFind(),
            const SingleActivator(LogicalKeyboardKey.keyS, meta: true): () =>
                _flushSave(context, loaded),
            const SingleActivator(LogicalKeyboardKey.keyS, control: true): () =>
                _flushSave(context, loaded),
            const SingleActivator(LogicalKeyboardKey.keyG, meta: true): () {
              if (_findOpen) _step(1, page.body);
            },
            const SingleActivator(LogicalKeyboardKey.keyG, control: true): () {
              if (_findOpen) _step(1, page.body);
            },
            const SingleActivator(LogicalKeyboardKey.keyG,
                meta: true, shift: true): () {
              if (_findOpen) _step(-1, page.body);
            },
            const SingleActivator(LogicalKeyboardKey.keyG,
                control: true, shift: true): () {
              if (_findOpen) _step(-1, page.body);
            },
            const SingleActivator(LogicalKeyboardKey.escape): () {
              if (_findOpen) _closeFind();
            },
            const SingleActivator(LogicalKeyboardKey.keyL,
                meta: true, shift: true): () => _toggleLock(context, loaded),
            const SingleActivator(LogicalKeyboardKey.keyL,
                control: true, shift: true): () => _toggleLock(context, loaded),
            const SingleActivator(LogicalKeyboardKey.backslash,
                meta: true, shift: true): () => setState(
                () => _rightRailHidden = !_rightRailHidden),
            const SingleActivator(LogicalKeyboardKey.backslash,
                control: true, shift: true): () => setState(
                () => _rightRailHidden = !_rightRailHidden),
            const SingleActivator(LogicalKeyboardKey.keyE, meta: true): () =>
                _toggleEditorMode(context, loaded),
            const SingleActivator(LogicalKeyboardKey.keyE, control: true): () =>
                _toggleEditorMode(context, loaded),
            const SingleActivator(LogicalKeyboardKey.keyP,
                meta: true, shift: true): () => setState(
                () => _propertiesOpen = !_propertiesOpen),
            const SingleActivator(LogicalKeyboardKey.keyP,
                control: true, shift: true): () => setState(
                () => _propertiesOpen = !_propertiesOpen),
            const SingleActivator(LogicalKeyboardKey.keyR,
                meta: true, alt: true): () =>
                _revealCurrentPage(context, loaded),
            const SingleActivator(LogicalKeyboardKey.keyR,
                control: true, alt: true): () =>
                _revealCurrentPage(context, loaded),
            const SingleActivator(LogicalKeyboardKey.keyW,
                meta: true, shift: true): () =>
                _toggleFullWidth(context, loaded),
            const SingleActivator(LogicalKeyboardKey.keyW,
                control: true, shift: true): () =>
                _toggleFullWidth(context, loaded),
            const SingleActivator(LogicalKeyboardKey.keyD,
                meta: true, shift: true): () =>
                _togglePin(context, loaded),
            const SingleActivator(LogicalKeyboardKey.keyD,
                control: true, shift: true): () =>
                _togglePin(context, loaded),
            // Cmd+Z / Ctrl+Z → undo last bloc-level edit. Native
            // TextField undo still wins inside text fields because the
            // field intercepts the keystroke before this Shortcuts
            // sees it; the binding fires when no field has focus.
            const SingleActivator(LogicalKeyboardKey.keyZ, meta: true): () =>
                context.read<EditorBloc>().add(const UndoEdit()),
            const SingleActivator(LogicalKeyboardKey.keyZ,
                control: true): () =>
                context.read<EditorBloc>().add(const UndoEdit()),
            const SingleActivator(LogicalKeyboardKey.keyZ,
                meta: true, shift: true): () =>
                context.read<EditorBloc>().add(const RedoEdit()),
            const SingleActivator(LogicalKeyboardKey.keyZ,
                control: true, shift: true): () =>
                context.read<EditorBloc>().add(const RedoEdit()),
          },
          child: Focus(
            autofocus: true,
            child: Column(
          children: [
            PageHeader(
              crumbs: crumbs,
              extra: Segment<EditorMode>(
                value: loaded.mode,
                onChanged: (m) => context.read<EditorBloc>().add(ToggleEditorMode(m)),
                options: const [
                  SegmentOption(value: EditorMode.rendered, label: 'Rendered', icon: 'eye'),
                  SegmentOption(value: EditorMode.source, label: 'Source', icon: 'code'),
                ],
              ),
              actions: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _DailyNoteNav(relativePath: page.relativePath),
                  _WikiBadge(page: page),
                  _ReminderBadge(page: page),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Tooltip(
                      message: loaded.dirty
                          ? 'Pending save — press ⌘S to flush now'
                          : 'Last saved ${DateTime.fromMillisecondsSinceEpoch(page.mtimeMs)}',
                      child: Text(
                        loaded.dirty
                            ? (loaded.saving ? 'saving…' : 'unsaved')
                            : 'saved ${_relativeMtime(page.mtimeMs)}',
                        style: mono(fontSize: 11, color: tokens.text3),
                      ),
                    ),
                  ),
                  _PinButton(pageUlid: page.ulid, onTap: () => _togglePin(context, loaded)),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _toggleLock(context, loaded),
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    tooltip: locked ? 'Unlock page' : 'Lock page',
                    icon: Icon(
                      locked ? Icons.lock_outline : Icons.lock_open,
                      size: 15,
                      color: locked ? tokens.accent : tokens.text3,
                    ),
                  ),
                  if (!mobile && !_propertiesOpen)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => setState(
                          () => _rightRailHidden = !_rightRailHidden),
                      padding: const EdgeInsets.all(4),
                      constraints:
                          const BoxConstraints(minWidth: 28, minHeight: 28),
                      tooltip: _rightRailHidden
                          ? 'Show outline (⌘⇧\\)'
                          : 'Hide outline (⌘⇧\\)',
                      icon: Icon(
                        _rightRailHidden
                            ? Icons.view_sidebar
                            : Icons.view_sidebar_outlined,
                        size: 16,
                        color: _rightRailHidden ? tokens.accent : tokens.text3,
                      ),
                    ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() => _propertiesOpen = !_propertiesOpen),
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    icon: QuillIcon('panel', size: 16, strokeWidth: 1.7,
                        color: _propertiesOpen ? tokens.accent : tokens.text3),
                  ),
                  Builder(
                    builder: (kebabCtx) => IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _showPageMenu(kebabCtx, loaded),
                      padding: const EdgeInsets.all(4),
                      constraints:
                          const BoxConstraints(minWidth: 28, minHeight: 28),
                      icon: QuillIcon('kebab-h',
                          size: 16, strokeWidth: 1.7, color: tokens.text3),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Builder(builder: (innerCtx) {
                      _jumpToAnchorIfNeeded(page.body);
                      return SingleChildScrollView(
                        controller: _scroll,
                        padding: EdgeInsets.symmetric(horizontal: mobile ? 12 : 64),
                        child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: _isFullWidth(page.frontmatter)
                                ? double.infinity
                                : QuillSpacing.editorMax,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              PageCoverBand(
                                coverValue: page.frontmatter.get('cover') is String
                                    ? page.frontmatter.get('cover') as String
                                    : null,
                                vaultRoot: context.read<VaultBloc>().state is VaultLoaded
                                    ? (context.read<VaultBloc>().state as VaultLoaded).rootPath
                                    : null,
                              ),
                              if (locked)
                                Container(
                                  margin: const EdgeInsets.only(top: 16, bottom: 4),
                                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                                  decoration: BoxDecoration(
                                    color: tokens.accentTint,
                                    borderRadius:
                                        const BorderRadius.all(Radius.circular(4)),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.lock_outline,
                                          size: 13, color: tokens.accent),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Locked — click the lock to enable editing',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: tokens.accent,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  GestureDetector(
                                    onTap: locked
                                        ? null
                                        : () => _pickIcon(context, loaded),
                                    child: MouseRegion(
                                      cursor: locked
                                          ? SystemMouseCursors.basic
                                          : SystemMouseCursors.click,
                                      child: Padding(
                                        padding:
                                            const EdgeInsets.only(top: 22, right: 12),
                                        child: PageIcon(
                                          iconValue: page.frontmatter.get('icon') is String
                                              ? page.frontmatter.get('icon') as String
                                              : null,
                                          size: 28,
                                          vaultRoot: context.read<VaultBloc>().state is VaultLoaded
                                              ? (context.read<VaultBloc>().state as VaultLoaded).rootPath
                                              : null,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(child: PageTitleField(title: page.title)),
                                ],
                              ),
                              FrontmatterCard(frontmatter: page.frontmatter),
                              if (loaded.mode == EditorMode.rendered) ...[
                                if (page.body.trim().isEmpty)
                                  _EmptyPageHint(locked: locked),
                                MarkdownRenderer(
                                  body: page.body,
                                  font: page.frontmatter.get('font')?.toString(),
                                  relativePath: page.relativePath,
                                  onBodyChange: locked
                                      ? null
                                      : (next) => context
                                          .read<EditorBloc>()
                                          .add(EditBody(next)),
                                  onBlockComment: locked
                                      ? null
                                      : (blockId) => _openBlockComments(
                                          context, page.ulid, blockId),
                                ),
                              ]
                              else
                                SourceView(
                                  key: ValueKey('source-${page.ulid}'),
                                  initialText: page.body,
                                ),
                              if (mobile) ...[
                                const SizedBox(height: 24),
                                OutlineRail(body: page.body, scroll: _scroll),
                                BacklinksRail(toUlid: page.ulid),
                              ],
                              const SizedBox(height: 20),
                              _PageFooter(
                                body: page.body,
                                goal: _readGoal(page.frontmatter.get('goal')),
                                createdAt:
                                    '${page.frontmatter.get('created_at') ?? ''}'.trim(),
                                createdBy:
                                    '${page.frontmatter.get('created_by') ?? ''}'.trim(),
                                lastEditedAt:
                                    '${page.frontmatter.get('last_edited_at') ?? ''}'.trim(),
                                lastEditedBy:
                                    '${page.frontmatter.get('last_edited_by') ?? ''}'.trim(),
                              ),
                              const SizedBox(height: 60),
                            ],
                          ),
                        ),
                      ),
                    );
                    }),
                  ),
                  if (_propertiesOpen)
                    PropertiesPanel(
                      page: page,
                      onClose: () => setState(() => _propertiesOpen = false),
                    )
                  else if (!mobile && !_rightRailHidden)
                    Container(
                      width: 248,
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                      decoration: BoxDecoration(
                        border: Border(left: BorderSide(color: tokens.divider, width: 0.5)),
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            OutlineRail(body: page.body, scroll: _scroll),
                            BacklinksRail(toUlid: page.ulid),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (_findOpen)
              _FindBar(
                controller: _findCtl,
                focus: _findFocus,
                matches: _findMatches.length,
                cursor:
                    _findMatches.isEmpty ? 0 : _findCursor + 1,
                onChanged: (_) => _recomputeFind(page.body),
                onNext: () => _step(1, page.body),
                onPrev: () => _step(-1, page.body),
                onClose: _closeFind,
              ),
          ],
        ),
      ),
    );
      },
    );
  }
}

/// Find-in-page bar shown at the bottom of the editor when Cmd+F is
/// invoked. Live-updates match count as the user types and offers
/// prev/next arrows that scroll the editor to the matching line.
class _FindBar extends StatelessWidget {
  const _FindBar({
    required this.controller,
    required this.focus,
    required this.matches,
    required this.cursor,
    required this.onChanged,
    required this.onPrev,
    required this.onNext,
    required this.onClose,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final int matches;
  final int cursor;
  final ValueChanged<String> onChanged;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border(top: BorderSide(color: tokens.divider, width: 0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.search, size: 14, color: tokens.text3),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focus,
              onChanged: onChanged,
              onSubmitted: (_) => onNext(),
              style: TextStyle(fontSize: 13, color: tokens.text),
              decoration: InputDecoration(
                isCollapsed: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 6),
                border: InputBorder.none,
                hintText: 'Find in page…',
                hintStyle: TextStyle(fontSize: 12.5, color: tokens.text3),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            matches == 0
                ? 'no matches'
                : '$cursor / $matches',
            style: mono(fontSize: 11.5, color: tokens.text3),
          ),
          const SizedBox(width: 6),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
            onPressed: matches == 0 ? null : onPrev,
            icon: Icon(Icons.keyboard_arrow_up,
                size: 16, color: tokens.text2),
            tooltip: 'Previous',
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
            onPressed: matches == 0 ? null : onNext,
            icon: Icon(Icons.keyboard_arrow_down,
                size: 16, color: tokens.text2),
            tooltip: 'Next',
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
            onPressed: onClose,
            icon: Icon(Icons.close, size: 14, color: tokens.text3),
            tooltip: 'Close (Esc)',
          ),
        ],
      ),
    );
  }
}

/// Friendly hint shown above the renderer when the page's body is
/// empty. Coaches the user toward source mode or slash menu without
/// taking screen real estate when the page has content.
class _EmptyPageHint extends StatelessWidget {
  const _EmptyPageHint({required this.locked});
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            locked ? 'This page is locked.' : 'Empty page',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: tokens.text2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            locked
                ? 'Click the lock icon (or press ⌘⇧L) to enable editing.'
                : 'Switch to Source (⌘E) to start typing, or use the '
                    'command palette (⌘K) to find what you need.',
            style: TextStyle(
              fontSize: 13,
              color: tokens.text3,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

/// Badge surfaced in the page header when the frontmatter carries
/// `wiki: true`. Reads `owners:` (list) + `verified:` (ISO date) and
/// pivots colour by how stale the verification is. Tooltip lists the
/// owners + verified-at line so editors can see who owns the page at
/// a glance.
/// Previous / next chevron pair shown only when the open page is a
/// daily note (path matches `Daily/YYYY-MM-DD.md`). Tap navigates to
/// the prev / next day's daily note, minting it if missing.
class _DailyNoteNav extends StatelessWidget {
  const _DailyNoteNav({required this.relativePath});
  final String relativePath;

  static final _re = RegExp(r'^Daily/(\d{4})-(\d{2})-(\d{2})\.md$');

  DateTime? _parseDate() {
    final m = _re.firstMatch(relativePath);
    if (m == null) return null;
    return DateTime.utc(
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
      int.parse(m.group(3)!),
    );
  }

  Future<void> _go(BuildContext context, DateTime target) async {
    final vaultBloc = context.read<VaultBloc>();
    final vault = vaultBloc.state;
    if (vault is! VaultLoaded) return;
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final result = await DailyNote.openTodaysNote(
        Directory(vault.rootPath),
        now: target,
      );
      if (!result.alreadyExisted) {
        vaultBloc.add(const ReindexVault());
      }
      router.go('/editor/${result.ulid}');
    } catch (e) {
      messenger?.showSnackBar(
          SnackBar(content: Text('Daily note nav failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _parseDate();
    if (d == null) return const SizedBox.shrink();
    final tokens = QuillTokens.of(context);
    final prev = d.subtract(const Duration(days: 1));
    final next = d.add(const Duration(days: 1));
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            tooltip:
                'Previous day · ${prev.toIso8601String().substring(0, 10)}',
            onPressed: () => _go(context, prev),
            icon: Icon(Icons.chevron_left,
                size: 16, color: tokens.text3),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            tooltip:
                'Next day · ${next.toIso8601String().substring(0, 10)}',
            onPressed: () => _go(context, next),
            icon: Icon(Icons.chevron_right,
                size: 16, color: tokens.text3),
          ),
        ],
      ),
    );
  }
}

/// Star icon shown in the editor's PageHeader actions row. Reads the
/// current vault's `favorites:` list to render the fill state, and
/// delegates the toggle back to the editor via [onTap]. Mirrors the
/// ⌘⇧D shortcut so users have a click target too.
class _PinButton extends StatelessWidget {
  const _PinButton({required this.pageUlid, required this.onTap});
  final String pageUlid;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    final state = context.watch<VaultBloc>().state;
    final pinned = state is VaultLoaded &&
        state.workspace.favorites.contains(pageUlid);
    return IconButton(
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      tooltip: pinned ? 'Unpin from favorites (⌘⇧D)' : 'Pin to favorites (⌘⇧D)',
      onPressed: onTap,
      icon: Icon(
        pinned ? Icons.star : Icons.star_outline,
        size: 15,
        color: pinned ? tokens.accent : tokens.text3,
      ),
    );
  }
}

class _WikiBadge extends StatelessWidget {
  const _WikiBadge({required this.page});
  final dynamic page;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    final wiki = page.frontmatter.get('wiki');
    final isWiki = wiki == true || '$wiki'.trim() == 'true';
    if (!isWiki) return const SizedBox.shrink();
    final owners = _readList(page.frontmatter.get('owners'));
    final verifiedRaw = page.frontmatter.get('verified');
    final verified = verifiedRaw == null
        ? null
        : DateTime.tryParse('$verifiedRaw'.trim());
    final days = verified == null
        ? null
        : DateTime.now().difference(verified).inDays;
    final stale = days != null && days > 90;
    final fresh = days != null && days <= 14;
    final fg = stale
        ? const Color(0xFFCB5A4F)
        : fresh
            ? tokens.accent
            : tokens.text2;
    final bg = stale
        ? const Color(0xFFCB5A4F).withValues(alpha: 0.16)
        : fresh
            ? tokens.accent.withValues(alpha: 0.16)
            : tokens.surface2;
    final label = verified == null
        ? 'wiki'
        : stale
            ? 'wiki · stale'
            : 'wiki';
    final tooltip = [
      if (owners.isNotEmpty) 'Owners: ${owners.join(", ")}',
      if (verified != null)
        'Verified ${verified.toIso8601String().substring(0, 10)}'
            '${days == 0 ? " (today)" : days == 1 ? " (1 day ago)" : " ($days days ago)"}',
    ].join('\n');
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Tooltip(
        message: tooltip.isEmpty ? 'Wiki page' : tooltip,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.all(Radius.circular(4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.menu_book_outlined, size: 11, color: fg),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(fontSize: 11, color: fg)),
            ],
          ),
        ),
      ),
    );
  }

  static List<String> _readList(dynamic raw) {
    if (raw == null) return const [];
    if (raw is List) {
      return raw.map((e) => '$e'.trim()).where((s) => s.isNotEmpty).toList();
    }
    final s = '$raw'.trim();
    if (s.isEmpty) return const [];
    return [s];
  }
}

/// Badge surfaced in the page header when the frontmatter carries a
/// `reminder:` field. Reads as ISO YYYY-MM-DD (optional time), shows a
/// bell + relative time pill that flips red when overdue.
class _ReminderBadge extends StatelessWidget {
  const _ReminderBadge({required this.page});
  final dynamic page;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    final raw = page.frontmatter.get('reminder');
    if (raw == null) return const SizedBox.shrink();
    final s = '$raw'.trim();
    if (s.isEmpty) return const SizedBox.shrink();
    final target = DateTime.tryParse(s);
    if (target == null) return const SizedBox.shrink();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final t = DateTime(target.year, target.month, target.day);
    final days = t.difference(today).inDays;
    final overdue = days < 0;
    final today0 = days == 0;
    final label = today0
        ? 'today'
        : days == 1
            ? 'tomorrow'
            : days > 0
                ? 'in ${days}d'
                : '${-days}d ago';
    final fg = overdue
        ? const Color(0xFFCB5A4F)
        : today0
            ? tokens.accent
            : tokens.text2;
    final bg = overdue
        ? const Color(0xFFCB5A4F).withValues(alpha: 0.16)
        : today0
            ? tokens.accent.withValues(alpha: 0.16)
            : tokens.surface2;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.all(Radius.circular(4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_active_outlined, size: 11, color: fg),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 11, color: fg)),
          ],
        ),
      ),
    );
  }
}

/// Parse a frontmatter `goal:` value into a positive int word count.
/// Returns null when the value is missing, non-numeric, or zero —
/// the footer then skips the progress bar entirely.
int? _readGoal(Object? raw) {
  if (raw == null) return null;
  final n = raw is num ? raw.toInt() : int.tryParse('$raw'.trim());
  if (n == null || n <= 0) return null;
  return n;
}

/// Tiny dim row at the bottom of the editor: word count, character
/// count, reading-time estimate. When the page's frontmatter declares
/// a `goal:` word count, also renders a progress bar + `<words>/<goal>`
/// pill (accent fill, green when met). Hidden if the body is empty so
/// empty pages don't show "0 words · 0 chars · 1 min".
class _PageFooter extends StatelessWidget {
  const _PageFooter({
    required this.body,
    this.goal,
    this.createdAt = '',
    this.createdBy = '',
    this.lastEditedAt = '',
    this.lastEditedBy = '',
  });

  final String body;

  /// Optional word-count goal from frontmatter `goal:`. When non-null,
  /// the footer surfaces progress against this target.
  final int? goal;

  /// `created_at:` from frontmatter (any format the user types) —
  /// surfaced below the word-count line so users can see when they
  /// started a page without opening the properties panel.
  final String createdAt;

  /// `created_by:` author name. Empty when unset.
  final String createdBy;

  /// `last_edited_at:` ISO date. Hidden when equal to [createdAt] so
  /// "untouched since creation" pages don't render redundant lines.
  final String lastEditedAt;

  /// `last_edited_by:` author name. Hidden when equal to [createdBy]
  /// so single-author pages don't render two redundant lines.
  final String lastEditedBy;

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    final stripped = body.replaceAll(RegExp(r'```[\s\S]*?```'), ' ');
    final words = stripped
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .length;
    if (words == 0) return const SizedBox.shrink();
    final chars = body.length;
    // 220wpm is a common silent-reading midpoint.
    final mins = (words / 220).ceil().clamp(1, 999);
    final g = goal;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('$words words',
                  style: mono(fontSize: 11, color: tokens.text3)),
              Text('  ·  ', style: TextStyle(fontSize: 11, color: tokens.text3)),
              Text('$chars chars',
                  style: mono(fontSize: 11, color: tokens.text3)),
              Text('  ·  ', style: TextStyle(fontSize: 11, color: tokens.text3)),
              Text('~$mins min read',
                  style: mono(fontSize: 11, color: tokens.text3)),
              if (g != null) ...[
                Text('  ·  ',
                    style: TextStyle(fontSize: 11, color: tokens.text3)),
                Text('$words / $g goal',
                    style: mono(
                        fontSize: 11,
                        color: words >= g
                            ? const Color(0xFF5A8F6E)
                            : tokens.text3)),
              ],
            ],
          ),
          if (g != null) ...[
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: ClipRRect(
                borderRadius: const BorderRadius.all(Radius.circular(2)),
                child: LinearProgressIndicator(
                  value: (words / g).clamp(0.0, 1.0),
                  minHeight: 4,
                  backgroundColor: tokens.surface2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    words >= g
                        ? const Color(0xFF5A8F6E)
                        : tokens.accent,
                  ),
                ),
              ),
            ),
          ],
          if (createdAt.isNotEmpty || createdBy.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              [
                if (createdAt.isNotEmpty) 'Created: $createdAt',
                if (createdBy.isNotEmpty) 'by $createdBy',
              ].join(' '),
              style: mono(fontSize: 11, color: tokens.text3),
            ),
          ],
          if ((lastEditedAt.isNotEmpty && lastEditedAt != createdAt) ||
              (lastEditedBy.isNotEmpty && lastEditedBy != createdBy)) ...[
            const SizedBox(height: 2),
            Text(
              [
                if (lastEditedAt.isNotEmpty && lastEditedAt != createdAt)
                  'Last edited: $lastEditedAt',
                if (lastEditedBy.isNotEmpty && lastEditedBy != createdBy)
                  'by $lastEditedBy',
              ].join(' '),
              style: mono(fontSize: 11, color: tokens.text3),
            ),
          ],
        ],
      ),
    );
  }
}

