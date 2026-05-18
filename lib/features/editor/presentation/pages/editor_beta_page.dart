import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:super_editor/super_editor.dart';

import '../../../../core/db/quill_database.dart' hide Page;
import '../../../../core/markdown/super_editor_serializer.dart';
import '../../../../core/markdown/wikilink_parser.dart';
import '../../../../core/network/backend_endpoint.dart';
import '../../../../core/platform/reveal.dart';
import '../../../../core/routing/routes.dart';
import '../../../vault/data/indexer.dart';
import '../../../vault/domain/repositories/vault_repository.dart';
import '../../../sync/presentation/bloc/sync_bloc.dart';
import '../../../sync/presentation/bloc/sync_event.dart';
import '../../../sync/presentation/bloc/sync_state.dart';
import '../../../vault/presentation/bloc/vault_bloc.dart';
import '../../../vault/presentation/bloc/vault_event.dart';
import '../../../vault/presentation/bloc/vault_state.dart';
import '../../../../core/ui/anchor_rect.dart';
import '../../../../core/ui/anchor_rect_x.dart';
import '../../domain/attachment_writer.dart';
import '../../domain/block_selection_gesture.dart';
import '../../../vault/domain/entities/frontmatter_entry.dart';
import '../../../vault/domain/sanitized_basename.dart';
import '../../../vault/domain/vault_absolute_path.dart';
import '../../domain/document_search.dart';
import '../../domain/editor_beta_app_bar_actions.dart';
import '../../../forms/domain/repositories/forms_repository.dart';
import '../../../forms/presentation/widgets/form_submissions_dialog.dart';
import '../../domain/copy_labels.dart';
import '../../domain/has_forms_frontmatter.dart';
import '../../../vault/data/html_exporter.dart';
import '../../domain/page_font.dart';
import '../../domain/safe_export_filename.dart';
import '../../domain/word_goal.dart';
import '../../domain/page_json_payload.dart';
import '../../domain/reminder_date.dart';
import '../../domain/strip_markdown.dart';
import '../../domain/find_in_page_navigation.dart';
import '../bloc/editor_bloc.dart';
import '../bloc/editor_event.dart';
import '../bloc/editor_state.dart';
import '../../domain/slash_entries.dart';
import '../../domain/slash_entry_block_type.dart';
import '../controllers/block_conversion_keyboard_action.dart';
import '../controllers/block_delete_keyboard_action.dart';
import '../controllers/block_duplicate_keyboard_action.dart';
import '../controllers/block_reorder_keyboard_action.dart';
import '../controllers/bold_autoformat_reaction.dart';
import '../controllers/find_in_page_keyboard_action.dart';
import '../controllers/heading_conversion_keyboard_action.dart';
import '../controllers/highlight_autoformat_reaction.dart';
import '../controllers/inline_code_autoformat_reaction.dart';
import '../controllers/italic_autoformat_reaction.dart';
import '../controllers/slash_trigger_session.dart';
import '../controllers/strike_autoformat_reaction.dart';
import '../controllers/subscript_autoformat_reaction.dart';
import '../controllers/super_editor_caret.dart';
import '../controllers/superscript_autoformat_reaction.dart';
import '../cubit/block_selection_cubit.dart';
import '../cubit/slash_menu_cubit.dart';
import '../../../../shared/widgets/quill_date_picker.dart';
import '../../../../shared/widgets/quill_modal.dart';
import '../widgets/block_selection_overlay.dart';
import '../widgets/editor_beta_app_bar_icons.dart';
import '../widgets/find_bar.dart';
import '../widgets/page_history_dialog.dart';
import '../widgets/slash_menu_overlay.dart';

/// Beta WYSIWYG editor route powered by `super_editor` (Phase D / D1 slice 23
/// of the 1m-loop plan). Wired in parallel to the existing `/editor/<ulid>`
/// source-mode route so users can opt into the new editor at
/// `/editor-beta/<ulid>` without losing the stable rendered + source view.
///
/// Slice 23 ships the route shell + a working markdown → serializer →
/// SuperEditor mount path. The block / inline parity for the 22 serializer
/// slices (91 test cases as of M1283) renders inside super_editor's default
/// stylesheet. Subsequent slices wire interactions (slash menu, drag,
/// multi-select, M234-M268 keyboard shortcuts); cutover at slices 28-30
/// flips the default editor route once beta proves itself.
class EditorBetaPage extends StatelessWidget {
  const EditorBetaPage({super.key, required this.ulid});

  final String ulid;

  @override
  Widget build(BuildContext context) {
    // D23 slice 2a (M1523): SlashMenuCubit is provided here as a sibling
    // of the EditorBloc so the upcoming super_editor keyboard listener
    // can `context.read<SlashMenuCubit>()` to drive `/` menu state — same
    // pattern source_view's existing wiring uses inside the source-mode
    // editor. Listener + overlay rendering land in subsequent sub-slices.
    return MultiBlocProvider(
      key: ValueKey('beta-$ulid'),
      providers: [
        BlocProvider<EditorBloc>(
          create: (context) {
            final bloc = EditorBloc(
              repo: context.read<VaultRepository>(),
              indexer: context.read<Indexer>(),
              db: context.read<QuillDatabase>(),
            );
            final vault = context.read<VaultBloc>().state;
            if (vault is VaultLoaded) {
              bloc.setVaultRoot(Directory(vault.rootPath));
            }
            bloc.add(OpenEditor(ulid));
            return bloc;
          },
        ),
        BlocProvider<SlashMenuCubit>(
          create: (_) => SlashMenuCubit(),
        ),
        // D25 slice 4a (M1600): Notion-style multi-block selection state.
        // The cubit is empty by default and lives alongside super_editor's
        // text-caret DocumentSelection — they don't conflict.
        BlocProvider<BlockSelectionCubit>(
          create: (_) => BlockSelectionCubit(),
        ),
      ],
      child: const _BetaEditorBody(),
    );
  }
}

