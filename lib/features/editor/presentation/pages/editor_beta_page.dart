import 'dart:io';

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
import '../bloc/editor_bloc.dart';
import '../bloc/editor_event.dart';
import '../bloc/editor_state.dart';
import '../controllers/slash_trigger_session.dart';
import '../controllers/super_editor_caret.dart';
import '../cubit/slash_menu_cubit.dart';

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
  late final MutableDocument _doc;
  late final MutableDocumentComposer _composer;
  late final Editor _editor;
  late final SlashTriggerSession _session;

  @override
  void initState() {
    super.initState();
    _doc = _serializer.markdownToDocument(widget.body);
    _composer = MutableDocumentComposer();
    _editor = createDefaultDocumentEditor(
      document: _doc,
      composer: _composer,
    );
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
        anchor: const AnchorRect(left: 0, top: 0, right: 0, bottom: 0),
        triggerOffset: triggerOffset,
      ),
      onDismiss: cubit.dismiss,
      onQuery: cubit.setQuery,
    );
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
      body: SuperEditor(editor: _editor),
    );
  }
}
