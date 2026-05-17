import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/db/quill_database.dart' hide Page;
import '../../../../core/markdown/yaml_scalar.dart';
import '../../../../core/network/backend_endpoint.dart';
import '../../../../core/paths.dart';
import '../../../../core/platform/reveal.dart';
import '../../../../core/util/throttle.dart';
import '../../../reminders/presentation/bloc/reminders_bloc.dart';
import '../../../reminders/presentation/bloc/reminders_event.dart';
import '../../../forms/domain/repositories/forms_repository.dart';
import '../../../forms/presentation/widgets/form_submissions_dialog.dart';
import '../../../sync/domain/usecases/build_public_password_entries.dart';
import '../../../sync/presentation/bloc/sync_bloc.dart';
import '../../../sync/presentation/bloc/sync_event.dart';
import '../../../sync/presentation/bloc/sync_state.dart';
import '../../../sync/presentation/default_editor_sync_binder_factory.dart';
import '../../../sync/presentation/editor_sync_ws_mount.dart';
import '../../../sync/presentation/widgets/pull_reconcile_dialog.dart';
import '../controllers/find_in_page_controller.dart';
import '../../../../shared/theme/quill_tokens.dart';
import '../../../../shared/theme/tokens.dart';
import '../../../../shared/widgets/emoji_picker.dart';
import '../../../../shared/widgets/page_icon.dart';
import '../../../../shared/widgets/quill_icon.dart';
import '../../../../shared/widgets/quill_overlays.dart';
import '../../../../shared/widgets/responsive_layout.dart';
import '../../../../shared/widgets/segment.dart';
import '../../../vault/data/daily_note.dart';
import '../../../vault/data/html_exporter.dart';
import '../../../vault/data/indexer.dart';
import '../../../vault/data/pdf_exporter.dart';
import '../../../vault/domain/entities/frontmatter.dart';
import '../../../vault/domain/entities/frontmatter_entry.dart';
import '../../../vault/domain/entities/page.dart' as vault_page;
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
import '../widgets/markdown_renderer.dart';
import '../widgets/mobile_editor_toolbar.dart';
import '../widgets/page_history_dialog.dart';
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
      // Multi-bridge: presentation-layer wiring that keeps the
      // EditorBloc independent of RemindersBloc and SyncBloc (CA-06).
      child: MultiBlocListener(
        listeners: [
          // B4 slice 3 (M1228): `reminder:` frontmatter → RemindersBloc.
          BlocListener<EditorBloc, EditorState>(
            listenWhen: (prev, next) {
              if (prev is! EditorLoaded || next is! EditorLoaded) return false;
              return prev.page.frontmatter.get('reminder') !=
                  next.page.frontmatter.get('reminder');
            },
            listener: (context, state) {
              if (state is! EditorLoaded) return;
              final reminders = context.read<RemindersBloc>();
              final value = state.page.frontmatter.get('reminder');
              final raw = value?.toString().trim() ?? '';
              if (raw.isEmpty) {
                reminders.add(CancelReminder(state.page.ulid));
                return;
              }
              final when = DateTime.tryParse(raw);
              if (when == null) return;
              reminders.add(
                ScheduleReminder(
                  ulid: state.page.ulid,
                  title: state.page.title,
                  when: when,
                ),
              );
            },
          ),
          // E18 (M1320): after a successful save (saving: true → false),
          // push the new body to the v2 backend if the user is authed.
          // Fire-and-forget — SyncBloc's sequential() transformer keeps
          // concurrent pushes ordered, and a 401 trips the bloc's
          // stale-token reset so the user gets a Login prompt in
          // Settings → Sync.
          BlocListener<EditorBloc, EditorState>(
            listenWhen: (prev, next) {
              if (prev is! EditorLoaded || next is! EditorLoaded) return false;
              // Detect "save just completed": was saving, no longer saving.
              return prev.saving && !next.saving;
            },
            listener: (context, state) {
              if (state is! EditorLoaded) return;
              final sync = context.read<SyncBloc>();
              if (!sync.state.isAuthed) return;
              sync.add(
                SyncPushFileRequested(
                  relpath: state.page.relativePath,
                  body: state.page.body,
                ),
              );
            },
          ),
          // E18 toast surface: when a push lands a conflict, show the
          // user a non-blocking warning. listenWhen so we only fire on
          // the transition INTO conflict, not on every emission while
          // the state is sticky.
          BlocListener<SyncBloc, SyncState>(
            listenWhen: (prev, next) =>
                next.lastError == 'conflict' &&
                prev.lastError != 'conflict' &&
                next.lastConflict != null,
            listener: (context, state) {
              final conflict = state.lastConflict;
              if (conflict == null) return;
              // E25 — give the conflict toast a one-tap "Pull" action
              // that fetches the server copy. The E24 reconcile dialog
              // then opens automatically via the lastFetched bridge
              // below, letting the user choose server-vs-local.
              final sync = context.read<SyncBloc>();
              context.toastWarn(
                'Sync conflict on ${conflict.relpath}',
                sub: 'server sha ${conflict.sha256.substring(0, 8)}…',
                subMono: true,
                action: 'Pull',
                onAction: () => sync.add(
                  SyncFetchFileRequested(relpath: conflict.relpath),
                ),
              );
            },
          ),
          // E24 (M1327): lastFetched transition null → non-null opens
          // the diff/replace dialog so the user can choose between the
          // server body and their local body. The dialog dispatches
          // EditBody(server) on "Use server version" or just clears
          // lastFetched on "Keep local".
          BlocListener<SyncBloc, SyncState>(
            listenWhen: (prev, next) =>
                prev.lastFetched == null && next.lastFetched != null,
            listener: (context, state) {
              final fetched = state.lastFetched;
              if (fetched == null) return;
              final editor = context.read<EditorBloc>();
              final editorState = editor.state;
              final localBody = editorState is EditorLoaded
                  ? editorState.page.body
                  : '';
              final sync = context.read<SyncBloc>();
              showDialog<void>(
                context: context,
                builder: (_) => PullReconcileDialog(
                  serverBody: fetched,
                  localBody: localBody,
                  onUseServer: () {
                    editor.add(EditBody(fetched.body));
                    sync.add(const SyncFetchCleared());
                    context.toastSuccess('Pulled server version',
                        sub: fetched.summary.relpath);
                  },
                  onKeepLocal: () =>
                      sync.add(const SyncFetchCleared()),
                ),
              );
            },
          ),
        ],
        child: _EditorBody(anchor: anchor),
      ),
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
/// Compose a full word/char/paragraph breakdown for the PageFooter's
/// word-count tooltip. The basic numbers (words/chars/min-read) are
/// already on screen — this adds paragraphs, sentences, and chars-
/// without-spaces so power users can verify a draft against an
/// external word-count tool.
String _wordCountTooltip(String body, int words, int chars, int mins) {
  final stripped = body.replaceAll(RegExp(r'```[\s\S]*?```'), ' ');
  final charsNoSpace = stripped.replaceAll(RegExp(r'\s'), '').length;
  final paragraphs = stripped
      .split(RegExp(r'\n\s*\n'))
      .where((s) => s.trim().isNotEmpty)
      .length;
  final sentences =
      stripped.split(RegExp(r'[.!?]+\s')).where((s) => s.trim().isNotEmpty).length;
  String pl(int n, String s, String p) => '$n ${n == 1 ? s : p}';
  return '${pl(words, 'word', 'words')}  ·  ${pl(chars, 'char', 'chars')} (incl. spaces)  ·  ${pl(charsNoSpace, 'char', 'chars')} (no spaces)\n'
      '${pl(paragraphs, 'paragraph', 'paragraphs')}  ·  ${pl(sentences, 'sentence', 'sentences')}\n'
      '~${pl(mins, 'min', 'mins')} read at 220 wpm';
}

