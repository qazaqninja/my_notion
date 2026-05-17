import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:super_editor/super_editor.dart';

import '../../../../core/db/quill_database.dart' hide Page;
import '../../../../core/markdown/super_editor_serializer.dart';
import '../../../vault/data/indexer.dart';
import '../../../vault/domain/repositories/vault_repository.dart';
import '../../../vault/presentation/bloc/vault_bloc.dart';
import '../../../vault/presentation/bloc/vault_state.dart';
import '../../../../core/ui/anchor_rect.dart';
import '../../../../core/ui/anchor_rect_x.dart';
import '../../domain/attachment_writer.dart';
import '../bloc/editor_bloc.dart';
import '../bloc/editor_event.dart';
import '../bloc/editor_state.dart';
import '../../domain/slash_entries.dart';
import '../../domain/slash_entry_block_type.dart';
import '../controllers/bold_autoformat_reaction.dart';
import '../controllers/highlight_autoformat_reaction.dart';
import '../controllers/inline_code_autoformat_reaction.dart';
import '../controllers/italic_autoformat_reaction.dart';
import '../controllers/slash_trigger_session.dart';
import '../controllers/strike_autoformat_reaction.dart';
import '../controllers/super_editor_caret.dart';
import '../cubit/slash_menu_cubit.dart';
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
  const _BetaEditorShell({required this.title, required this.body});
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
        actions: const [
          Padding(
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
      body: Stack(
        children: [
          SuperEditor(
            editor: _editor,
            documentLayoutKey: _docLayoutKey,
          ),
          SlashMenuOverlay(
            onPick: _onSlashEntryPicked,
            onDismiss: () => context.read<SlashMenuCubit>().dismiss(),
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
