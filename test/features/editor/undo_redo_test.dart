/// Tests the EditorBloc's undo/redo behaviour by driving it end-to-end
/// through events on a fake repo + indexer. The save side-effect is
/// stubbed out — the test only cares about the in-memory page snapshots
/// after EditBody / UndoEdit / RedoEdit sequences.
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/core/db/quill_database.dart' hide Page;
import 'package:my_notion/core/ulid/ulid_generator.dart';
import 'package:my_notion/features/editor/presentation/bloc/editor_bloc.dart';
import 'package:my_notion/features/editor/presentation/bloc/editor_event.dart';
import 'package:my_notion/features/editor/presentation/bloc/editor_state.dart';
import 'package:my_notion/features/vault/data/indexer.dart';
import 'package:my_notion/features/vault/data/datasources/vault_fs_datasource.dart';
import 'package:my_notion/features/vault/domain/entities/frontmatter.dart';
import 'package:my_notion/features/vault/domain/entities/page.dart';
import 'package:my_notion/features/vault/domain/repositories/vault_repository.dart';

class _FakeRepo implements VaultRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  Future<void> writePage(Page page, {required Directory root}) async {}
}

class _FakeIndexer extends Indexer {
  _FakeIndexer(super.db, super.ds);
  @override
  Future<void> upsertPage(Page page) async {}
}

Page _seed({String body = 'initial body', String title = 'P'}) => Page(
      ulid: '01HX0V9R5N6E8L3P7Q8S9U2X4B',
      relativePath: 'p.md',
      title: title,
      frontmatter: Frontmatter.empty,
      body: body,
    );

EditorBloc _makeBloc() {
  final db = QuillDatabase.forTesting(NativeDatabase.memory());
  final ds = VaultFsDatasource(ulids: const UlidGenerator());
  return EditorBloc(repo: _FakeRepo(), indexer: _FakeIndexer(db, ds), db: db);
}

void main() {
  group('EditorBloc undo/redo', () {
    test('initial canUndo / canRedo are false', () {
      final bloc = _makeBloc();
      expect(bloc.canUndo, isFalse);
      expect(bloc.canRedo, isFalse);
    });

    test('EditBody pushes onto undo, makes redo empty', () async {
      final bloc = _makeBloc();
      bloc.emit(EditorLoaded(
        page: _seed(),
        mode: EditorMode.rendered,
        dirty: false,
        saving: false,
      ));
      bloc.add(const EditBody('changed body'));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(bloc.canUndo, isTrue);
      expect(bloc.canRedo, isFalse);
      expect((bloc.state as EditorLoaded).page.body, 'changed body');
    });

    test('UndoEdit restores the previous body', () async {
      final bloc = _makeBloc();
      bloc.emit(EditorLoaded(
        page: _seed(body: 'A'),
        mode: EditorMode.rendered,
        dirty: false,
        saving: false,
      ));
      bloc.add(const EditBody('B'));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      bloc.add(const UndoEdit());
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect((bloc.state as EditorLoaded).page.body, 'A');
      expect(bloc.canUndo, isFalse);
      expect(bloc.canRedo, isTrue);
    });

    test('RedoEdit re-applies the undone change', () async {
      final bloc = _makeBloc();
      bloc.emit(EditorLoaded(
        page: _seed(body: 'A'),
        mode: EditorMode.rendered,
        dirty: false,
        saving: false,
      ));
      bloc.add(const EditBody('B'));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      bloc.add(const UndoEdit());
      await Future<void>.delayed(const Duration(milliseconds: 10));
      bloc.add(const RedoEdit());
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect((bloc.state as EditorLoaded).page.body, 'B');
      expect(bloc.canUndo, isTrue);
      expect(bloc.canRedo, isFalse);
    });

    test('fresh edit after undo clears the redo stack', () async {
      final bloc = _makeBloc();
      bloc.emit(EditorLoaded(
        page: _seed(body: 'A'),
        mode: EditorMode.rendered,
        dirty: false,
        saving: false,
      ));
      bloc.add(const EditBody('B'));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      bloc.add(const UndoEdit());
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(bloc.canRedo, isTrue);
      bloc.add(const EditBody('C'));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(bloc.canRedo, isFalse);
    });

    test('UndoEdit on empty stack is a no-op', () async {
      final bloc = _makeBloc();
      bloc.emit(EditorLoaded(
        page: _seed(body: 'A'),
        mode: EditorMode.rendered,
        dirty: false,
        saving: false,
      ));
      bloc.add(const UndoEdit());
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect((bloc.state as EditorLoaded).page.body, 'A');
    });
  });
}