/// Hover-tooltip helper for the PageFooter date lines. Tries to
/// parse [iso] as a full DateTime; falls back to "no date" when the
/// value is empty, and to the raw input when parsing fails (date-only
/// strings like `2026-05-15` already parse cleanly, so this mostly
/// catches user-typed garbage gracefully).
String _dateAgoTooltip(String iso) {
  if (iso.trim().isEmpty) return 'No date set';
  final parsed = DateTime.tryParse(iso);
  if (parsed == null) return iso;
  final pretty = parsed
      .toIso8601String()
      .replaceFirst('T', ' ')
      .split('.')
      .first;
  final delta = DateTime.now().difference(parsed);
  if (delta.inDays < 1 && delta.inDays > -1) return 'today  ·  $pretty';
  final days = delta.inDays;
  if (days > 0) return '${days == 1 ? "1 day" : "$days days"} ago  ·  $pretty';
  return 'in ${-days == 1 ? "1 day" : "${-days} days"}  ·  $pretty';
}

String _slugify(String s) {
  final lower = s.toLowerCase();
  final cleaned = lower.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  return cleaned.replaceAll(RegExp(r'(^-+)|(-+$)'), '');
}

bool _isFullWidth(Frontmatter frontmatter) {
  final v = frontmatter.get('full_width');
  if (v == true) return true;
  return '${v ?? ''}'.toLowerCase() == 'true';
}

class _EditorBodyState extends State<_EditorBody> {
  bool _propertiesOpen = false;
  bool _rightRailHidden = false;
  final ScrollController _scroll = ScrollController();
  bool _anchorJumped = false;

  // Find-in-page state (M85). Extracted to FindInPageController
  // (H3a) — five-field cluster (_findOpen / _findCtl / _findFocus
  // / _findMatches / _findCursor) plus five-method API now lives
  // in the controller; this State owns one instance and bridges
  // its notifications into setState so the BlocConsumer rebuilds
  // when the find bar opens/closes or the cursor advances.
  late final FindInPageController _find =
      FindInPageController(scroll: _scroll)..addListener(_onFindChange);

  void _onFindChange() {
    if (mounted) setState(() {});
  }

  // H2.5: throttles "Multiplayer disconnected" toasts so a flaky
  // network can't spam the user — at most one toast per 8-second
  // window per editor mount.
  final Throttle<void> _connErrorToastThrottle =
      Throttle<void>(const Duration(seconds: 8));

