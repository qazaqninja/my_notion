import 'dart:async';
import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/db/quill_database.dart' hide Page;
import '../../../vault/data/indexer.dart';
import '../../../vault/domain/repositories/vault_repository.dart';
import 'editor_event.dart';
import 'editor_state.dart';

class EditorBloc extends Bloc<EditorEvent, EditorState> {
  EditorBloc({
    required VaultRepository repo,
    required Indexer indexer,
    required QuillDatabase db,
  })  : _repo = repo,
        _indexer = indexer,
        _db = db,
        super(const EditorIdle()) {
    on<OpenEditor>(_onOpen);
    on<EditBody>(_onEditBody);
    on<ToggleEditorMode>(_onToggleMode);
    on<SaveNow>(_onSave);
  }

  final VaultRepository _repo;
  final Indexer _indexer;
  final QuillDatabase _db;

  Timer? _saveDebounce;
  static const _saveDebounceDuration = Duration(milliseconds: 500);

  /// The vault root must be set before opening — we read it from drift via
  /// the relative path stored on the page row.
  Directory? _vaultRoot;
  void setVaultRoot(Directory root) => _vaultRoot = root;

  Future<void> _onOpen(OpenEditor e, Emitter<EditorState> emit) async {
    emit(EditorLoading(e.ulid));
    try {
      final row = await (_db.select(_db.pages)..where((p) => p.ulid.equals(e.ulid)))
          .getSingleOrNull();
      if (row == null) {
        emit(EditorError('Page not found: ${e.ulid}'));
        return;
      }
      final root = _vaultRoot;
      if (root == null) {
        emit(const EditorError('Vault root not set'));
        return;
      }
      final page = await _repo.readPage(row.relativePath, root: root);
      emit(EditorLoaded(page: page, mode: EditorMode.rendered, dirty: false, saving: false));
    } catch (err) {
      emit(EditorError('Failed to open: $err'));
    }
  }

  Future<void> _onEditBody(EditBody e, Emitter<EditorState> emit) async {
    if (state is! EditorLoaded) return;
    final loaded = state as EditorLoaded;
    if (loaded.page.body == e.body) return;
    final updated = loaded.page.copyWith(body: e.body);
    emit(loaded.copyWith(page: updated, dirty: true));
    _scheduleSave();
  }

  Future<void> _onToggleMode(ToggleEditorMode e, Emitter<EditorState> emit) async {
    if (state is! EditorLoaded) return;
    final loaded = state as EditorLoaded;
    if (loaded.mode == e.mode) return;
    emit(loaded.copyWith(mode: e.mode));
  }

  Future<void> _onSave(SaveNow e, Emitter<EditorState> emit) async {
    if (state is! EditorLoaded) return;
    final loaded = state as EditorLoaded;
    if (!loaded.dirty || _vaultRoot == null) return;
    emit(loaded.copyWith(saving: true));
    try {
      await _repo.writePage(loaded.page, root: _vaultRoot!);
      await _indexer.upsertPage(loaded.page);
      emit(loaded.copyWith(saving: false, dirty: false));
    } catch (err) {
      emit(EditorError('Save failed: $err'));
    }
  }

  void _scheduleSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(_saveDebounceDuration, () => add(const SaveNow()));
  }

  @override
  Future<void> close() {
    _saveDebounce?.cancel();
    return super.close();
  }
}
