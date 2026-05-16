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
import '../bloc/editor_bloc.dart';
import '../bloc/editor_event.dart';
import '../bloc/editor_state.dart';

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
    return BlocProvider<EditorBloc>(
      key: ValueKey('beta-$ulid'),
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

  @override
  void initState() {
    super.initState();
    _doc = _serializer.markdownToDocument(widget.body);
    _composer = MutableDocumentComposer();
    _editor = createDefaultDocumentEditor(
      document: _doc,
      composer: _composer,
    );
  }

  @override
  void dispose() {
    _composer.dispose();
    _doc.dispose();
    super.dispose();
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