  @override
  void dispose() {
    _scroll.dispose();
    _find
      ..removeListener(_onFindChange)
      ..dispose();
    super.dispose();
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

  /// Shared guard for actions that mutate frontmatter. Returns false +
  /// info-toasts if the page is locked, so the caller can early-return
  /// before opening pickers / dialogs that would silently no-op when
  /// the bloc swallows the dispatch (editor_bloc.dart:261/290).
  bool _requireUnlocked(BuildContext context, EditorLoaded loaded) {
    if (!EditorBloc.isLocked(loaded)) return true;
    context.toastInfo('Page is locked',
        sub: 'Unlock the page (⌘⇧L) to edit it');
    return false;
  }

  Future<void> _pickIcon(BuildContext context, EditorLoaded loaded) async {
    if (!_requireUnlocked(context, loaded)) return;
    final bloc = context.read<EditorBloc>();
    final picked = await pickEmoji(context);
    if (picked == null) return; // dismissed without choosing
    final fm = loaded.page.frontmatter;
    final existing = fm.find('icon');
    if (picked.isEmpty) {
      // "Clear" — remove the icon entry entirely.
      if (existing != null) {
        bloc.add(const RemoveFrontmatterField('icon'));
        if (context.mounted) context.toastSuccess('Page icon cleared');
      }
      return;
    }
    final iconRaw = yamlSafeScalar(picked);
    if (existing != null && existing.rawScalar.trim() == iconRaw) {
      if (context.mounted) {
        context.toastInfo('Page icon already $picked');
      }
      return;
    }
    if (existing == null) {
      bloc.add(AddFrontmatterField(FrontmatterEntry(
        key: 'icon',
        rawScalar: iconRaw,
        type: FrontmatterType.text,
        value: picked,
      )));
    } else {
      bloc.add(EditFrontmatterField(
        'icon',
        existing.copyWith(rawScalar: iconRaw, value: picked),
      ));
    }
    if (context.mounted) context.toastSuccess('Page icon: $picked');
  }

  Future<void> _showPageMenu(BuildContext context, EditorLoaded loaded) async {
    final ulid = loaded.page.ulid;
    final action = await showQuillMenu<String>(
      context: context,
      position: quillMenuAnchor(context),
      width: 232,
      items: [
        const QuillMenuItem(icon: 'link', label: 'Copy ULID', value: 'copy-ulid'),
        const QuillMenuItem(icon: 'link', label: 'Copy [[link]]', value: 'copy-link'),
        const QuillMenuItem(icon: 'folder', label: 'Copy file path', value: 'copy-path'),
        const QuillMenuItem(icon: 'reveal', label: 'Reveal in Finder', hint: '⌘⌥R', value: 'reveal'),
        const QuillMenuItem(icon: 'note', label: 'Duplicate page', value: 'duplicate'),
        const QuillMenuItem(icon: 'edit', label: 'Rename file…', value: 'rename'),
        const QuillMenuItem(icon: 'folder', label: 'Move to folder…', value: 'move'),
        const QuillMenuItem(icon: 'clock', label: 'Page history…', value: 'history'),
        QuillMenuItem.separator<String>(),
        const QuillMenuItem(icon: 'note', label: 'Copy page body', value: 'copy-body'),
        const QuillMenuItem(icon: 'note', label: 'Copy as plain text', value: 'copy-plain'),
        const QuillMenuItem(icon: 'code', label: 'Copy as JSON', value: 'copy-json'),
        const QuillMenuItem(icon: 'export', label: 'Export as .md…', value: 'export-md'),
        const QuillMenuItem(icon: 'export', label: 'Export as .html…', value: 'export-html'),
        const QuillMenuItem(icon: 'export', label: 'Print page…', value: 'print-page'),
        const QuillMenuItem(icon: 'export', label: 'Share…', value: 'share'),
        QuillMenuItem.separator<String>(),
        const QuillMenuItem(icon: 'tag', label: 'Add tags…', value: 'add-tags'),
        const QuillMenuItem(icon: 'edit', label: 'Set page font…', value: 'set-font'),
        const QuillMenuItem(icon: 'clock', label: 'Set reminder…', value: 'set-reminder'),
        const QuillMenuItem(icon: 'clock', label: 'Snooze reminder…', value: 'snooze-reminder'),
        const QuillMenuItem(icon: 'clock', label: 'Clear reminder', value: 'clear-reminder'),
        const QuillMenuItem(icon: 'hash', label: 'Set word count goal…', value: 'set-goal'),
        QuillMenuItem.separator<String>(),
        // E17 — v2 backend public sharing toggle. Single entry swaps
        // label based on current frontmatter (Publish ↔ Unpublish).
        if (_isPublic(loaded))
          const QuillMenuItem(
              icon: 'link', label: 'Unpublish', value: 'unpublish')
        else ...[
          const QuillMenuItem(
              icon: 'link', label: 'Publish & copy link', value: 'publish'),
          // E44 — password-protected variant. Prompts for a password
          // and stamps `public: true` + `public_password: <bcrypt>`
          // into frontmatter; backend E43 gate then demands the
          // unlock cookie before serving the rendered HTML.
          const QuillMenuItem(
              icon: 'lock',
              label: 'Publish with password…',
              value: 'publish-password'),
        ],
        // E23 — pull the latest server copy for conflict reconciliation.
        // Only meaningful when logged in; entry is always present but
        // emits a non-blocking error toast when offline.
        const QuillMenuItem(
            icon: 'download', label: 'Pull from server', value: 'pull'),
        // E51 — view form submissions for this page, when it carries a
        // `forms:` frontmatter field. Only shown when the page is
        // actually form-bearing — otherwise the menu would always
        // resolve to a 403 / not_owner.
        if (_hasForms(loaded)) ...[
          // E57 — author-facing share helper: copy the public
          // /forms/<ulid> URL to clipboard so the author can paste
          // it anywhere (Slack, email, embed). Visitors fill out
          // the rendered HTML (E56b) and their submissions land in
          // the per-page list reached via "View form submissions →"
          // below.
          const QuillMenuItem(
              icon: 'link',
              label: 'Copy form link',
              value: 'copy-form-link'),
          const QuillMenuItem(
              icon: 'inbox',
              label: 'View form submissions →',
              value: 'view-form-submissions'),
        ],
        QuillMenuItem.separator<String>(),
        const QuillMenuItem(icon: 'trash', label: 'Move to trash', danger: true, value: 'trash'),
        const QuillMenuItem(icon: 'sync', label: 'Reindex vault', value: 'reindex'),
      ],
    );
    if (action == null || !context.mounted) return;
    switch (action) {
      case 'copy-ulid':
        await Clipboard.setData(ClipboardData(text: ulid));
        if (context.mounted) context.toastSuccess('Copied $ulid', subMono: true);
      case 'copy-form-link':
        // E57: build the public form URL via the shared helper so a
        // future E14+ override doesn't drift between consumers.
        final url = publicFormUrl(
          backendBaseUrl: kBackendHttpBaseUrl,
          pageUlid: ulid,
        );
        await Clipboard.setData(ClipboardData(text: url));
        if (context.mounted) {
          context.toastSuccess('Copied form link', sub: url, subMono: true);
        }
      case 'copy-link':
        await Clipboard.setData(ClipboardData(text: '[[$ulid]]'));
        if (context.mounted) context.toastSuccess('Copied [[$ulid]]', subMono: true);
      case 'copy-path':
        final vault = context.read<VaultBloc>().state;
        final path = vault is VaultLoaded
            ? '${vault.rootPath}/${loaded.page.relativePath}'
            : loaded.page.relativePath;
        await Clipboard.setData(ClipboardData(text: path));
        if (context.mounted) context.toastSuccess('Copied path', sub: path, subMono: true);
      case 'reveal':
        final vault = context.read<VaultBloc>().state;
        if (vault is VaultLoaded) {
          final path = '${vault.rootPath}/${loaded.page.relativePath}';
          final ok = await Reveal.show(path);
          if (!ok && context.mounted) {
            context.toastError('Could not reveal', sub: path, subMono: true);
          }
        }
      case 'history':
        await _showPageHistory(context, loaded);
      case 'copy-body':
        await Clipboard.setData(ClipboardData(text: loaded.page.body));
        final n = loaded.page.body.length;
        if (context.mounted) {
          context.toastSuccess(
              'Copied $n ${n == 1 ? 'char' : 'chars'} to clipboard');
        }
      case 'copy-plain':
        final plain = stripMarkdown(loaded.page.body);
        await Clipboard.setData(ClipboardData(text: plain));
        if (context.mounted) {
          context.toastSuccess(
              'Copied ${plain.length} ${plain.length == 1 ? 'char' : 'chars'} as plain text');
        }
      case 'copy-json':
        final fmMap = <String, Object?>{};
        for (final e in loaded.page.frontmatter.entries) {
          fmMap[e.key] = e.value;
        }
        final payload = jsonEncode({
          'ulid': loaded.page.ulid,
          'relativePath': loaded.page.relativePath,
          'frontmatter': fmMap,
          'body': loaded.page.body,
        });
        await Clipboard.setData(ClipboardData(text: payload));
        if (context.mounted) {
          context.toastSuccess(
              'Copied ${payload.length} ${payload.length == 1 ? 'char' : 'chars'} JSON');
        }
      case 'export-md':
        await _exportPageAsMarkdown(context, loaded);
      case 'export-html':
        await _exportPageAsHtml(context, loaded);
      case 'print-page':
        await _printPage(context, loaded);
      case 'share':
        await _sharePage(context, loaded);
      case 'add-tags':
        await _addTags(context, loaded);
      case 'set-font':
        await _setFont(context, loaded);
      case 'set-reminder':
        await _setReminder(context, loaded);
      case 'snooze-reminder':
        await _snoozeReminder(context, loaded);
      case 'clear-reminder':
        if (!_requireUnlocked(context, loaded)) return;
        final fm = loaded.page.frontmatter;
        final existing = fm.find('reminder');
        if (existing == null) {
          context.toastInfo('No reminder set on this page.');
        } else {
          final was = existing.rawScalar.trim();
          context
              .read<EditorBloc>()
              .add(const RemoveFrontmatterField('reminder'));
          context.toastSuccess(was.isEmpty
              ? 'Reminder cleared.'
              : 'Reminder cleared (was $was).');
        }
      case 'set-goal':
        await _setWordGoal(context, loaded);
      case 'publish':
        await _publishPage(context, loaded);
      case 'publish-password':
        await _publishPageWithPassword(context, loaded);
      case 'unpublish':
        await _unpublishPage(context, loaded);
      case 'pull':
        final sync = context.read<SyncBloc>();
        if (!sync.state.isAuthed) {
          context.toastWarn('Not logged in',
              sub: 'Open Settings → Sync to sign in.');
          return;
        }
        sync.add(SyncFetchFileRequested(relpath: loaded.page.relativePath));
        context.toastInfo('Pulling latest from server…');
      case 'view-form-submissions':
        await _viewFormSubmissions(context, loaded);
      case 'rename':
        await _renameFile(context, loaded);
      case 'move':
        await _moveToFolder(context, loaded);
      case 'duplicate':
        final router = GoRouter.of(context);
        final scope = context;
        final sourceTitle = loaded.page.title;
        context.read<VaultBloc>().add(DuplicatePage(
              ulid,
              onCreated: (newUlid) {
                if (scope.mounted) {
                  scope.toastSuccess(
                      sourceTitle.isEmpty
                          ? 'Page duplicated'
                          : 'Duplicated "$sourceTitle"',
                      sub: 'New ULID: $newUlid',
                      subMono: true);
                }
                router.go('/editor/$newUlid');
              },
            ));
      case 'trash':
        final now = DateTime.now();
        final bucket =
            '${now.year}-${now.month.toString().padLeft(2, '0')}';
        final confirmed = await showQuillConfirm(
          context,
          title: 'Move to trash?',
          sub:
              'The .md file moves to .trash/$bucket/${loaded.page.relativePath}. '
              'You can restore it from the Trash dialog later.',
          icon: 'trash',
          confirmLabel: 'Move to trash',
          danger: true,
        );
        if (!confirmed || !context.mounted) return;
        final title = loaded.page.title;
        final relpath = loaded.page.relativePath;
        context.read<VaultBloc>().add(MoveToTrash(ulid));
        // E22: when the user is logged into the v2 backend, mirror the
        // local trash move to the server. The server returns 204 (or
        // 404 if it never knew about the file); both count as success
        // and drop the relpath from knownShas so a future push doesn't
        // ship a stale If-Match for a tombstoned row.
        final sync = context.read<SyncBloc>();
        if (sync.state.isAuthed) {
          sync.add(SyncDeleteFileRequested(relpath: relpath));
        }
        if (context.mounted) {
          context.toastSuccess('Moved to trash',
              sub: title.isEmpty ? relpath : title);
        }
        GoRouter.of(context).go('/home');
      case 'reindex':
        if (!context.mounted) return;
        context.read<VaultBloc>().add(const ReindexVault());
        context.toastInfo('Reindexing vault…');
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
      if (context.mounted) context.toastError('Print failed', sub: '$e');
    }
  }

  Future<void> _renameFile(
      BuildContext context, EditorLoaded loaded) async {
    final current = loaded.page.relativePath;
    final slash = current.lastIndexOf('/');
    final basename = current.substring(slash + 1);
    final base = basename.endsWith('.md')
        ? basename.substring(0, basename.length - 3)
        : basename;
    final picked = await showQuillPrompt(
      context,
      title: 'Rename file',
      icon: 'edit',
      label: 'New name',
      hint: 'ULID is unchanged — wikilinks survive the rename.',
      placeholder: 'new-name (without .md)',
      initial: base,
      confirmLabel: 'Rename',
    );
    if (picked == null || picked.isEmpty) return;
    if (!context.mounted) return;
    // Mirror _safeFileName's transformations so the toast matches the
    // actual filename on disk (slashes/quotes/etc. become "-"; trailing
    // .md is stripped).
    var preview = picked
        .replaceAll(RegExp(r'[\\/<>:"|?*]+'), '-')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (preview.toLowerCase().endsWith('.md')) {
      preview = preview.substring(0, preview.length - 3).trim();
    }
    if (preview.isEmpty) preview = 'Untitled';
    if (preview == base) {
      context.toastInfo('Filename unchanged');
      return;
    }
    context.read<VaultBloc>().add(
        RenamePage(ulid: loaded.page.ulid, newBasename: picked));
    context.toastSuccess('Renamed to $preview.md');
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
    final hasOtherFolder = sorted.any((f) => f != currentFolder);
    if (currentFolder == '' && !hasOtherFolder) {
      context.toastInfo('No folders to move to',
          sub: 'Create a folder in the sidebar first');
      return;
    }
    final picked = await showQuillChoice<String>(
      context,
      title: 'Move to folder',
      icon: 'folder',
      options: [
        if (currentFolder != '')
          const QuillChoiceOption<String>(
            value: '',
            label: '(vault root)',
            icon: 'home',
          ),
        for (final f in sorted)
          if (f != currentFolder)
            QuillChoiceOption<String>(
              value: f,
              label: f,
              icon: 'folder',
            ),
      ],
    );
    if (picked == null) return;
    if (!context.mounted) return;
    context.read<VaultBloc>().add(
        MovePage(ulid: loaded.page.ulid, targetFolder: picked));
    final pageLabel = loaded.page.title.isEmpty
        ? loaded.page.relativePath
        : loaded.page.title;
    context.toastSuccess(
        picked.isEmpty ? 'Moved to vault root' : 'Moved to $picked',
        sub: pageLabel);
  }

  Future<void> _setFont(
      BuildContext context, EditorLoaded loaded) async {
    if (!_requireUnlocked(context, loaded)) return;
    final fm = loaded.page.frontmatter;
    final existing = fm.find('font');
    final picked = await showQuillChoice<String>(
      context,
      title: 'Page font',
      icon: 'edit',
      options: const [
        QuillChoiceOption<String>(
          value: 'sans',
          label: 'Sans-serif (default)',
        ),
        QuillChoiceOption<String>(
          value: 'serif',
          label: 'Serif (Georgia)',
        ),
        QuillChoiceOption<String>(
          value: 'mono',
          label: 'Monospace (JetBrainsMono)',
        ),
      ],
    );
    if (picked == null || !context.mounted) return;
    // No-op detection: 'sans' with no frontmatter entry is already the
    // default; any other choice that matches the existing rawScalar is
    // also a no-op. Skip the bloc dispatch + misleading success toast.
    if (picked == 'sans' && existing == null) {
      context.toastInfo('Page font already set to default');
      return;
    }
    if (existing != null && existing.rawScalar.trim() == picked) {
      context.toastInfo('Page font already set to $picked');
      return;
    }
    final bloc = context.read<EditorBloc>();
    final label = switch (picked) {
      'sans' => 'sans-serif (default)',
      'serif' => 'serif',
      'mono' => 'monospace',
      _ => picked,
    };
    if (picked == 'sans') {
      // Default — strip the frontmatter entry entirely.
      if (existing != null) {
        bloc.add(const RemoveFrontmatterField('font'));
      }
      context.toastSuccess('Page font: $label');
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
    context.toastSuccess('Page font: $label');
  }

  Future<void> _addTags(
      BuildContext context, EditorLoaded loaded) async {
    if (!_requireUnlocked(context, loaded)) return;
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
    final hint = currentTags.isEmpty
        ? 'Comma-separated. New tags are merged with current.'
        : 'Current: ${currentTags.join(', ')} · new tags are merged.';
    final result = await showQuillPrompt(
      context,
      title: 'Add tags',
      icon: 'tag',
      label: 'Tags',
      hint: hint,
      placeholder: 'tag1, tag2',
      confirmLabel: 'Add',
    );
    if (result == null) return;
    // Quote-aware split (M783) so a user typing
    // `"high, priority", urgent` lands as two tags not three.
    final added = parseMultiValueInput(result);
    if (added.isEmpty) return;
    // Merge + dedupe, preserving order: current first, then new.
    // Case-insensitive match — re-adding "draft" when "Draft" is
    // already on the page is a no-op rather than double-listing the
    // same tag with two casings (M786). The kept entry keeps its
    // original casing.
    final merged = <String>[...currentTags];
    final mergedLower = {for (final t in currentTags) t.toLowerCase()};
    final actuallyNew = <String>[];
    for (final t in added) {
      final lower = t.toLowerCase();
      if (!mergedLower.contains(lower)) {
        merged.add(t);
        mergedLower.add(lower);
        actuallyNew.add(t);
      }
    }
    if (!context.mounted) return;
    if (actuallyNew.isEmpty) {
      // Every tag the user entered was already on the page — skip the
      // no-op bloc dispatch and inform via toast.
      context.toastInfo('All tags already on this page');
      return;
    }
    final bloc = context.read<EditorBloc>();
    // Quote each element when it would otherwise break the YAML flow
    // list — `,`, `[`, `]`, `:`, `#`, leading/trailing whitespace.
    // Without this, a tag like "high, priority" would split into two
    // entries when re-parsed.
    final raw =
        '[${merged.map(yamlFlowItem).join(', ')}]';
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
    context.toastSuccess(
        'Added ${actuallyNew.length} ${actuallyNew.length == 1 ? "tag" : "tags"}',
        sub: actuallyNew.join(', '));
  }

  Future<void> _setWordGoal(
      BuildContext context, EditorLoaded loaded) async {
    if (!_requireUnlocked(context, loaded)) return;
    final fm = loaded.page.frontmatter;
    final existing = fm.find('goal');
    final initial = existing?.rawScalar ?? '';
    final picked = await showQuillPrompt(
      context,
      title: 'Set word count goal',
      icon: 'hash',
      label: 'Goal',
      hint: 'Empty to clear. The footer will show progress.',
      placeholder: 'e.g. 500',
      initial: initial,
      confirmLabel: 'Save',
      mono: true,
    );
    if (picked == null || !context.mounted) return;
    final trimmed = picked.trim();
    final bloc = context.read<EditorBloc>();
    if (trimmed.isEmpty) {
      if (existing != null) {
        final was = existing.rawScalar.trim();
        bloc.add(const RemoveFrontmatterField('goal'));
        context.toastSuccess(was.isEmpty
            ? 'Word count goal cleared'
            : 'Word count goal cleared (was $was)');
      }
      return;
    }
    final n = int.tryParse(trimmed);
    if (n == null || n < 1) {
      context.toastError('Goal must be a positive whole number');
      return;
    }
    if (existing != null && existing.rawScalar.trim() == '$n') {
      context.toastInfo(
          'Word count goal already $n ${n == 1 ? "word" : "words"}');
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
    context.toastSuccess('Word count goal: $n ${n == 1 ? "word" : "words"}');
  }

  Future<void> _snoozeReminder(
      BuildContext context, EditorLoaded loaded) async {
    if (!_requireUnlocked(context, loaded)) return;
    final fm = loaded.page.frontmatter;
    final existing = fm.find('reminder');
    if (existing == null) {
      context.toastInfo('No reminder set. Use "Set reminder…" to start one.');
      return;
    }
    final base =
        DateTime.tryParse(existing.rawScalar) ?? DateTime.now();
    final baseDay = DateTime(base.year, base.month, base.day);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // If the existing reminder is in the past, snooze should push from
    // today rather than the past — otherwise '+ 7 days' on a 2025-01-01
    // reminder produces 2025-01-08, still in the past. Notion / Apple
    // Mail semantics: snooze always lands in the future.
    final start = baseDay.isBefore(today) ? today : baseDay;
    final picked = await showQuillChoice<int>(
      context,
      title: 'Snooze reminder',
      icon: 'clock',
      options: const [
        QuillChoiceOption<int>(value: 1, label: '+ 1 day', icon: 'clock'),
        QuillChoiceOption<int>(value: 3, label: '+ 3 days', icon: 'clock'),
        QuillChoiceOption<int>(value: 7, label: '+ 1 week', icon: 'clock'),
        QuillChoiceOption<int>(
            value: 30, label: '+ 1 month (30d)', icon: 'clock'),
      ],
    );
    if (picked == null || !context.mounted) return;
    final next = start.add(Duration(days: picked));
    final iso =
        '${next.year.toString().padLeft(4, '0')}-${next.month.toString().padLeft(2, '0')}-${next.day.toString().padLeft(2, '0')}';
    final bloc = context.read<EditorBloc>();
    bloc.add(EditFrontmatterField(
      'reminder',
      existing.copyWith(rawScalar: iso, value: iso),
    ));
    final days = next.difference(today).inDays;
    context.toastSuccess(
        'Snoozed reminder to $iso (in $days ${days == 1 ? "day" : "days"})');
  }

  Future<void> _setReminder(
      BuildContext context, EditorLoaded loaded) async {
    if (!_requireUnlocked(context, loaded)) return;
    final fm = loaded.page.frontmatter;
    final existing = fm.find('reminder');
    final now = DateTime.now();
    DateTime initial = DateTime(now.year, now.month, now.day);
    if (existing != null) {
      final parsed = DateTime.tryParse(existing.rawScalar);
      if (parsed != null) initial = parsed;
    }
    final picked = await showQuillDatePicker(
      context,
      initial: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null) return;
    if (!context.mounted) return;
    final iso =
        '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    if (existing != null && existing.rawScalar.trim() == iso) {
      context.toastInfo('Reminder already set for $iso');
      return;
    }
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
    final today = DateTime(now.year, now.month, now.day);
    final tPicked = DateTime(picked.year, picked.month, picked.day);
    final days = tPicked.difference(today).inDays;
    final relative = days == 0
        ? 'today'
        : days == 1
            ? 'tomorrow'
            : days > 0
                ? 'in $days ${days == 1 ? "day" : "days"}'
                : '${-days} ${(-days) == 1 ? "day" : "days"} ago';
    context.toastSuccess('Reminder set for $iso ($relative)');
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
    try {
      final html = HtmlExporter.renderStandalonePage(
        title: loaded.page.title,
        body: loaded.page.body,
      );
      await File(picked).writeAsString(html);
      if (context.mounted) {
        context.toastSuccess('Exported HTML', sub: picked, subMono: true);
      }
    } catch (e) {
      if (context.mounted) context.toastError('Export failed', sub: '$e');
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
    try {
      await source.copy(picked);
      if (context.mounted) {
        context.toastSuccess('Exported markdown',
            sub: picked, subMono: true);
      }
    } catch (e) {
      if (context.mounted) context.toastError('Export failed', sub: '$e');
    }
  }

  Future<void> _revealCurrentPage(
      BuildContext context, EditorLoaded loaded) async {
    final vault = context.read<VaultBloc>().state;
    if (vault is! VaultLoaded) return;
    final path = '${vault.rootPath}/${loaded.page.relativePath}';
    final ok = await Reveal.show(path);
    if (!ok && context.mounted) {
      context.toastError('Could not reveal', sub: path, subMono: true);
    }
  }

  /// True iff the page's frontmatter has `public: true` (or `yes`) per
  /// the M1316 server-side probe contract. The kebab swaps Publish ↔
  /// Unpublish based on this.
  bool _isPublic(EditorLoaded loaded) {
    final v = loaded.page.frontmatter.get('public');
    if (v == true) return true;
    final s = '$v'.toLowerCase();
    return s == 'true' || s == 'yes';
  }

  /// E51 — true when the page declares a `forms:` field with a
  /// non-empty value. Mirrors the backend's `FrontmatterProbe.hasForms`
  /// rule so the kebab entry matches what the server would accept.
  bool _hasForms(EditorLoaded loaded) {
    final v = loaded.page.frontmatter.get('forms');
    if (v == null) return false;
    final s = '$v'.trim();
    return s.isNotEmpty;
  }

  Future<void> _viewFormSubmissions(
      BuildContext context, EditorLoaded loaded) async {
    final ulid = loaded.page.ulid;
    if (ulid.isEmpty) {
      context.toastError('Cannot list submissions',
          sub: 'page has no ULID');
      return;
    }
    final sync = context.read<SyncBloc>();
    final token = sync.state.token;
    if (token == null || !sync.state.isAuthed) {
      context.toastWarn('Not logged in',
          sub: 'Sign in to view submissions.');
      return;
    }
    final repo = context.read<FormsRepository>();
    await showDialog<void>(
      context: context,
      builder: (_) => FormSubmissionsDialog(
        ulid: ulid,
        load: () => repo.listSubmissions(token: token, ulid: ulid),
      ),
    );
  }

  /// Hardcoded share-URL base — matches `HttpSyncRepository` in
  /// `app.dart`. A future settings entry lets users override.
  static const _publicShareBase = 'http://localhost:8080/public';

  Future<void> _publishPage(BuildContext context, EditorLoaded loaded) async {
    final ulid = loaded.page.ulid;
    if (ulid.isEmpty) {
      context.toastError('Cannot publish', sub: 'page has no ULID');
      return;
    }
    final bloc = context.read<EditorBloc>();
    final fm = loaded.page.frontmatter;
    final existing = fm.find('public');
    const entry = FrontmatterEntry(
      key: 'public',
      rawScalar: 'true',
      type: FrontmatterType.checkbox,
      value: true,
    );
    if (existing == null) {
      bloc.add(const AddFrontmatterField(entry));
    } else {
      bloc.add(const EditFrontmatterField('public', entry));
    }
    final url = '$_publicShareBase/$ulid';
    await Clipboard.setData(ClipboardData(text: url));
    if (context.mounted) {
      context.toastSuccess('Published', sub: url, subMono: true);
    }
  }

  Future<void> _unpublishPage(
      BuildContext context, EditorLoaded loaded) async {
    final bloc = context.read<EditorBloc>();
    if (loaded.page.frontmatter.find('public') == null) return;
    bloc.add(const RemoveFrontmatterField('public'));
    // E44: when unpublishing, also drop any lingering password hash so
    // a re-Publish without a password doesn't accidentally inherit the
    // old gate.
    if (loaded.page.frontmatter.find('public_password') != null) {
      bloc.add(const RemoveFrontmatterField('public_password'));
    }
    if (context.mounted) context.toastSuccess('Unpublished');
  }

  /// E44 — prompts for a password, bcrypt-hashes it (synchronously,
  /// pure-Dart `bcrypt`), and stamps `public: true` +
  /// `public_password: "<hash>"` into the page's frontmatter. Save flow
  /// then routes the new body through SyncBloc's push pipeline; the
  /// backend's E43 probe stores the hash and gates `/public/<ulid>`.
  Future<void> _publishPageWithPassword(
      BuildContext context, EditorLoaded loaded) async {
    final ulid = loaded.page.ulid;
    if (ulid.isEmpty) {
      context.toastError('Cannot publish', sub: 'page has no ULID');
      return;
    }
    final password = await _promptForPassword(context);
    if (password == null || password.isEmpty || !context.mounted) return;
    final entries = buildPublicPasswordEntries(password);
    final bloc = context.read<EditorBloc>();
    final fm = loaded.page.frontmatter;
    if (fm.find('public') == null) {
      bloc.add(AddFrontmatterField(entries.publicFlag));
    } else {
      bloc.add(EditFrontmatterField('public', entries.publicFlag));
    }
    if (fm.find('public_password') == null) {
      bloc.add(AddFrontmatterField(entries.passwordHash));
    } else {
      bloc.add(EditFrontmatterField('public_password', entries.passwordHash));
    }
    final url = '$_publicShareBase/$ulid';
    await Clipboard.setData(ClipboardData(text: url));
    if (context.mounted) {
      context.toastSuccess(
        'Published (password-protected)',
        sub: url,
        subMono: true,
      );
    }
  }

  /// Modal text field prompt for E44 password publishing. Returns
  /// null on dismiss / cancel, the entered string otherwise.
  Future<String?> _promptForPassword(BuildContext context) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Set page password'),
          content: TextField(
            controller: controller,
            autofocus: true,
            obscureText: true,
            decoration: const InputDecoration(
              hintText: 'Password',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (v) => Navigator.of(dialogContext).pop(v),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text),
              child: const Text('Publish'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return result;
  }

  /// C3 of the 1m-loop plan: route the current page through the OS share
  /// sheet via `package:share_plus`. Tries `shareXFiles` first (works
  /// natively on iOS / macOS / Android — the share sheet handles AirDrop,
  /// Messages, email attachments, etc.). On platforms where file-sharing
  /// isn't supported (notably plain Linux), falls back to `share` with
  /// the page body as plain text so the entry isn't a dead end.
  Future<void> _sharePage(BuildContext context, EditorLoaded loaded) async {
    final vault = context.read<VaultBloc>().state;
    if (vault is! VaultLoaded) return;
    final relPath = loaded.page.relativePath;
    final path = '${vault.rootPath}/$relPath';
    final source = File(path);
    if (!await source.exists()) {
      if (context.mounted) {
        context.toastError('Cannot share', sub: 'File not found', subMono: true);
      }
      return;
    }
    try {
      // share_plus 12.x: `Share.shareXFiles` accepts a list of XFile + an
      // optional subject. The share sheet UI is platform-native.
      final params = ShareParams(
        files: [XFile(path, name: loaded.page.title)],
        subject: loaded.page.title,
      );
      await SharePlus.instance.share(params);
    } catch (e) {
      // Fallback: try plain-text share of the body so the entry isn't a
      // total dead end on platforms without file-share support.
      try {
        await SharePlus.instance.share(
          ShareParams(text: loaded.page.body, subject: loaded.page.title),
        );
      } catch (_) {
        if (context.mounted) {
          context.toastError('Share failed', sub: '$e');
        }
      }
    }
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
    if (loaded.dirty) {
      bloc.add(const SaveNow());
      context.toastInfo('Saving…');
    } else {
      context.toastInfo('Already saved');
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
    final label = loaded.page.title.isEmpty
        ? loaded.page.relativePath
        : loaded.page.title;
    context.toastSuccess(wasLocked ? 'Page unlocked' : 'Page locked',
        sub: label);
  }

  void _togglePin(BuildContext context, EditorLoaded loaded) {
    final vault = context.read<VaultBloc>();
    final ulid = loaded.page.ulid;
    if (ulid.isEmpty) return;
    final state = vault.state;
    final wasPinned =
        state is VaultLoaded && state.workspace.favorites.contains(ulid);
    vault.add(ToggleFavorite(ulid));
    final label = loaded.page.title.isEmpty
        ? loaded.page.relativePath
        : loaded.page.title;
    context.toastSuccess(
        wasPinned ? 'Unpinned from favorites' : 'Pinned to favorites',
        sub: label);
  }

  void _toggleFullWidth(BuildContext context, EditorLoaded loaded) {
    if (!_requireUnlocked(context, loaded)) return;
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
    final label = loaded.page.title.isEmpty
        ? loaded.page.relativePath
        : loaded.page.title;
    context.toastSuccess(
        wasFull ? 'Page width: default' : 'Page width: full',
        sub: label);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = QuillTokens.of(context);
    return BlocConsumer<EditorBloc, EditorState>(
      // Save-failures emit a transient EditorError before re-emitting
      // the loaded state. Snackbar the error and let the user keep
      // editing — the debounced save will retry on the next edit.
      listenWhen: (prev, next) => next is EditorError,
      listener: (context, state) {
        if (state is! EditorError) return;
        context.toastError(state.message);
      },
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_outlined,
                      size: 28, color: tokens.danger),
                  const SizedBox(height: 10),
                  Text(
                    'Could not open page',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: tokens.text2),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    state.message,
                    style: TextStyle(
                        color: tokens.text3, fontSize: 13, height: 1.5),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => context.go('/home'),
                        child: const Text('Back to home'),
                      ),
                      const SizedBox(width: 4),
                      TextButton(
                        onPressed: () =>
                            context.read<VaultBloc>().add(const ReindexVault()),
                        child: const Text('Reindex vault'),
                      ),
                    ],
                  ),
                ],
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
            const SingleActivator(LogicalKeyboardKey.keyF, meta: true):
                _find.open,
            const SingleActivator(LogicalKeyboardKey.keyF, control: true):
                _find.open,
            const SingleActivator(LogicalKeyboardKey.keyS, meta: true): () =>
                _flushSave(context, loaded),
            const SingleActivator(LogicalKeyboardKey.keyS, control: true): () =>
                _flushSave(context, loaded),
            const SingleActivator(LogicalKeyboardKey.keyG, meta: true): () {
              if (_find.isOpen) _find.step(1, page.body);
            },
            const SingleActivator(LogicalKeyboardKey.keyG, control: true): () {
              if (_find.isOpen) _find.step(1, page.body);
            },
            const SingleActivator(LogicalKeyboardKey.keyG,
                meta: true, shift: true): () {
              if (_find.isOpen) _find.step(-1, page.body);
            },
            const SingleActivator(LogicalKeyboardKey.keyG,
                control: true, shift: true): () {
              if (_find.isOpen) _find.step(-1, page.body);
            },
            const SingleActivator(LogicalKeyboardKey.escape): () {
              if (_find.isOpen) _find.close();
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
            // F2 — universal "rename" shortcut across file managers,
            // IDEs, and OS-level dialogs. Opens the same rename prompt
            // as the editor kebab → Rename file….
            const SingleActivator(LogicalKeyboardKey.f2): () =>
                _renameFile(context, loaded),
            // ⌘P — print current page. ⌘⇧P remains the properties-panel
            // toggle; the two don't collide because the modifier set
            // differs.
            const SingleActivator(LogicalKeyboardKey.keyP, meta: true): () =>
                _printPage(context, loaded),
            const SingleActivator(LogicalKeyboardKey.keyP, control: true): () =>
                _printPage(context, loaded),
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
          // H2.4c (BL-12 cleanup): narrow rebuild scope to the two
          // SyncState fields the mount actually cares about. Without
          // buildWhen, every SyncState emission (heartbeats,
          // reconnect attempts, lastError churn) would rebuild the
          // entire editor body subtree.
          child: BlocBuilder<SyncBloc, SyncState>(
            buildWhen: (prev, next) =>
                prev.isAuthed != next.isAuthed || prev.token != next.token,
            builder: (context, syncState) => EditorSyncWsMount(
              ulid: page.ulid,
              isPublished: _isPublic(loaded),
              isAuthed: syncState.isAuthed,
              token: syncState.token,
              initialBody: page.body,
              // H2.4c: wsUrl mirrors app.dart's HTTP base URL.
              // E57 promoted both to lib/core/network/backend_endpoint.dart
              // as the single source of truth — when E14+ exposes a
              // settings-page override, both constants will read
              // from the same stored value.
              // H2.4d-i: factory closure extracted to
              // sync/presentation so this presentation file no
              // longer imports from sync/data/ directly (resolves
              // the CA-04 cleanup deferred from M1385).
              binderFactory:
                  defaultEditorSyncBinderFactory(wsUrl: kBackendWsBaseUrl),
              // H2.4d-iii: inbound peer updates apply via the
              // EditorBloc.EditBody event, which mutates the loaded
              // state's body. The renderer / SourceView re-render
              // from that state — same path a local edit takes,
              // minus the onBodyChange / _onChanged fan-out, so no
              // loop (see M1391 rationale at the dispatch sites).
              onRemoteDoc: (doc) {
                context.read<EditorBloc>().add(EditBody(doc.body));
              },
              // H2.4d-iii: surface transport drops as a transient
              // toast. SyncConnectionLostException covers the
              // "connection established then lost" case; the
              // EditorSyncWsMount will auto-reattach on the next
              // SyncBloc/published-flag reconcile so users don't
              // need to manually retry.
              //
              // H2.5: throttled at 8s/window so a flaky network
              // can't spam toasts during a reconnect burst.
              onConnectionError: (_) {
                _connErrorToastThrottle.run(() {
                  context.toastError(
                    'Multiplayer disconnected',
                    sub: 'Reconnecting…',
                  );
                });
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
                  SegmentOption(
                      value: EditorMode.rendered,
                      label: 'Rendered',
                      icon: 'eye',
                      tooltip: 'Rendered view (⌘E)'),
                  SegmentOption(
                      value: EditorMode.source,
                      label: 'Source',
                      icon: 'code',
                      tooltip: 'Source markdown (⌘E)'),
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
                          ? (loaded.saving
                              ? 'Saving now…'
                              : 'Pending save — press ⌘S to flush now')
                          : 'Last saved ${DateTime.fromMillisecondsSinceEpoch(page.mtimeMs).toIso8601String().replaceFirst("T", " · ").substring(0, 18)}',
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
                    tooltip: _propertiesOpen
                        ? 'Hide properties panel (⌘⇧P)'
                        : 'Show properties panel (⌘⇧P)',
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
                      tooltip: 'Page menu',
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
                                coverValue: switch (page.frontmatter.get('cover')) {
                                  final String s => s,
                                  _ => null,
                                },
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
                                      child: Tooltip(
                                        message: locked
                                            ? 'Page is locked'
                                            : 'Change icon',
                                        waitDuration: const Duration(
                                            milliseconds: 500),
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                              top: 22, right: 12),
                                          child: PageIcon(
                                            iconValue: switch (page.frontmatter.get('icon')) {
                                              final String s => s,
                                              _ => null,
                                            },
                                            size: 28,
                                            vaultRoot: context.read<VaultBloc>().state is VaultLoaded
                                                ? (context.read<VaultBloc>().state as VaultLoaded).rootPath
                                                : null,
                                          ),
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
                                      : (next) {
                                          context
                                              .read<EditorBloc>()
                                              .add(EditBody(next));
                                          // H2.4d-ii: fan out local
                                          // edits to peers. Silent
                                          // no-op when the editor is
                                          // mounted outside an active
                                          // multiplayer session
                                          // (unauthed or unpublished).
                                          //
                                          // Why dispatch-site, not a
                                          // BlocListener on EditorBloc.
                                          // body? BL-11 (M1390 audit)
                                          // suggested the listener
                                          // shape; the call-site
                                          // placement is intentional
                                          // because we want to push
                                          // ONLY user-originated edits.
                                          // EditBody is also dispatched
                                          // by Pull-from-server (line
                                          // 196) and by inbound peer
                                          // updates (H2.4d-iii) — a
                                          // listener would re-broadcast
                                          // those and create a loop.
                                          EditorSyncWsScope.maybeOf(context)
                                              ?.pushLocalUpdate(next);
                                        },
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
                                  locked: locked,
                                  pageUlid: page.ulid,
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
            if (_find.isOpen)
              _FindBar(
                controller: _find.queryController,
                focus: _find.focusNode,
                matches: _find.matches.length,
                cursor:
                    _find.matches.isEmpty ? 0 : _find.cursor + 1,
                onChanged: (_) => _find.recompute(page.body),
                onNext: () => _find.step(1, page.body),
                onPrev: () => _find.step(-1, page.body),
                onClose: _find.close,
              ),
            // G2.5 — mobile sticky bottom-bar surfaces the most-used
            // kebab actions on narrow widths. The kebab itself stays
            // in the page header so the "More…" button on the bar
            // just re-uses _showPageMenu through a Builder for the
            // right anchor.
            if (mobile)
              Builder(
                builder: (toolbarCtx) => MobileEditorToolbar(
                  onSetReminder: () => _setReminder(toolbarCtx, loaded),
                  onPublish: () => _isPublic(loaded)
                      ? _unpublishPage(toolbarCtx, loaded)
                      : _publishPage(toolbarCtx, loaded),
                  onViewFormSubmissions: () =>
                      _viewFormSubmissions(toolbarCtx, loaded),
                  onMore: () => _showPageMenu(toolbarCtx, loaded),
                  hasForms: _hasForms(loaded),
                  isPublished: _isPublic(loaded),
                ),
              ),
          ],
        ),
      ),
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
          Tooltip(
            message: matches == 0
                ? 'No matches in this page'
                : 'Match $cursor of ${matches == 1 ? "1 match" : "$matches matches"}',
            waitDuration: const Duration(milliseconds: 500),
            child: Text(
              matches == 0
                  ? 'no matches'
                  : '$cursor / $matches',
              style: mono(fontSize: 11.5, color: tokens.text3),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
            onPressed: matches == 0 ? null : onPrev,
            icon: Icon(Icons.keyboard_arrow_up,
                size: 16, color: tokens.text2),
            tooltip: 'Previous match (⌘⇧G)',
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
            onPressed: matches == 0 ? null : onNext,
            icon: Icon(Icons.keyboard_arrow_down,
                size: 16, color: tokens.text2),
            tooltip: 'Next match (⌘G)',
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
          Icon(
            locked ? Icons.lock_outline : Icons.edit_outlined,
            size: 24,
            color: locked ? tokens.accent : tokens.text3,
          ),
          const SizedBox(height: 8),
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
      if (context.mounted) context.toastError('Daily note nav failed', sub: '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _parseDate();
    if (d == null) return const SizedBox.shrink();
    final tokens = QuillTokens.of(context);
    final prev = d.subtract(const Duration(days: 1));
    final next = d.add(const Duration(days: 1));
    final today = DateTime.now().toUtc();
    final todayUtc = DateTime.utc(today.year, today.month, today.day);
    final isToday = d.year == todayUtc.year &&
        d.month == todayUtc.month &&
        d.day == todayUtc.day;
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
          if (!isToday)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Tooltip(
                message:
                    'Jump to today · ${todayUtc.toIso8601String().substring(0, 10)}',
                waitDuration: const Duration(milliseconds: 500),
                child: TextButton(
                  onPressed: () => _go(context, todayUtc),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 0),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    foregroundColor: tokens.text2,
                    textStyle: const TextStyle(fontSize: 11.5),
                  ),
                  child: const Text('Today'),
                ),
              ),
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
  final vault_page.Page page;

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
        ? tokens.danger
        : fresh
            ? tokens.accent
            : tokens.text2;
    final bg = stale
        ? tokens.dangerTint
        : fresh
            ? tokens.accent.withValues(alpha: 0.16)
            : tokens.surface2;
    final label = verified == null
        ? 'wiki'
        : stale
            ? 'wiki · stale'
            : 'wiki';
    final tooltip = [
      if (owners.isNotEmpty)
        '${owners.length == 1 ? "Owner" : "Owners"}: ${owners.join(", ")}',
      if (verified != null)
        'Verified ${verified.toIso8601String().substring(0, 10)}${days == 0 ? " (today)" : days == 1 ? " (1 day ago)" : " ($days days ago)"}',
      if (stale)
        'Stale — re-verify (verified: <today> in frontmatter).',
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
  final vault_page.Page page;

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
        ? tokens.danger
        : today0
            ? tokens.accent
            : tokens.text2;
    final bg = overdue
        ? tokens.dangerTint
        : today0
            ? tokens.accent.withValues(alpha: 0.16)
            : tokens.surface2;
    final iso = t.toIso8601String().substring(0, 10);
    final relative = overdue
        ? '${-days} ${(-days) == 1 ? "day" : "days"} overdue'
        : today0
            ? 'today'
            : days == 1
                ? 'tomorrow'
                : 'in $days ${days == 1 ? "day" : "days"}';
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Tooltip(
        message: 'Reminder · $iso ($relative)',
        waitDuration: const Duration(milliseconds: 400),
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
          Tooltip(
            message: _wordCountTooltip(body, words, chars, mins),
            child: Row(
              children: [
                Text('$words ${words == 1 ? 'word' : 'words'}',
                    style: mono(fontSize: 11, color: tokens.text3)),
                Text('  ·  ', style: TextStyle(fontSize: 11, color: tokens.text3)),
                Text('$chars ${chars == 1 ? 'char' : 'chars'}',
                    style: mono(fontSize: 11, color: tokens.text3)),
                Text('  ·  ', style: TextStyle(fontSize: 11, color: tokens.text3)),
                Text('~$mins ${mins == 1 ? 'min' : 'mins'} read',
                    style: mono(fontSize: 11, color: tokens.text3)),
                if (g != null) ...[
                  Text('  ·  ',
                      style: TextStyle(fontSize: 11, color: tokens.text3)),
                  Text('$words / $g goal',
                      style: mono(
                          fontSize: 11,
                          color: words >= g
                              ? tokens.success
                              : tokens.text3)),
                ],
              ],
            ),
          ),
          if (g != null) ...[
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Tooltip(
                message: words >= g
                    ? 'Goal reached — $words / $g words'
                    : '${(words * 100 / g).clamp(0, 100).round()}% of $g-word goal',
                child: ClipRRect(
                  borderRadius: const BorderRadius.all(Radius.circular(2)),
                  child: LinearProgressIndicator(
                    value: (words / g).clamp(0.0, 1.0),
                    minHeight: 4,
                    backgroundColor: tokens.surface2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      words >= g
                          ? tokens.success
                          : tokens.accent,
                    ),
                  ),
                ),
              ),
            ),
          ],
          if (createdAt.isNotEmpty || createdBy.isNotEmpty) ...[
            const SizedBox(height: 4),
            Tooltip(
              message: _dateAgoTooltip(createdAt),
              child: Text(
                createdAt.isNotEmpty
                    ? (createdBy.isNotEmpty
                        ? 'Created: $createdAt by $createdBy'
                        : 'Created: $createdAt')
                    : 'Created by $createdBy',
                style: mono(fontSize: 11, color: tokens.text3),
              ),
            ),
          ],
          if ((lastEditedAt.isNotEmpty && lastEditedAt != createdAt) ||
              (lastEditedBy.isNotEmpty && lastEditedBy != createdBy)) ...[
            const SizedBox(height: 2),
            Builder(builder: (_) {
              final showAt =
                  lastEditedAt.isNotEmpty && lastEditedAt != createdAt;
              final showBy =
                  lastEditedBy.isNotEmpty && lastEditedBy != createdBy;
              final label = showAt
                  ? (showBy
                      ? 'Last edited: $lastEditedAt by $lastEditedBy'
                      : 'Last edited: $lastEditedAt')
                  : 'Last edited by $lastEditedBy';
              return Tooltip(
                message: _dateAgoTooltip(lastEditedAt),
                child: Text(
                  label,
                  style: mono(fontSize: 11, color: tokens.text3),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
