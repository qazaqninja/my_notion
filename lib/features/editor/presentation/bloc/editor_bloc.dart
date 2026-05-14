import 'dart:async';
import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/db/quill_database.dart' hide Page;
import '../../../../core/markdown/frontmatter_parser.dart';
import '../../../vault/data/indexer.dart';
import '../../../vault/domain/entities/frontmatter.dart';
import '../../../vault/domain/entities/frontmatter_entry.dart';
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
    on<EditFrontmatterField>(_onEditField);
    on<AddFrontmatterField>(_onAddField);
    on<RemoveFrontmatterField>(_onRemoveField);
    on<ReplaceFrontmatterYaml>(_onReplaceYaml);
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

  Future<void> _onEditField(EditFrontmatterField e, Emitter<EditorState> emit) async {
    if (state is! EditorLoaded) return;
    final loaded = state as EditorLoaded;
    final entries = loaded.page.frontmatter.entries;
    final i = entries.indexWhere((x) => x.key == e.key);
    if (i < 0) return;
    final next = List.of(entries);
    next[i] = e.newEntry;
    _emitFrontmatter(loaded, next, emit);
  }

  Future<void> _onAddField(AddFrontmatterField e, Emitter<EditorState> emit) async {
    if (state is! EditorLoaded) return;
    final loaded = state as EditorLoaded;
    final entries = loaded.page.frontmatter.entries;
    if (entries.any((x) => x.key == e.entry.key)) return; // duplicate key
    final next = [...entries, e.entry];
    _emitFrontmatter(loaded, next, emit);
  }

  Future<void> _onRemoveField(RemoveFrontmatterField e, Emitter<EditorState> emit) async {
    if (state is! EditorLoaded) return;
    if (e.key == 'id') return; // protected
    final loaded = state as EditorLoaded;
    final next = [
      for (final x in loaded.page.frontmatter.entries)
        if (x.key != e.key) x,
    ];
    if (next.length == loaded.page.frontmatter.entries.length) return;
    _emitFrontmatter(loaded, next, emit);
  }

  Future<void> _onReplaceYaml(ReplaceFrontmatterYaml e, Emitter<EditorState> emit) async {
    if (state is! EditorLoaded) return;
    final loaded = state as EditorLoaded;
    // Wrap in delimiters so the parser reuses its proven path. The body is
    // empty — we only care about the frontmatter side.
    final wrapped = '---\n${e.rawYaml.endsWith('\n') ? e.rawYaml : '${e.rawYaml}\n'}---\n';
    final parsed = FrontmatterParser.parse(wrapped);
    if (parsed.frontmatter.isEmpty && e.rawYaml.trim().isNotEmpty) {
      emit(const EditorError('Invalid YAML'));
      // Restore the previous state so the user can keep editing.
      emit(loaded);
      return;
    }
    // Preserve the page id even if the user removed it from the YAML.
    final currentId = loaded.page.frontmatter.id;
    final hasId = parsed.frontmatter.entries.any((x) => x.key == 'id');
    final entries = hasId || currentId == null
        ? parsed.frontmatter.entries
        : [
            FrontmatterEntry(
              key: 'id',
              rawScalar: currentId,
              type: FrontmatterType.ulid,
              value: currentId,
            ),
            ...parsed.frontmatter.entries,
          ];
    _emitFrontmatter(loaded, entries, emit);
  }

  void _emitFrontmatter(
    EditorLoaded loaded,
    List<FrontmatterEntry> entries,
    Emitter<EditorState> emit,
  ) {
    final fm = Frontmatter(entries: entries);
    final updated = loaded.page.copyWith(frontmatter: fm);
    emit(loaded.copyWith(page: updated, dirty: true));
    _scheduleSave();
  }

  @override
  Future<void> close() {
    _saveDebounce?.cancel();
    return super.close();
  }
}