class _BetaEditorBody extends StatelessWidget {
  const _BetaEditorBody();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EditorBloc, EditorState>(
      builder: (context, state) {
        if (state is EditorLoading || state is EditorIdle) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (state is EditorError) {
          return Scaffold(
            body: Center(child: Text(state.message)),
          );
        }
        if (state is EditorLoaded) {
          return _BetaEditorShell(
            ulid: state.page.ulid,
            relativePath: state.page.relativePath,
            title: state.page.title,
            body: state.page.body,
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}

class _BetaEditorShell extends StatefulWidget {
  const _BetaEditorShell({
    required this.ulid,
    required this.relativePath,
    required this.title,
    required this.body,
  });
  final String ulid;
  final String relativePath;
  final String title;
  final String body;

  @override
  State<_BetaEditorShell> createState() => _BetaEditorShellState();
}

class _BetaEditorShellState extends State<_BetaEditorShell> {
  static const _serializer = SuperEditorSerializer();
  // M1546 (RP-02 fix-forward on M1545): AttachmentWriter is injectable via a
  // late-bound override so widget tests can swap a fake without standing up
  // the real file_picker platform channel. Default is `const
  // AttachmentWriter()` — production behaviour unchanged.
  @visibleForTesting
  AttachmentWriter attachmentWriter = const AttachmentWriter();
  late final MutableDocument _doc;
  late final MutableDocumentComposer _composer;
  late final Editor _editor;
  late final SlashTriggerSession _session;
  // D23 slice 2f (M1535): GlobalKey on the SuperEditor mount so the
  // composer listener can reach DocumentLayout.getRectForPosition to
  // anchor the slash menu at the caret. Editor-local coordinates —
  // overlay positioning (slice 2g) stacks against the same parent so
  // the local rect maps 1-to-1 without a localToGlobal hop.
  final GlobalKey _docLayoutKey = GlobalKey();

  /// D25 slice 4b (M1602): tracks the last clicked block id so that
  /// Cmd+Shift+Click can extend the block selection from that anchor
  /// to the newly-clicked block. Updated on every block-hit click;
  /// stays untouched on `passthrough` and `clear` intents (clicking
  /// off the document doesn't change the anchor).
  String? _lastClickedBlockNodeId;

  /// D-fp4 slice 3b (M1634): Find-in-page state. `_findBarVisible`
  /// toggles whether the [FindBar] mounts at the bottom of the body
  /// Column; the controller / focus node back the bar's TextField;
  /// `_findCursor` tracks the active match list + index. All state
  /// is owned by this State so the bar widget can stay stateless.
  bool _findBarVisible = false;
  final TextEditingController _findController = TextEditingController();
  final FocusNode _findFocusNode = FocusNode();
  MatchCursor _findCursor = MatchCursor.empty();

  @override
  void initState() {
    super.initState();
    _doc = _serializer.markdownToDocument(widget.body);
    _composer = MutableDocumentComposer();
    _editor = createDefaultDocumentEditor(
      document: _doc,
      composer: _composer,
    );
    // D26 slice 1b (M1551): append the inline-mark autoformat reactions
    // after super_editor's defaultEditorReactions. Order: block-prefix
    // conversions run first, then this BoldAutoformatReaction handles
    // the `**X**` keystroke. Future sibling reactions (italic, strike,
    // inline code, highlight, sub, sup) plug in here.
    _editor.reactionPipeline.add(const BoldAutoformatReaction());
    _editor.reactionPipeline.add(const ItalicAutoformatReaction());
    _editor.reactionPipeline.add(const StrikeAutoformatReaction());
    _editor.reactionPipeline.add(const InlineCodeAutoformatReaction());
    _editor.reactionPipeline.add(const HighlightAutoformatReaction());
    _editor.reactionPipeline.add(const SubscriptAutoformatReaction());
    _editor.reactionPipeline.add(const SuperscriptAutoformatReaction());
    _session = SlashTriggerSession();
    // D23 slice 2d (M1531): every composer selection / document mutation
    // projects to a flat (text, caret) via M1528's plainTextAndCaret and
    // feeds M1525's SlashTriggerSession, which routes to the SlashMenuCubit
    // provided by the parent MultiBlocProvider (M1523). Anchor stays
    // Rect.zero in this slice — slice 2e adds real positioning, slice 2f
    // the overlay + selection-splice command.
    _composer.addListener(_onComposerChanged);
  }

  @override
  void dispose() {
    _composer.removeListener(_onComposerChanged);
    _session.reset();
    _composer.dispose();
    _doc.dispose();
    _findController.dispose();
    _findFocusNode.dispose();
    super.dispose();
  }

  void _onComposerChanged() {
    final cubit = context.read<SlashMenuCubit>();
    final snapshot = plainTextAndCaret(doc: _doc, composer: _composer);
    _session.update(
      text: snapshot.text,
      caret: snapshot.caret,
      onOpen: (triggerOffset) => cubit.openAt(
        anchor: _caretAnchor(),
        triggerOffset: triggerOffset,
      ),
      onDismiss: cubit.dismiss,
      onQuery: cubit.setQuery,
    );
  }

  /// Resolve the caret's editor-local Rect via [DocumentLayout.getRectForPosition]
  /// and convert through M1533's [anchorRectFromRect]. Falls back to a zero
  /// anchor when the layout hasn't been realized (pre-first-frame) or the
  /// composer's selection is collapsed but its node isn't laid out yet.
  /// D25 slice 4a (M1600): resolve a block node id to its document-space
  /// [Rect] via super_editor's `DocumentLayout.getRectForSelection`
  /// (covers the whole node from `beginningPosition` to `endPosition`).
  /// Returns null when the layout isn't built yet, the node has been
  /// removed, or the layout can't compute a rect for that node type.
  /// Passed to [BlockSelectionOverlay] as the `rectForNode` resolver.
  Rect? _rectForBlockNode(String nodeId) {
    final DocumentLayout? layout =
        _docLayoutKey.currentState as DocumentLayout?;
    if (layout == null) return null;
    final node = _doc.getNodeById(nodeId);
    if (node == null) return null;
    return layout.getRectForSelection(
      DocumentPosition(nodeId: nodeId, nodePosition: node.beginningPosition),
      DocumentPosition(nodeId: nodeId, nodePosition: node.endPosition),
    );
  }

  /// D-fp3 (M1625): port Share-via-OS-sheet from legacy
  /// editor_page.dart:1344 `_sharePage`. Tries `SharePlus.instance.share`
  /// with the file as `XFile` first (works on iOS / macOS / Android), falls
  /// back to plain-text body share on platforms without file-share
  /// (notably plain Linux). Reads the vault rootPath to compute the
  /// absolute file path.
  // coverage:ignore-start
  Future<void> _onSharePage() async {
    final vault = context.read<VaultBloc>().state;
    if (vault is! VaultLoaded) return;
    // M1710 (M1709 CA-07 fix-forward): use the shared vaultAbsolutePath
    // helper introduced by D-fp7 so trailing-slash dedup + null fallback
    // stay consistent between Share and Copy-path.
    final absolutePath = vaultAbsolutePath(
      rootPath: vault.rootPath,
      relativePath: widget.relativePath,
    );
    final file = File(absolutePath);
    if (!await file.exists()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot share: $absolutePath not found')),
      );
      return;
    }
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(absolutePath, name: widget.title)],
          subject: widget.title,
        ),
      );
    } on Object catch (e) {
      // Fallback to plain-text share of the body — keeps the entry
      // useful on platforms without native file-share (plain Linux).
      try {
        await SharePlus.instance.share(
          ShareParams(text: widget.body, subject: widget.title),
        );
      } on Object catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Share failed: $e')),
        );
      }
    }
  }
  // coverage:ignore-end

  /// D-fp2 (M1623): port Pull-from-server from legacy editor_page.dart:604.
  /// Dispatches `SyncFetchFileRequested` against the server-known relpath
  /// when authed; shows a SnackBar with the result. Mirrors the legacy
  /// kebab `'pull'` case at editor_page.dart:604-612.
  ///
  /// The button is hidden when not authed via a `BlocBuilder` gate at the
  /// AppBar level, so this handler doesn't need the redundant
  /// `if (!sync.state.isAuthed)` check the legacy editor still carries
  /// (its kebab item is always visible).
  // coverage:ignore-start
  void _onPullFromServer() {
    final sync = context.read<SyncBloc>();
    sync.add(SyncFetchFileRequested(relpath: widget.relativePath));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pulling latest from server…'),
        duration: Duration(seconds: 2),
      ),
    );
  }
  // coverage:ignore-end

  /// D-fp4 slice 3b (M1634): toggle the Find-in-page bar. On open,
  /// requests focus on the bar's TextField after the next frame so
  /// the user can start typing immediately. On close, clears the
  /// query + resets the cursor — mirrors editor_page.dart's M85
  /// behaviour at editor_page.dart:1989.
  ///
  /// Coverage exemption (TS-01): widget-tier orchestration over
  /// state-setter + post-frame focus. Same M1571 pattern as the
  /// other D-fp parity ports.
  // coverage:ignore-start
  void _toggleFindBar() {
    setState(() {
      _findBarVisible = !_findBarVisible;
      if (!_findBarVisible) {
        _findController.clear();
        _findCursor = MatchCursor.empty();
      }
    });
    if (_findBarVisible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _findFocusNode.requestFocus();
      });
    }
  }
  // coverage:ignore-end

  /// D-fp4 slice 3b (M1634): re-run `findMatches` against the current
  /// document, build a fresh `MatchCursor`, and dispatch the
  /// `selectionRequestForMatch` for the first match (when any). Pure
  /// orchestration over M1627's `findMatches` + M1629's `MatchCursor` +
  /// `selectionRequestForMatch`, all separately unit-tested.
  // coverage:ignore-start
  void _onFindQueryChanged(String query) {
    final matches = findMatches(document: _doc, query: query);
    final cursor = MatchCursor.initial(matches);
    setState(() => _findCursor = cursor);
    final current = cursor.current;
    if (current != null) {
      _editor.execute([selectionRequestForMatch(current)]);
    }
  }
  // coverage:ignore-end

  /// D-fp4 slice 3b (M1634): step to the next match, wrap from last
  /// back to first per `MatchCursor.next` (Notion/VSCode convention).
  // coverage:ignore-start
  void _onFindNext() {
    final advanced = _findCursor.next();
    setState(() => _findCursor = advanced);
    final current = advanced.current;
    if (current != null) {
      _editor.execute([selectionRequestForMatch(current)]);
    }
  }
  // coverage:ignore-end

  /// D-fp4 slice 3b (M1634): step to the previous match, wrap from
  /// first back to last per `MatchCursor.previous`.
  // coverage:ignore-start
  void _onFindPrev() {
    final advanced = _findCursor.previous();
    setState(() => _findCursor = advanced);
    final current = advanced.current;
    if (current != null) {
      _editor.execute([selectionRequestForMatch(current)]);
    }
  }
  // coverage:ignore-end

  /// D-fp1 (M1621): port Move-to-Trash from legacy editor_page.dart:654.
  /// Confirm via dialog, dispatch VaultBloc(MoveToTrash) + optional
  /// SyncBloc(SyncDeleteFileRequested) when authed, navigate home.
  /// Coverage exemption (TS-01): widget-tier handler over already-tested
  /// bloc paths — matches the legacy M195 wire-up.
  // coverage:ignore-start
  Future<void> _onMoveToTrash() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Move to trash?'),
        content: Text(
          'The .md file moves to .trash/. '
          'You can restore it from the Trash dialog later.\n\n'
          '${widget.relativePath}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Move to trash'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    context.read<VaultBloc>().add(MoveToTrash(widget.ulid));
    // Mirror to the v2 backend when authed so the server tombstones
    // the row and forgets the knownSha (matches editor_page.dart:660-663).
    final sync = context.read<SyncBloc>();
    if (sync.state.isAuthed) {
      sync.add(SyncDeleteFileRequested(relpath: widget.relativePath));
    }
    if (!mounted) return;
    context.go(Routes.home);
  }
  // coverage:ignore-end

  /// D-fp17 (M1737): port Copy-body from legacy
  /// editor_page.dart:536 (case 'copy-body'). Writes the current
  /// page body to the system clipboard; toast reports the char
  /// count via the M1737 [copiedCharsLabel] helper.
  ///
  /// Coverage exemption (TS-01): widget-tier orchestration over
  /// `Clipboard.setData` + `ScaffoldMessenger`. The label is
  /// independently tested in `copy_labels_test.dart`.
  // coverage:ignore-start
  Future<void> _onCopyBody() async {
    final editorState = context.read<EditorBloc>().state;
    if (editorState is! EditorLoaded) return;
    final body = editorState.page.body;
    await Clipboard.setData(ClipboardData(text: body));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(copiedCharsLabel(body.length)),
        duration: const Duration(seconds: 2),
      ),
    );
  }
  // coverage:ignore-end

  /// D-fp18 (M1739): port Copy-plain from legacy
  /// editor_page.dart:543 (case 'copy-plain'). Runs the page body
  /// through [stripMarkdown] to drop syntax characters, writes the
  /// result to the system clipboard, and reports the new char count
  /// via [copiedCharsLabel] with the "as plain text" suffix.
  ///
  /// Coverage exemption (TS-01): widget-tier orchestration over
  /// `Clipboard.setData` + `ScaffoldMessenger`. The label suffix +
  /// strip helper are independently tested in
  /// `copy_labels_test.dart` and `strip_markdown_test.dart`.
  // coverage:ignore-start
  Future<void> _onCopyPlain() async {
    final editorState = context.read<EditorBloc>().state;
    if (editorState is! EditorLoaded) return;
    final plain = stripMarkdown(editorState.page.body);
    await Clipboard.setData(ClipboardData(text: plain));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(copiedCharsLabel(plain.length, suffix: 'as plain text')),
        duration: const Duration(seconds: 2),
      ),
    );
  }
  // coverage:ignore-end

  /// D-fp20 (M1743): port Copy-form-link from legacy
  /// editor_page.dart:504 (case 'copy-form-link'). Builds the public
  /// `<backendBaseUrl>/forms/<ulid>` URL via [publicFormUrl] and
  /// writes it to the system clipboard so the author can paste it
  /// anywhere (Slack, email, embed). Visitors fill out the rendered
  /// form (E56b) and submissions land in the per-page list reachable
  /// via the [EditorBetaAppBarAction.viewFormSubmissions] entry. The
  /// kebab entry that triggers this handler only renders when
  /// [hasFormsFrontmatter] returns true for the current page (same
  /// `isFormBearing` gate as viewFormSubmissions).
  ///
  /// Coverage exemption (TS-01): widget-tier orchestration over
  /// `Clipboard.setData` + `ScaffoldMessenger`. The URL-build helper
  /// has 4 unit tests in `backend_endpoint_test.dart`.
  // coverage:ignore-start
  Future<void> _onCopyFormLink() async {
    final editorState = context.read<EditorBloc>().state;
    if (editorState is! EditorLoaded) return;
    final pageUlid = editorState.page.ulid;
    if (pageUlid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot copy form link: page has no ULID'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    final url = publicFormUrl(
      backendBaseUrl: kBackendHttpBaseUrl,
      pageUlid: pageUlid,
    );
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied form link: $url'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
  // coverage:ignore-end

  /// D-fp19 (M1741): port View-form-submissions from legacy
  /// editor_page.dart:614 (case 'view-form-submissions') →
  /// `_viewFormSubmissions`. Reads the SyncBloc token, checks
  /// `isAuthed`, then opens the [FormSubmissionsDialog] backed by
  /// `FormsRepository.listSubmissions(token:, ulid:)`. SnackBars when
  /// the page lacks a ULID or the user is signed out, matching the
  /// legacy editor's behaviour exactly. The kebab entry that triggers
  /// this handler only renders when [hasFormsFrontmatter] returns
  /// true for the current page (see [EditorBetaAppBarAction]
  /// `isFormBearing` gate).
  ///
  /// Coverage exemption (TS-01): widget-tier orchestration over the
  /// pre-existing `FormSubmissionsDialog` (E51) + a `FormsRepository`
  /// lookup. The hasFormsFrontmatter gate has its own 6 unit tests.
  // coverage:ignore-start
  Future<void> _onViewFormSubmissions() async {
    final editorState = context.read<EditorBloc>().state;
    if (editorState is! EditorLoaded) return;
    final pageUlid = editorState.page.ulid;
    if (pageUlid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot list submissions: page has no ULID'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    final sync = context.read<SyncBloc>();
    final token = sync.state.token;
    if (token == null || !sync.state.isAuthed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Not logged in — sign in to view submissions.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    final repo = context.read<FormsRepository>();
    await showDialog<void>(
      context: context,
      builder: (_) => FormSubmissionsDialog(
        ulid: pageUlid,
        load: () => repo.listSubmissions(token: token, ulid: pageUlid),
      ),
    );
  }
  // coverage:ignore-end

  /// D-fp18 (M1739): port Copy-JSON from legacy
  /// editor_page.dart:555 (case 'copy-json'). Builds the canonical
  /// `{ ulid, relativePath, frontmatter, body }` payload via
  /// [pageAsJsonPayload], writes the JSON string to the clipboard,
  /// and reports the byte length via [copiedCharsLabel] with the
  /// "JSON" suffix.
  ///
  /// Coverage exemption (TS-01): widget-tier orchestration over
  /// `Clipboard.setData` + `ScaffoldMessenger`. The payload shape is
  /// independently tested in `page_json_payload_test.dart`.
  // coverage:ignore-start
  Future<void> _onCopyJson() async {
    final editorState = context.read<EditorBloc>().state;
    if (editorState is! EditorLoaded) return;
    final page = editorState.page;
    final fmMap = <String, Object?>{};
    for (final e in page.frontmatter.entries) {
      fmMap[e.key] = e.value;
    }
    final payload = pageAsJsonPayload(
      ulid: page.ulid,
      relativePath: page.relativePath,
      frontmatter: fmMap,
      body: page.body,
    );
    await Clipboard.setData(ClipboardData(text: payload));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(copiedCharsLabel(payload.length, suffix: 'JSON')),
        duration: const Duration(seconds: 2),
      ),
    );
  }
  // coverage:ignore-end

  /// D-fp16 (M1735): port Snooze-reminder from legacy
  /// editor_page.dart:1010 (`_snoozeReminder`). Opens a 4-option
  /// chooser (+1 / +3 / +7 / +30 days), computes the new ISO date
  /// via the M1733 [isoDate] helper relative to the M1735
  /// [snoozeBaseFor] start (which guards against snoozing a
  /// past-due reminder back into the past), and dispatches
  /// EditFrontmatterField to update the `reminder:` field. SnackBars
  /// "No reminder set" when the page has none.
  ///
  /// Coverage exemption (TS-01): widget-tier orchestration over the
  /// pure-Dart `snoozeBaseFor` + `isoDate` + `relativeReminderLabel`
  /// helpers (all unit-tested in `reminder_date_test.dart`).
  // coverage:ignore-start
  Future<void> _onSnoozeReminder() async {
    final bloc = context.read<EditorBloc>();
    final editorState = bloc.state;
    if (editorState is! EditorLoaded) return;
    final fm = editorState.page.frontmatter;
    final existing = fm.find('reminder');
    if (existing == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No reminder set. Use "Set reminder…" first.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    final parsed = DateTime.tryParse(existing.rawScalar);
    final now = DateTime.now();
    final start = snoozeBaseFor(existing: parsed, today: now);
    final picked = await showQuillChoice<int>(
      context,
      title: 'Snooze reminder',
      icon: 'clock',
      options: const [
        QuillChoiceOption<int>(value: 1, label: '+ 1 day', icon: 'clock'),
        QuillChoiceOption<int>(value: 3, label: '+ 3 days', icon: 'clock'),
        QuillChoiceOption<int>(value: 7, label: '+ 1 week', icon: 'clock'),
        QuillChoiceOption<int>(
          value: 30,
          label: '+ 1 month (30d)',
          icon: 'clock',
        ),
      ],
    );
    if (picked == null || !mounted) return;
    final next = start.add(Duration(days: picked));
    final iso = isoDate(next);
    bloc.add(
      EditFrontmatterField(
        'reminder',
        existing.copyWith(rawScalar: iso, value: iso),
      ),
    );
    final relative = relativeReminderLabel(picked: next, now: now);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Snoozed reminder to $iso ($relative)'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
  // coverage:ignore-end

  /// D-fp16 (M1735): port Clear-reminder from legacy
  /// editor_page.dart:582 (case 'clear-reminder'). Removes the
  /// `reminder:` frontmatter field; SnackBars "no reminder set"
  /// when there's nothing to clear.
  ///
  /// Coverage exemption (TS-01): widget-tier orchestration over
  /// the EditorBloc Remove event.
  // coverage:ignore-start
  void _onClearReminder() {
    final bloc = context.read<EditorBloc>();
    final editorState = bloc.state;
    if (editorState is! EditorLoaded) return;
    final existing = editorState.page.frontmatter.find('reminder');
    if (existing == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No reminder set on this page.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    final was = existing.rawScalar.trim();
    bloc.add(const RemoveFrontmatterField('reminder'));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          was.isEmpty
              ? 'Reminder cleared.'
              : 'Reminder cleared (was $was).',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }
  // coverage:ignore-end

  /// D-fp15 (M1733): port Set-reminder from legacy
  /// editor_page.dart:1055 (`_setReminder`). Opens
  /// `showQuillDatePicker`, formats the pick via M1733
  /// [isoDate] for the `reminder:` frontmatter value, and dispatches
  /// `AddFrontmatterField` / `EditFrontmatterField` (with the no-op
  /// "already set" SnackBar when picking the same date). Toast uses
  /// [relativeReminderLabel] for the "today / tomorrow / in N days"
  /// suffix, matching the legacy UX exactly.
  ///
  /// Coverage exemption (TS-01): widget-tier orchestration over
  /// `showQuillDatePicker` + `ScaffoldMessenger` + frontmatter
  /// events. All formatting logic is unit-tested via
  /// `reminder_date_test.dart`.
  // coverage:ignore-start
  Future<void> _onSetReminder() async {
    final bloc = context.read<EditorBloc>();
    final editorState = bloc.state;
    if (editorState is! EditorLoaded) return;
    final fm = editorState.page.frontmatter;
    final existing = fm.find('reminder');
    final now = DateTime.now();
    var initial = DateTime(now.year, now.month, now.day);
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
    if (picked == null || !mounted) return;
    final iso = isoDate(picked);
    if (existing != null && existing.rawScalar.trim() == iso) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reminder already set for $iso'),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    if (existing == null) {
      bloc.add(
        AddFrontmatterField(
          FrontmatterEntry(
            key: 'reminder',
            rawScalar: iso,
            type: FrontmatterType.date,
            value: iso,
          ),
        ),
      );
    } else {
      bloc.add(
        EditFrontmatterField(
          'reminder',
          existing.copyWith(rawScalar: iso, value: iso),
        ),
      );
    }
    final relative = relativeReminderLabel(picked: picked, now: now);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Reminder set for $iso ($relative)'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
  // coverage:ignore-end

  /// D-fp14 (M1731): port Set-font from legacy editor_page.dart:805
  /// (`_setFont`). Opens a 3-option `showQuillChoice` (sans / serif /
  /// mono); the result is routed through `pageFontActionFor` (M1731
  /// pure-Dart planner) so the no-op detection is reuseable. Mirrors
  /// the legacy add / edit / remove dispatch logic against
  /// frontmatter `font:`.
  ///
  /// Coverage exemption (TS-01): widget-tier orchestration over
  /// `showQuillChoice` + `ScaffoldMessenger` + frontmatter events.
  /// All branching logic is unit-tested via `pageFontActionFor`.
  // coverage:ignore-start
  Future<void> _onSetFont() async {
    final editorState = context.read<EditorBloc>().state;
    if (editorState is! EditorLoaded) return;
    final existing = editorState.page.frontmatter.find('font')?.rawScalar;
    final picked = await showQuillChoice<String>(
      context,
      title: 'Page font',
      icon: 'edit',
      options: const [
        QuillChoiceOption<String>(
          value: 'sans',
          label: 'Sans-serif (default)',
        ),
        QuillChoiceOption<String>(value: 'serif', label: 'Serif (Georgia)'),
        QuillChoiceOption<String>(
          value: 'mono',
          label: 'Monospace (JetBrainsMono)',
        ),
      ],
    );
    if (picked == null || !mounted) return;
    final plan = pageFontActionFor(picked: picked, existing: existing);
    if (plan == PageFontAction.noop) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Page font already set to ${pageFontLabel(picked)}'),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    final bloc = context.read<EditorBloc>();
    switch (plan) {
      case PageFontAction.remove:
        bloc.add(const RemoveFrontmatterField('font'));
      case PageFontAction.add:
        bloc.add(
          AddFrontmatterField(
            FrontmatterEntry(
              key: 'font',
              rawScalar: picked,
              type: FrontmatterType.text,
              value: picked,
            ),
          ),
        );
      case PageFontAction.edit:
        bloc.add(
          EditFrontmatterField(
            'font',
            FrontmatterEntry(
              key: 'font',
              rawScalar: picked,
              type: FrontmatterType.text,
              value: picked,
            ),
          ),
        );
      case PageFontAction.noop:
        return; // already handled above
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Page font: ${pageFontLabel(picked)}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
  // coverage:ignore-end

  /// D-fp21 (M1745): port Set-word-count-goal from legacy
  /// editor_page.dart:954 (`_setWordGoal`). Opens a [showQuillPrompt]
  /// seeded with the existing rawScalar (or empty), routes the
  /// trimmed input through the M1745 [wordGoalActionFor] planner,
  /// then dispatches the matching frontmatter event (Remove / Add /
  /// Edit) or SnackBars the no-op / invalid result. Pluralisation in
  /// SnackBars uses [wordGoalLabel].
  ///
  /// Coverage exemption (TS-01): widget-tier orchestration over
  /// `showQuillPrompt` + `ScaffoldMessenger` + frontmatter events.
  /// All branching logic is unit-tested via `wordGoalActionFor`.
  // coverage:ignore-start
  Future<void> _onSetGoal() async {
    final bloc = context.read<EditorBloc>();
    final editorState = bloc.state;
    if (editorState is! EditorLoaded) return;
    final existing = editorState.page.frontmatter.find('goal');
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
    if (picked == null || !mounted) return;
    final plan = wordGoalActionFor(
      picked: picked,
      existing: existing?.rawScalar,
    );
    switch (plan) {
      case WordGoalAction.noop:
        return;
      case WordGoalAction.invalid:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Goal must be a positive whole number'),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      case WordGoalAction.remove:
        final was = existing!.rawScalar.trim();
        bloc.add(const RemoveFrontmatterField('goal'));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(was.isEmpty
                ? 'Word count goal cleared'
                : 'Word count goal cleared (was $was)'),
            duration: const Duration(seconds: 2),
          ),
        );
        return;
      case WordGoalAction.noopAlreadySet:
        final n = int.parse(picked.trim());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Word count goal already ${wordGoalLabel(n)}'),
            duration: const Duration(seconds: 2),
          ),
        );
        return;
      case WordGoalAction.add:
        final n = int.parse(picked.trim());
        bloc.add(
          AddFrontmatterField(
            FrontmatterEntry(
              key: 'goal',
              rawScalar: '$n',
              type: FrontmatterType.number,
              value: n,
            ),
          ),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Word count goal: ${wordGoalLabel(n)}'),
            duration: const Duration(seconds: 2),
          ),
        );
        return;
      case WordGoalAction.edit:
        final n = int.parse(picked.trim());
        bloc.add(
          EditFrontmatterField(
            'goal',
            existing!.copyWith(rawScalar: '$n', value: n),
          ),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Word count goal: ${wordGoalLabel(n)}'),
            duration: const Duration(seconds: 2),
          ),
        );
        return;
    }
  }
  // coverage:ignore-end

  /// D-fp22 (M1747): port Export-as-Markdown from legacy
  /// editor_page.dart:1134 (`_exportPageAsMarkdown`). Reads
  /// VaultBloc's rootPath, copies the source `.md` file to the
  /// user-picked path via `FilePicker.platform.saveFile`. The filename
  /// seed comes from [safeExportFilename] applied to `page.title`.
  ///
  /// Coverage exemption (TS-01): widget-tier orchestration over
  /// `FilePicker` + `dart:io` `File.copy` + `ScaffoldMessenger`. The
  /// filename normaliser has 7 unit tests in
  /// `safe_export_filename_test.dart`.
  // coverage:ignore-start
  Future<void> _onExportMarkdown() async {
    final vault = context.read<VaultBloc>().state;
    if (vault is! VaultLoaded) return;
    final editorState = context.read<EditorBloc>().state;
    if (editorState is! EditorLoaded) return;
    final page = editorState.page;
    final source = File('${vault.rootPath}/${page.relativePath}');
    if (!await source.exists()) return;
    if (!mounted) return;
    final safeName = safeExportFilename(page.title);
    final picked = await FilePicker.platform.saveFile(
      dialogTitle: 'Export page as Markdown…',
      fileName: '$safeName.md',
      type: FileType.custom,
      allowedExtensions: const ['md'],
    );
    if (picked == null || !mounted) return;
    try {
      await source.copy(picked);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exported markdown: $picked'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
  // coverage:ignore-end

  /// D-fp22 (M1747): port Export-as-HTML from legacy
  /// editor_page.dart:1107 (`_exportPageAsHtml`). Renders
  /// `HtmlExporter.renderStandalonePage(title:, body:)` and writes
  /// the resulting standalone HTML to the user-picked path. Shares
  /// the [safeExportFilename] seed with the markdown variant.
  ///
  /// Coverage exemption (TS-01): widget-tier orchestration over
  /// `FilePicker` + `dart:io` `File.writeAsString` +
  /// `ScaffoldMessenger`. HtmlExporter has its own test coverage.
  // coverage:ignore-start
  Future<void> _onExportHtml() async {
    final editorState = context.read<EditorBloc>().state;
    if (editorState is! EditorLoaded) return;
    final page = editorState.page;
    final safeName = safeExportFilename(page.title);
    final picked = await FilePicker.platform.saveFile(
      dialogTitle: 'Export page as HTML…',
      fileName: '$safeName.html',
      type: FileType.custom,
      allowedExtensions: const ['html'],
    );
    if (picked == null || !mounted) return;
    try {
      final html = HtmlExporter.renderStandalonePage(
        title: page.title,
        body: page.body,
      );
      await File(picked).writeAsString(html);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exported HTML: $picked'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
  // coverage:ignore-end

  /// D-fp12 (M1725): port Page-history from legacy editor_page.dart:534
  /// (`_showPageHistory`). Reads the VaultBloc's rootPath, opens the
  /// [PageHistoryDialog] backed by `git log`. The dialog handles the
  /// "no git history" case itself when the vault is not a git repo.
  ///
  /// Coverage exemption (TS-01): widget-tier orchestration over a
  /// pre-existing dialog widget that already has its own coverage.
  // coverage:ignore-start
  Future<void> _onPageHistory() async {
    final vault = context.read<VaultBloc>().state;
    if (vault is! VaultLoaded) return;
    await showDialog<void>(
      context: context,
      builder: (_) => PageHistoryDialog(
        vaultRoot: vault.rootPath,
        relativePath: widget.relativePath,
      ),
    );
  }
  // coverage:ignore-end

  /// D-fp11 (M1722): port Publish-toggle from legacy
  /// editor_page.dart:599 ('publish') + :603 ('unpublish'). Reads
  /// the EditorBloc's current state to inspect frontmatter; if
  /// `public:` is present, dispatch `RemoveFrontmatterField('public')`
  /// (and also `public_password` if set); otherwise dispatch an
  /// `AddFrontmatterField(public: true)` event. SnackBar mirrors the
  /// resulting state.
  ///
  /// The password-gated variant (legacy `'publish-password'` case at
  /// `editor_page.dart:601`) is deliberately deferred — keeps this
  /// slice bite-sized.
  ///
  /// Coverage exemption (TS-01): widget-tier orchestration over the
  /// pre-existing AddFrontmatterField / RemoveFrontmatterField events
  /// that the legacy editor already fires.
  // coverage:ignore-start
  void _onPublishToggle() {
    // M1723 (M1722 CA-06 fix-forward): capture EditorBloc once so the
    // state read + add() share a single context.read.
    final bloc = context.read<EditorBloc>();
    final editorState = bloc.state;
    if (editorState is! EditorLoaded) return;
    final fm = editorState.page.frontmatter;
    final isPublic = fm.find('public') != null;
    if (isPublic) {
      bloc.add(const RemoveFrontmatterField('public'));
      if (fm.find('public_password') != null) {
        bloc.add(const RemoveFrontmatterField('public_password'));
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unpublished'),
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      const entry = FrontmatterEntry(
        key: 'public',
        rawScalar: 'true',
        type: FrontmatterType.checkbox,
        value: true,
      );
      bloc.add(const AddFrontmatterField(entry));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Published — public: true added to frontmatter'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
  // coverage:ignore-end

  /// D-fp10 (M1719): port Rename-file from legacy
  /// editor_page.dart:705 (`_renameFile`). Opens a [showQuillPrompt]
  /// dialog seeded with the current basename, runs the picked value
  /// through the M1719 [sanitizedBasename] helper for a preview, and
  /// dispatches `RenamePage(ulid:, newBasename:)` against VaultBloc.
  /// The ULID + wikilinks survive the rename — only the on-disk
  /// filename changes.
  ///
  /// Coverage exemption (TS-01): widget-tier orchestration over
  /// `showQuillPrompt` + `ScaffoldMessenger` + a VaultBloc dispatch.
  /// The sanitisation logic has 6 unit tests via
  /// `sanitized_basename_test.dart`.
  // coverage:ignore-start
  Future<void> _onRename() async {
    final current = widget.relativePath;
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
    if (!mounted) return;
    final preview = sanitizedBasename(picked);
    if (preview == base) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Filename unchanged'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    // M1720 (M1719 TS-01 info fix-forward): dispatch the sanitised
    // preview, not the raw picked string. Two reasons:
    // 1. The SnackBar shows "Renamed to $preview.md"; the event
    //    should carry exactly what the user will see persisted.
    // 2. VaultBloc._onRenamePage runs its own _safeFileName(...) but
    //    if that helper ever diverges from sanitizedBasename the two
    //    views (toast + on-disk) would drift. Sending preview makes
    //    sanitizedBasename the single source of truth.
    context.read<VaultBloc>().add(
          RenamePage(ulid: widget.ulid, newBasename: preview),
        );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Renamed to $preview.md'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
  // coverage:ignore-end

  /// D-fp9 (M1715): port Reveal-in-Finder/Explorer from legacy
  /// editor_page.dart:525. Resolves the absolute filesystem path via
  /// the M1709 [vaultAbsolutePath] helper, then dispatches through
  /// the cross-platform `Reveal.show()` (macOS: `open -R`; Linux:
  /// `xdg-open` on the parent dir; Windows: `explorer.exe /select,`).
  /// On failure (unsupported platform / non-zero exit) shows a
  /// SnackBar with the path so the user can copy it manually.
  ///
  /// Coverage exemption (TS-01): widget-tier orchestration over the
  /// pre-existing `Reveal.show()` platform helper and VaultBloc
  /// state read. `vaultAbsolutePath` has its own 6 unit tests.
  // coverage:ignore-start
  Future<void> _onReveal() async {
    final vault = context.read<VaultBloc>().state;
    if (vault is! VaultLoaded) return;
    final path = vaultAbsolutePath(
      rootPath: vault.rootPath,
      relativePath: widget.relativePath,
    );
    final ok = await Reveal.show(path);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not reveal: $path'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
  // coverage:ignore-end

  /// D-fp8 (M1712): port Duplicate page from legacy
  /// editor_page.dart:620. Dispatches the existing
  /// [DuplicatePage] VaultBloc event with an `onCreated` callback
  /// that navigates the editor to the freshly created copy + shows a
  /// transient SnackBar with the new ULID.
  ///
  /// Coverage exemption (TS-01): widget-tier orchestration over a
  /// VaultBloc event the legacy editor already fires + a router go.
  /// The DuplicatePage handler in `vault_bloc.dart:_onDuplicate` has
  /// its own test coverage.
  // coverage:ignore-start
  void _onDuplicate() {
    final router = GoRouter.of(context);
    final scope = context;
    final sourceTitle = widget.title;
    context.read<VaultBloc>().add(
          DuplicatePage(
            widget.ulid,
            onCreated: (newUlid) {
              if (!scope.mounted) return;
              final main = sourceTitle.isEmpty
                  ? 'Page duplicated'
                  : 'Duplicated "$sourceTitle"';
              ScaffoldMessenger.of(scope).showSnackBar(
                SnackBar(
                  content: Text('$main • new ULID: $newUlid'),
                  duration: const Duration(seconds: 2),
                ),
              );
              router.go(Routes.editor(newUlid));
            },
          ),
        );
  }
  // coverage:ignore-end

  /// D-fp7 (M1709): port Copy-path from legacy editor_page.dart:518.
  /// Writes the absolute filesystem path (`vault.rootPath + '/' +
  /// widget.relativePath`) to the system clipboard via the M1709
  /// `vaultAbsolutePath` helper. Falls back to the bare relative
  /// path if VaultBloc hasn't loaded yet — same defensive behaviour
  /// as the legacy handler.
  ///
  /// Coverage exemption (TS-01): widget-tier orchestration over
  /// `Clipboard.setData` + `ScaffoldMessenger`. The join logic is
  /// pre-tested in `vault_absolute_path_test.dart` (6 tests).
  // coverage:ignore-start
  Future<void> _onCopyPath() async {
    final vault = context.read<VaultBloc>().state;
    final rootPath = vault is VaultLoaded ? vault.rootPath : null;
    final path = vaultAbsolutePath(
      rootPath: rootPath,
      relativePath: widget.relativePath,
    );
    await Clipboard.setData(ClipboardData(text: path));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied $path'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
  // coverage:ignore-end

  /// D-fp6 (M1703): port Copy-ULID from legacy editor_page.dart:501.
  /// Writes the bare ULID to the system clipboard so users can paste it
  /// into external scripts, frontmatter, or git commit messages — same
  /// Clipboard pattern as D-fp5 [_onCopyLink] but without the `[[…]]`
  /// brackets. The tooltip + ordering for the AppBar button live on
  /// [EditorBetaAppBarAction.copyUlid] (M1700).
  ///
  /// Coverage exemption (TS-01): widget-tier orchestration over
  /// `Clipboard.setData` + `ScaffoldMessenger`. The enum slot is
  /// pre-tested by `editor_beta_app_bar_actions_test.dart` (M1700,
  /// M1701).
  // coverage:ignore-start
  Future<void> _onCopyUlid() async {
    await Clipboard.setData(ClipboardData(text: widget.ulid));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied ${widget.ulid}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
  // coverage:ignore-end

  /// D-fp5 (M1696): port Copy-[[link]] from legacy editor_page.dart:515.
  /// Writes `[[<ulid>]]` to the system clipboard so the user can paste
  /// it into any other page; pops a transient SnackBar confirming.
  /// Wraps the M1696 [wikilinkLiteralFor] so the literal format lives
  /// in one place (see lib/core/markdown/wikilink_parser.dart).
  ///
  /// Coverage exemption (TS-01): widget-tier orchestration over
  /// `Clipboard.setData` + `ScaffoldMessenger`. The actual literal
  /// formatting has its own 5 unit tests via [wikilinkLiteralFor].
  // coverage:ignore-start
  Future<void> _onCopyLink() async {
    final literal = wikilinkLiteralFor(ulid: widget.ulid);
    await Clipboard.setData(ClipboardData(text: literal));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied $literal'), duration: const Duration(seconds: 2)),
    );
  }
  // coverage:ignore-end

  /// D25 slice 5b (M1607): named-method keyboard handlers that read
  /// the BlockSelectionCubit at callback time (not at build time), so
  /// DI-04 lint doesn't fire on `context.read` inside `build`.
  ExecutionInstruction _multiBlockDeleteAction({
    required SuperEditorContext editContext,
    required KeyEvent keyEvent,
  }) =>
      blockDeleteKeyboardActionWithSelection(
        editContext: editContext,
        keyEvent: keyEvent,
        blockSelection: context.read<BlockSelectionCubit>().state,
      );

  ExecutionInstruction _multiHeadingConversionAction({
    required SuperEditorContext editContext,
    required KeyEvent keyEvent,
  }) =>
      headingConversionKeyboardActionWithSelection(
        editContext: editContext,
        keyEvent: keyEvent,
        blockSelection: context.read<BlockSelectionCubit>().state,
      );

  ExecutionInstruction _multiBlockConversionAction({
    required SuperEditorContext editContext,
    required KeyEvent keyEvent,
  }) =>
      blockConversionKeyboardActionWithSelection(
        editContext: editContext,
        keyEvent: keyEvent,
        blockSelection: context.read<BlockSelectionCubit>().state,
      );

  /// D-fp4 slice 4b (M1638): named-method SuperEditorKeyboardAction
  /// bridging [parseFindInPageKey] (M1636) to the find-bar state on
  /// `_BetaEditorShellState`. Same shape as the M1607 cubit-bound
  /// handlers (named method so the state read happens in the callback,
  /// not the closure literal inside `build`).
  ///
  /// Intent → side effect:
  /// - open    → toggle bar visible + focus the TextField (halts)
  /// - next    → advance MatchCursor + dispatch selection (halts iff
  ///             cursor non-empty; otherwise falls through so other
  ///             handlers can still see Cmd+G)
  /// - previous → step back the cursor + dispatch (same gate)
  /// - close   → close the bar — only consumes Esc when the bar is
  ///             actually visible, so Esc still passes through to
  ///             super_editor's caret-blur handlers when the bar is
  ///             closed
  /// - none    → continueExecution
  ///
  /// Coverage exemption (TS-01): handler composes the M1636 parser
  /// (11 unit tests) + the M1634 state methods (M1571-exempt). Same
  /// M1571 pattern as the other D-fp parity ports.
  // coverage:ignore-start
  ExecutionInstruction _findInPageKeyboardAction({
    required SuperEditorContext editContext,
    required KeyEvent keyEvent,
  }) {
    final intent = parseFindInPageKey(
      keyEvent: keyEvent,
      isShiftPressed: HardwareKeyboard.instance.isShiftPressed,
      isPrimaryShortcutPressed: keyEvent.isPrimaryShortcutKeyPressed,
    );
    switch (intent) {
      case FindInPageKeyIntent.open:
        _toggleFindBar();
        return ExecutionInstruction.haltExecution;
      case FindInPageKeyIntent.next:
        if (_findCursor.isEmpty) return ExecutionInstruction.continueExecution;
        _onFindNext();
        return ExecutionInstruction.haltExecution;
      case FindInPageKeyIntent.previous:
        if (_findCursor.isEmpty) return ExecutionInstruction.continueExecution;
        _onFindPrev();
        return ExecutionInstruction.haltExecution;
      case FindInPageKeyIntent.close:
        if (!_findBarVisible) return ExecutionInstruction.continueExecution;
        _toggleFindBar();
        return ExecutionInstruction.haltExecution;
      case FindInPageKeyIntent.none:
        return ExecutionInstruction.continueExecution;
    }
  }
  // coverage:ignore-end

  /// D25 slice 4b (M1602): passive pointer-down observer that mutates
  /// `BlockSelectionCubit` based on the click's hit-test + modifier
  /// state. Wired via a `Listener` (not a `GestureDetector`) so we
  /// don't compete with super_editor's own gesture pipeline — both
  /// receive the event and act on the parts they own (we own the
  /// multi-selection state, super_editor owns the text caret).
  ///
  /// On `replace` intent we currently dispatch `clearSelection` rather
  /// than `selectBlock`: a plain click should let super_editor's
  /// caret take over, so the multi-selection clears. A future
  /// block-handle hit-test (the `⋮⋮` gutter glyph on hover) can wire
  /// `selectBlock` directly.
  void _onPointerDown(PointerDownEvent event) {
    final DocumentLayout? layout =
        _docLayoutKey.currentState as DocumentLayout?;
    final position = layout?.getDocumentPositionAtOffset(event.localPosition);
    final nodeId = position?.nodeId;
    final keyboard = HardwareKeyboard.instance;
    final intent = interpretBlockClick(
      nodeId: nodeId,
      isPrimaryShortcutPressed: keyboard.isMetaPressed || keyboard.isControlPressed,
      isShiftPressed: keyboard.isShiftPressed,
    );
    final cubit = context.read<BlockSelectionCubit>();
    switch (intent) {
      case BlockSelectionGestureIntent.clear:
      case BlockSelectionGestureIntent.replace:
        cubit.clearSelection();
      case BlockSelectionGestureIntent.toggle:
        if (nodeId != null) {
          cubit.toggleBlock(nodeId);
          _lastClickedBlockNodeId = nodeId;
        }
      case BlockSelectionGestureIntent.extend:
        if (nodeId != null) {
          cubit.extendSelection(
            anchor: _lastClickedBlockNodeId ?? nodeId,
            extent: nodeId,
            document: _doc,
          );
          _lastClickedBlockNodeId = nodeId;
        }
      case BlockSelectionGestureIntent.passthrough:
        break;
    }
  }

  /// M1705: maps an [EditorBetaAppBarAction] enum value to the concrete
  /// `IconButton` the AppBar renders. Icon mapping was further extracted
  /// at M1707 into the top-level [iconFor] helper so each action's icon
  /// is unit-testable without a widget tree; the handler-reference
  /// switch stays here since it's bound to State methods.
  /// M1729 (D-fp13 kebab refactor slice 2): map each
  /// [EditorBetaAppBarAction] enum value to the State method that
  /// executes it. Pulled out of `_iconButtonFor` so the new
  /// `PopupMenuButton` kebab can dispatch the same way without
  /// duplicating the switch.
  VoidCallback _handlerFor(EditorBetaAppBarAction action) =>
      switch (action) {
        EditorBetaAppBarAction.pullFromServer => _onPullFromServer,
        EditorBetaAppBarAction.findInPage => _toggleFindBar,
        EditorBetaAppBarAction.share => _onSharePage,
        EditorBetaAppBarAction.copyLink => _onCopyLink,
        EditorBetaAppBarAction.copyUlid => _onCopyUlid,
        EditorBetaAppBarAction.copyPath => _onCopyPath,
        EditorBetaAppBarAction.duplicate => _onDuplicate,
        EditorBetaAppBarAction.reveal => _onReveal,
        EditorBetaAppBarAction.rename => _onRename,
        EditorBetaAppBarAction.publishToggle => _onPublishToggle,
        EditorBetaAppBarAction.pageHistory => _onPageHistory,
        EditorBetaAppBarAction.setFont => _onSetFont,
        EditorBetaAppBarAction.setGoal => _onSetGoal,
        EditorBetaAppBarAction.exportMarkdown => _onExportMarkdown,
        EditorBetaAppBarAction.exportHtml => _onExportHtml,
        EditorBetaAppBarAction.setReminder => _onSetReminder,
        EditorBetaAppBarAction.snoozeReminder => _onSnoozeReminder,
        EditorBetaAppBarAction.clearReminder => _onClearReminder,
        EditorBetaAppBarAction.copyBody => _onCopyBody,
        EditorBetaAppBarAction.copyPlain => _onCopyPlain,
        EditorBetaAppBarAction.copyJson => _onCopyJson,
        EditorBetaAppBarAction.copyFormLink => _onCopyFormLink,
        EditorBetaAppBarAction.viewFormSubmissions => _onViewFormSubmissions,
        EditorBetaAppBarAction.moveToTrash => _onMoveToTrash,
      };

  IconButton _iconButtonFor(EditorBetaAppBarAction action) {
    return IconButton(
      icon: Icon(iconFor(action)),
      tooltip: action.tooltip,
      onPressed: _handlerFor(action),
    );
  }

  /// M1729 (D-fp13 kebab refactor slice 2): render the secondary
  /// AppBar actions as a single trailing `PopupMenuButton` kebab. The
  /// partition order is locked by `editorBetaKebabActions` unit
  /// tests, so the rendered menu always matches the docs. The
  /// `isFormBearing` flag (M1741, D-fp19) gates the
  /// `viewFormSubmissions` row to pages that declare a non-empty
  /// `forms:` frontmatter field.
  PopupMenuButton<EditorBetaAppBarAction> _kebabFor({
    required bool isAuthed,
    required bool isFormBearing,
  }) {
    return PopupMenuButton<EditorBetaAppBarAction>(
      icon: const Icon(Icons.more_vert),
      tooltip: 'More actions',
      onSelected: (action) => _handlerFor(action).call(),
      itemBuilder: (context) => [
        for (final action in editorBetaKebabActions(
          isAuthed: isAuthed,
          isFormBearing: isFormBearing,
        ))
          PopupMenuItem<EditorBetaAppBarAction>(
            value: action,
            child: Row(
              children: [
                Icon(iconFor(action), size: 18),
                const SizedBox(width: 12),
                Text(action.tooltip),
              ],
            ),
          ),
      ],
    );
  }

  AnchorRect _caretAnchor() {
    const zero = AnchorRect(left: 0, top: 0, right: 0, bottom: 0);
    final DocumentLayout? layout =
        _docLayoutKey.currentState as DocumentLayout?;
    if (layout == null) return zero;
    final selection = _composer.selection;
    if (selection == null) return zero;
    final rect = layout.getRectForPosition(selection.extent);
    if (rect == null) return zero;
    return anchorRectFromRect(rect);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          // M1729 wire-up: top-bar IconButtons + trailing
          // PopupMenuButton kebab, driven by the M1727 partition.
          // Nested BlocBuilders gate the whole row on
          // `SyncBloc.isAuthed` (the outer one) + `EditorBloc`'s
          // frontmatter probe via [hasFormsFrontmatter] (the inner
          // one, M1741 D-fp19). Both `buildWhen` clauses narrow
          // rebuilds so a body-only EditorBloc emission doesn't
          // bounce the AppBar.
          BlocBuilder<SyncBloc, SyncState>(
            buildWhen: (prev, next) => prev.isAuthed != next.isAuthed,
            builder: (context, syncState) {
              return BlocBuilder<EditorBloc, EditorState>(
                buildWhen: (prev, next) {
                  final p = prev is EditorLoaded &&
                      hasFormsFrontmatter(prev.page.frontmatter);
                  final n = next is EditorLoaded &&
                      hasFormsFrontmatter(next.page.frontmatter);
                  return p != n;
                },
                builder: (context, editorState) {
                  final isFormBearing = editorState is EditorLoaded &&
                      hasFormsFrontmatter(editorState.page.frontmatter);
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final action in editorBetaTopBarActions(
                        isAuthed: syncState.isAuthed,
                        isFormBearing: isFormBearing,
                      ))
                        _iconButtonFor(action),
                      _kebabFor(
                        isAuthed: syncState.isAuthed,
                        isFormBearing: isFormBearing,
                      ),
                    ],
                  );
                },
              );
            },
          ),
          // BETA badge sits outside the BlocBuilder above so a SyncBloc
          // state change can't accidentally remount it. The kebab
          // (`_kebabFor`) holds the 8 secondary D-fp ports
          // (copyLink/copyUlid/copyPath/duplicate/reveal/rename/
          // publishToggle/pageHistory); the top-bar IconButtons hold
          // the 4 most-frequent + destructive (pullFromServer/
          // findInPage/share/moveToTrash).
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              child: Text(
                'BETA',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      // D23 slice 2g-a (M1537): wrap the SuperEditor in a Stack so the
      // SlashMenuOverlay can paint on top of the document, positioned by
      // the cubit's anchorRect. The overlay's onPick handler is a stub
      // (`dismiss + log`) for now — slice 2g-b adds the
      // selection-splice command that mutates the document.
      //
      // D-fp4 slice 3b (M1634): wrap the Stack in a Column so the
      // FindBar can attach below the editor when active. Stack stays
      // inside an Expanded so it fills the remaining body height.
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Listener(
                  onPointerDown: _onPointerDown,
                  child: SuperEditor(
                    editor: _editor,
                    documentLayoutKey: _docLayoutKey,
                    // D24a slice 2 (M1570): prepend the block-reorder shortcut so
                    // Cmd+Shift+ArrowUp/Down moves the active block before
                    // super_editor's default arrow-key selection-move fires.
                    keyboardActions: [
                      // D-fp4 slice 4b (M1638): Cmd+F / ⌘G / ⌘⇧G / Esc
                      // routed to the FindBar state. Prepended so Cmd+F
                      // is not swallowed by super_editor's default
                      // text-input pipeline.
                      _findInPageKeyboardAction,
                      blockReorderKeyboardAction,
                      blockDuplicateKeyboardAction,
                      // D25 slice 5b (M1606 + M1607 DI-04 fix-forward):
                      // named-method handlers so the cubit lookup happens
                      // inside the callback body, not in the closure literal
                      // inside `build` (DI-04). Reorder + duplicate stay
                      // single-block in v1 (non-contiguous semantics
                      // deferred).
                      _multiBlockDeleteAction,
                      _multiHeadingConversionAction,
                      _multiBlockConversionAction,
                      ...defaultKeyboardActions,
                    ],
                  ),
                ),
                // D25 slice 4a (M1600): paint the Notion-style multi-block
                // selection highlight behind the document content. Gesture
                // wiring to actually mutate the cubit ships in slice 4b.
                BlockSelectionOverlay(rectForNode: _rectForBlockNode),
                SlashMenuOverlay(
                  onPick: _onSlashEntryPicked,
                  onDismiss: () => context.read<SlashMenuCubit>().dismiss(),
                ),
              ],
            ),
          ),
          if (_findBarVisible)
            FindBar(
              controller: _findController,
              focusNode: _findFocusNode,
              matches: _findCursor.count,
              cursor: _findCursor.isEmpty ? 0 : _findCursor.index + 1,
              onChanged: _onFindQueryChanged,
              onPrev: _onFindPrev,
              onNext: _onFindNext,
              onClose: _toggleFindBar,
            ),
        ],
      ),
    );
  }

  /// Strip the typed `/query` from the document, insert the entry's
  /// snippet at the trigger offset, dismiss the menu, and reset the
  /// session. D23 slice 2g-b (M1539).
  ///
  /// Only `SlashAction.insertSnippet` without `linePrefix` is implemented
  /// — other actions (pickImage / pickFile / convert-in-place) close the
  /// menu without mutating the document; follow-up slices wire them.
  void _onSlashEntryPicked(SlashEntry entry) {
    final cubit = context.read<SlashMenuCubit>();
    final triggerGlobal = cubit.state.triggerOffset;
    final selection = _composer.selection;
    // Reset trigger state BEFORE mutating the document — same lesson as
    // source_view's M-era splice (see comment at source_view.dart:822).
    cubit.dismiss();
    _session.reset();

    if (selection == null || !selection.isCollapsed) return;
    final extent = selection.extent;
    final localPosition = extent.nodePosition;
    if (localPosition is! TextNodePosition) return;
    final localCaret = localPosition.offset;

    // Project the global caret back to local-node coords via the same
    // helper that produced the global offset on the trigger fire.
    final snapshot = plainTextAndCaret(doc: _doc, composer: _composer);
    final triggerLocal = localCaret - (snapshot.caret - triggerGlobal);
    if (triggerLocal < 0) return; // Same-node invariant — guard defensively.

    final nodeId = extent.nodeId;
    final triggerPos = DocumentPosition(
      nodeId: nodeId,
      nodePosition: TextNodePosition(offset: triggerLocal),
    );

    // Async picker actions branch off here: strip `/query` first, then
    // delegate to the async helper. The helper inserts an ImageNode (or
    // file-attachment paragraph) after the current node once the picker
    // resolves. Fire-and-forget — errors land in the catch and surface
    // via debug logs; no toast yet (TS-01 carry-forward).
    if (entry.action == SlashAction.pickImage ||
        entry.action == SlashAction.pickFile) {
      _editor.execute([
        DeleteContentRequest(
          documentRange: DocumentRange(start: triggerPos, end: extent),
        ),
      ]);
      unawaited(_runPickerAction(entry, nodeId));
      return;
    }
    if (entry.action != SlashAction.insertSnippet) {
      // Remaining variants (insertDailyNoteLink, insertToday, etc.) are
      // deferred to a follow-up slice — they touch DailyNote scaffolding
      // beyond the D23 scope.
      return;
    }

    // Build the request list. First request always strips `/query`.
    // Second request varies by entry.linePrefix:
    //   linePrefix == null              → InsertTextRequest (snippet)
    //   "# " | "## " | "### " | "> "    → ChangeParagraphBlockTypeRequest
    //   "- " | "1. "                    → ConvertParagraphToListItemRequest
    //   "- [ ] "                        → ConvertParagraphToTaskRequest
    // Unmappable linePrefix → delete-only (no-op insert).
    final prefix = entry.linePrefix;
    final blockType = prefix == null ? null : blockTypeForLinePrefix(prefix);
    final listType = prefix == null ? null : listItemTypeForLinePrefix(prefix);
    final isTask = prefix != null && isTaskLinePrefix(prefix);
    _editor.execute([
      DeleteContentRequest(
        documentRange: DocumentRange(start: triggerPos, end: extent),
      ),
      if (blockType != null)
        ChangeParagraphBlockTypeRequest(nodeId: nodeId, blockType: blockType)
      else if (listType != null)
        ConvertParagraphToListItemRequest(nodeId: nodeId, type: listType)
      else if (isTask)
        ConvertParagraphToTaskRequest(nodeId: nodeId)
      else if (prefix == null)
        InsertTextRequest(
          documentPosition: triggerPos,
          textToInsert: entry.snippet,
          attributions: const {},
        ),
    ]);
  }

  /// D23 slice 2g-e (M1545) — open a file_picker, copy the result into
  /// the vault via [AttachmentWriter], and insert an `ImageNode` (or a
  /// file-attachment ParagraphNode for `pickFile`) immediately after
  /// [triggerNodeId]. Failures are swallowed silently — the in-app
  /// toast surface for EditorBetaPage hasn't landed yet (TS-01 carry-
  /// forward).
  Future<void> _runPickerAction(SlashEntry entry, String triggerNodeId) async {
    final vault = context.read<VaultBloc>().state;
    if (vault is! VaultLoaded) return;

    final result = await FilePicker.platform.pickFiles(
      type: entry.action == SlashAction.pickImage
          ? FileType.image
          : FileType.any,
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.first;
    if (picked.path == null) return;

    final String relpath;
    try {
      relpath = await attachmentWriter.copy(
        source: File(picked.path!),
        vaultRoot: Directory(vault.rootPath),
      );
    } on Object {
      return;
    }

    if (!mounted) return;
    // Find the trigger node's index so the new media block lands right
    // after it. Defensive: if the node was removed concurrently, fall
    // back to appending at the end.
    final nodes = _doc.toList();
    final triggerIndex = nodes.indexWhere((n) => n.id == triggerNodeId);
    final insertIndex = triggerIndex < 0 ? nodes.length : triggerIndex + 1;

    final newNode = entry.action == SlashAction.pickImage
        ? ImageNode(
            id: Editor.createNodeId(),
            imageUrl: relpath,
            altText: 'image',
          )
        : ParagraphNode(
            id: Editor.createNodeId(),
            text: AttributedText('![${picked.name}]($relpath)'),
            metadata: {
              'blockType': fileAttachmentAttribution,
              'label': picked.name,
              'path': relpath,
            },
          );
    _editor.execute([
      InsertNodeAtIndexRequest(nodeIndex: insertIndex, newNode: newNode),
    ]);
  }
}
