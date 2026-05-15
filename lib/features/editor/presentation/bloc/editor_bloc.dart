import 'dart:async';
import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/db/quill_database.dart' hide Page;
import '../../../../core/markdown/frontmatter_parser.dart';
import '../../../vault/data/indexer.dart';
import '../../../vault/domain/entities/frontmatter.dart';
import '../../../vault/domain/entities/frontmatter_entry.dart';
import '../../../vault/domain/entities/page.dart';
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
    on<UndoEdit>(_onUndo);
    on<RedoEdit>(_onRedo);
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

  /// Optional display name of the workspace's current user. When set,
  /// `_onSave` stamps frontmatter `last_edited_by:` on every save and
  /// `created_by:` the first time the page is saved. Configured from
  /// `.quill.yaml`'s `users:` list via WorkspaceConfig.currentUserName.
  String? _currentUser;
  void setCurrentUser(String? name) => _currentUser = name;

  /// Bounded undo/redo stacks of page snapshots. Every mutating event
  /// pushes the pre-mutation page onto `_undo` and clears `_redo` so the
  /// user can't fork the history. Cap at [_undoLimit] entries so a long
  /// editing session doesn't grow without bound.
  final List<Page> _undo = <Page>[];
  final List<Page> _redo = <Page>[];
  static const _undoLimit = 50;

  void _pushUndo(Page snapshot) {
    _undo.add(snapshot);
    if (_undo.length > _undoLimit) _undo.removeAt(0);
    _redo.clear();
  }

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

  /// True when the loaded page is locked by frontmatter. Recognises:
  ///   - `locked: true` — the legacy single-flag lock.
  ///   - `permissions: read_only` / `read-only` / `locked` — the new
  ///     `permissions:` block (M170). Any other `permissions:` value
  ///     (e.g. `private`, `team_only`) is documentation-only and does
  ///     not lock the page.
  /// Locked pages reject all editing events; the UI surfaces a banner.
  static bool isLocked(EditorLoaded loaded) {
    final v = loaded.page.frontmatter.get('locked');
    if (v == true || '$v'.toLowerCase() == 'true') return true;
    final p = loaded.page.frontmatter.get('permissions');
    final ps = '$p'.trim().toLowerCase();
    return ps == 'read_only' ||
        ps == 'read-only' ||
        ps == 'readonly' ||
        ps == 'locked';
  }

  Future<void> _onEditBody(EditBody e, Emitter<EditorState> emit) async {
    if (state is! EditorLoaded) return;
    final loaded = state as EditorLoaded;
    if (isLocked(loaded)) return;
    if (loaded.page.body == e.body) return;
    _pushUndo(loaded.page);
    final updated = loaded.page.copyWith(body: e.body);
    emit(loaded.copyWith(page: updated, dirty: true));
    _scheduleSave();
  }

  Future<void> _onUndo(UndoEdit e, Emitter<EditorState> emit) async {
    if (state is! EditorLoaded || _undo.isEmpty) return;
    final loaded = state as EditorLoaded;
    if (isLocked(loaded)) return;
    final snapshot = _undo.removeLast();
    _redo.add(loaded.page);
    if (_redo.length > _undoLimit) _redo.removeAt(0);
    emit(loaded.copyWith(page: snapshot, dirty: true));
    _scheduleSave();
  }

  Future<void> _onRedo(RedoEdit e, Emitter<EditorState> emit) async {
    if (state is! EditorLoaded || _redo.isEmpty) return;
    final loaded = state as EditorLoaded;
    if (isLocked(loaded)) return;
    final snapshot = _redo.removeLast();
    _undo.add(loaded.page);
    if (_undo.length > _undoLimit) _undo.removeAt(0);
    emit(loaded.copyWith(page: snapshot, dirty: true));
    _scheduleSave();
  }

  /// True when there's an undo entry available — used by the shell to
  /// dim the keyboard-shortcut chip.
  bool get canUndo => _undo.isNotEmpty;

  /// True when redo has at least one entry available.
  bool get canRedo => _redo.isNotEmpty;

  Future<void> _onToggleMode(ToggleEditorMode e, Emitter<EditorState> emit) async {
    if (state is! EditorLoaded) return;
    final loaded = state as EditorLoaded;
    if (loaded.mode == e.mode) return;
    emit(loaded.copyWith(mode: e.mode));
  }

  Future<void> _onSave(SaveNow e, Emitter<EditorState> emit) async {
    if (state is! EditorLoaded) return;
    var loaded = state as EditorLoaded;
    if (!loaded.dirty || _vaultRoot == null) return;
    // Auto-stamp last_edited_by + created_by when a current user is known.
    final user = _currentUser;
    if (user != null && user.isNotEmpty) {
      final fm = loaded.page.frontmatter;
      final stamped = _stampAuthor(fm, user);
      if (!identical(stamped, fm)) {
        loaded = loaded.copyWith(
          page: loaded.page.copyWith(frontmatter: stamped),
        );
      }
    }
    emit(loaded.copyWith(saving: true));
    try {
      await _repo.writePage(loaded.page, root: _vaultRoot!);
      await _indexer.upsertPage(loaded.page);
      emit(loaded.copyWith(saving: false, dirty: false));
    } catch (err) {
      // Transient — emit the error so listeners can snackbar, then
      // restore the dirty loaded state so the user doesn't lose their
      // work. The "dirty" flag stays true so the next debounced save
      // tries again.
      emit(EditorError('Save failed: $err'));
      emit(loaded.copyWith(saving: false));
    }
  }

  /// Add or update `last_edited_by:` to [user]; add `created_by:` to
  /// [user] only when it is not already present (a once-stamped author
  /// should never be overwritten by another editor).
  ///
  /// Exposed publicly so author-stamping is exercisable in tests
  /// without spinning up the full bloc + filesystem.
  static Frontmatter stampAuthor(Frontmatter fm, String user) =>
      _stampAuthor(fm, user);

  static Frontmatter _stampAuthor(Frontmatter fm, String user) {
    final now = DateTime.now();
    final iso =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final hasCreatedBy =
        fm.entries.any((x) => x.key == 'created_by' && '${x.value}'.isNotEmpty);
    final next = <FrontmatterEntry>[];
    var replacedAuthor = false;
    var replacedDate = false;
    for (final e in fm.entries) {
      if (e.key == 'last_edited_by') {
        next.add(FrontmatterEntry(
          key: 'last_edited_by',
          rawScalar: user,
          type: FrontmatterType.text,
          value: user,
        ));
        replacedAuthor = true;
      } else if (e.key == 'last_edited_at') {
        next.add(FrontmatterEntry(
          key: 'last_edited_at',
          rawScalar: iso,
          type: FrontmatterType.date,
          value: iso,
        ));
        replacedDate = true;
      } else {
        next.add(e);
      }
    }
    if (!replacedAuthor) {
      next.add(FrontmatterEntry(
        key: 'last_edited_by',
        rawScalar: user,
        type: FrontmatterType.text,
        value: user,
      ));
    }
    if (!replacedDate) {
      next.add(FrontmatterEntry(
        key: 'last_edited_at',
        rawScalar: iso,
        type: FrontmatterType.date,
        value: iso,
      ));
    }
    if (!hasCreatedBy) {
      next.add(FrontmatterEntry(
        key: 'created_by',
        rawScalar: user,
        type: FrontmatterType.text,
        value: user,
      ));
    }
    return Frontmatter(entries: next);
  }

  void _scheduleSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(_saveDebounceDuration, () => add(const SaveNow()));
  }

  Future<void> _onEditField(EditFrontmatterField e, Emitter<EditorState> emit) async {
    if (state is! EditorLoaded) return;
    final loaded = state as EditorLoaded;
    // Allow `locked` itself to be toggled — otherwise users can't unlock.
    if (isLocked(loaded) && e.key != 'locked' && e.key != 'permissions') {
      return;
    }
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
    if (isLocked(loaded) &&
        e.entry.key != 'locked' &&
        e.entry.key != 'permissions') {
      return;
    }
    final entries = loaded.page.frontmatter.entries;
    if (entries.any((x) => x.key == e.entry.key)) return; // duplicate key
    final next = [...entries, e.entry];
    _emitFrontmatter(loaded, next, emit);
  }

  Future<void> _onRemoveField(RemoveFrontmatterField e, Emitter<EditorState> emit) async {
    if (state is! EditorLoaded) return;
    if (e.key == 'id') return; // protected
    final loaded = state as EditorLoaded;
    if (isLocked(loaded) && e.key != 'locked' && e.key != 'permissions') {
      return;
    }
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
    if (isLocked(loaded)) return;
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
    _pushUndo(loaded.page);
    final fm = Frontmatter(entries: entries);
    // Keep Page.title in sync with frontmatter['title'] so the in-memory
    // entity matches what a fresh read would produce.
    final titleEntry = entries.cast<FrontmatterEntry?>().firstWhere(
          (e) => e!.key == 'title',
          orElse: () => null,
        );
    final nextTitle = titleEntry?.value is String
        ? titleEntry!.value as String
        : loaded.page.title;
    final updated = loaded.page.copyWith(frontmatter: fm, title: nextTitle);
    emit(loaded.copyWith(page: updated, dirty: true));
    _scheduleSave();
  }

  @override
  Future<void> close() {
    _saveDebounce?.cancel();
    return super.close();
  }
}
