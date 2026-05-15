import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:drift/drift.dart' show Value;

import '../../../../core/db/quill_database.dart' hide Page;
import '../../../../core/markdown/frontmatter_icon.dart';
import '../../../../core/ulid/ulid_generator.dart';
import '../../data/indexer.dart';
import '../../data/vault_watcher.dart';
import '../../data/workspace_config.dart';
import '../../domain/entities/frontmatter.dart';
import '../../domain/entities/frontmatter_entry.dart';
import '../../domain/entities/page.dart';
import '../../domain/entities/vault_tree.dart';
import '../../domain/repositories/vault_repository.dart';
import 'vault_event.dart';
import 'vault_state.dart';

class VaultBloc extends Bloc<VaultEvent, VaultState> {
  VaultBloc({
    required VaultRepository repo,
    required Indexer indexer,
    required QuillDatabase db,
    VaultWatcher? watcher,
    UlidGenerator? ulids,
  })  : _repo = repo,
        _indexer = indexer,
        _db = db,
        _watcher = watcher ?? VaultWatcher(),
        _ulids = ulids ?? const UlidGenerator(),
        super(const VaultInitial()) {
    on<PickVault>(_onPick);
    on<LoadFromPath>(_onLoad);
    on<ToggleFolder>(_onToggle);
    on<ReindexVault>(_onReindex);
    on<RefreshFromDisk>(_onRefresh);
    on<CreatePage>(_onCreatePage);
    on<MoveToTrash>(_onMoveToTrash);
    on<DuplicatePage>(_onDuplicate);
    on<ToggleFavorite>(_onToggleFavorite);
    on<MovePage>(_onMovePage);
    on<RenamePage>(_onRenamePage);
    on<CreateFolder>(_onCreateFolder);
    on<CloseVault>(_onCloseVault);
    _watchSub = _watcher.changes.listen((_) => add(const RefreshFromDisk()));
  }

  final VaultRepository _repo;
  final Indexer _indexer;
  final QuillDatabase _db;
  final UlidGenerator _ulids;
  final VaultWatcher _watcher;
  StreamSubscription<void>? _watchSub;

  @override
  Future<void> close() async {
    await _watchSub?.cancel();
    await _watcher.dispose();
    return super.close();
  }

  static const _prefVaultPath = 'vault.path';
  static const _prefVaultRecent = 'vault.recent';

  Future<void> _onPick(PickVault e, Emitter<VaultState> emit) async {
    emit(const VaultPicking());
    final selected = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose your vault folder',
    );
    if (selected == null) {
      emit(const VaultInitial());
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefVaultPath, selected);
    // Recent list: dedupe by string, prepend the new pick, cap at 5.
    final recent = prefs.getStringList(_prefVaultRecent) ?? const <String>[];
    final next = [
      selected,
      ...recent.where((p) => p != selected),
    ].take(5).toList();
    await prefs.setStringList(_prefVaultRecent, next);
    add(LoadFromPath(selected));
  }

  Future<void> _onLoad(LoadFromPath e, Emitter<VaultState> emit) async {
    final dir = Directory(e.path);
    if (!dir.existsSync()) {
      emit(VaultError('Vault not found: ${e.path}'));
      return;
    }
    emit(VaultLoading(rootPath: e.path));
    try {
      await _indexer.reindex(dir);
      final tree = await _buildTree(dir);
      final count = (await _db.select(_db.pages).get()).length;
      final workspace = await WorkspaceConfig.load(dir);
      emit(VaultLoaded(
        rootPath: e.path,
        tree: tree,
        expandedFolders: _expandTopLevel(tree),
        pageCount: count,
        workspace: workspace,
      ));
      // (Re-)start the watcher pointed at the freshly-loaded vault.
      await _watcher.watch(dir);
    } catch (err, _) {
      // If we hit a PathAccessException during an auto-restore, the saved
      // path is no longer accessible to the sandbox (the security-scoped
      // bookmark didn't survive). Clear it and fall back to the picker
      // silently rather than nagging with a stale error.
      if (_isAutoRestoring && err.toString().contains('PathAccessException')) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_prefVaultPath);
        emit(const VaultInitial());
      } else {
        emit(VaultError('Failed to index: $err'));
      }
    } finally {
      _isAutoRestoring = false;
    }
  }

  bool _isAutoRestoring = false;

  Future<void> _onToggle(ToggleFolder e, Emitter<VaultState> emit) async {
    if (state is! VaultLoaded) return;
    final loaded = state as VaultLoaded;
    final next = Set<String>.of(loaded.expandedFolders);
    if (next.contains(e.relativePath)) {
      next.remove(e.relativePath);
    } else {
      next.add(e.relativePath);
    }
    emit(loaded.copyWith(expandedFolders: next));
  }

  Future<void> _onReindex(ReindexVault e, Emitter<VaultState> emit) async {
    if (state is! VaultLoaded) return;
    final loaded = state as VaultLoaded;
    add(LoadFromPath(loaded.rootPath));
  }

  Future<void> _onCloseVault(CloseVault e, Emitter<VaultState> emit) async {
    await _watcher.stop();
    await _indexer.clearAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefVaultPath);
    emit(const VaultInitial());
  }

  Future<void> _onCreatePage(CreatePage e, Emitter<VaultState> emit) async {
    if (state is! VaultLoaded) return;
    final loaded = state as VaultLoaded;
    final root = Directory(loaded.rootPath);
    final ulid = _ulids.generate();
    final safe = _safeFileName(e.title);
    final relativePath = e.folderPath.isEmpty ? '$safe.md' : p.join(e.folderPath, '$safe.md');
    final today = DateTime.now();
    final iso =
        '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final author = loaded.workspace.currentUserName;
    final page = Page(
      ulid: ulid,
      relativePath: relativePath,
      title: e.title,
      frontmatter: Frontmatter(entries: [
        FrontmatterEntry(
          key: 'id',
          rawScalar: ulid,
          type: FrontmatterType.ulid,
          value: ulid,
        ),
        FrontmatterEntry(
          key: 'title',
          rawScalar: e.title,
          type: FrontmatterType.text,
          value: e.title,
        ),
        FrontmatterEntry(
          key: 'created_at',
          rawScalar: iso,
          type: FrontmatterType.date,
          value: iso,
        ),
        if (author != null && author.isNotEmpty)
          FrontmatterEntry(
            key: 'created_by',
            rawScalar: author,
            type: FrontmatterType.text,
            value: author,
          ),
      ]),
      body: '',
      mtimeMs: DateTime.now().millisecondsSinceEpoch,
    );
    try {
      await _repo.writePage(page, root: root);
      await _indexer.upsertPage(page);
      final tree = await _buildTree(root);
      final count = (await _db.select(_db.pages).get()).length;
      emit(loaded.copyWith(tree: tree, pageCount: count));
      e.onCreated?.call(ulid);
    } catch (err) {
      emit(VaultError('Create failed: $err'));
      emit(loaded);
    }
  }

  Future<void> _onMoveToTrash(MoveToTrash e, Emitter<VaultState> emit) async {
    if (state is! VaultLoaded) return;
    final loaded = state as VaultLoaded;
    final row = await (_db.select(_db.pages)..where((p) => p.ulid.equals(e.ulid)))
        .getSingleOrNull();
    if (row == null) return;
    final root = Directory(loaded.rootPath);
    final src = File(p.join(root.path, row.relativePath));
    if (!await src.exists()) return;
    try {
      final now = DateTime.now();
      final bucket =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';
      final trashDir = Directory(p.join(root.path, '.trash', bucket));
      await trashDir.create(recursive: true);
      // Preserve original basename; suffix with timestamp if it collides.
      final origName = p.basename(row.relativePath);
      var target = File(p.join(trashDir.path, origName));
      if (await target.exists()) {
        final stem = p.basenameWithoutExtension(origName);
        final ext = p.extension(origName);
        target = File(p.join(trashDir.path,
            '$stem-${now.millisecondsSinceEpoch}$ext'));
      }
      await src.rename(target.path);
      // Drop the row from Drift (and its outgoing relations).
      await (_db.delete(_db.relations)..where((r) => r.fromUlid.equals(e.ulid))).go();
      await (_db.delete(_db.pages)..where((p) => p.ulid.equals(e.ulid))).go();
      final tree = await _buildTree(root);
      final count = (await _db.select(_db.pages).get()).length;
      emit(loaded.copyWith(tree: tree, pageCount: count));
    } catch (err) {
      emit(VaultError('Move to trash failed: $err'));
      emit(loaded);
    }
  }

  Future<void> _onDuplicate(DuplicatePage e, Emitter<VaultState> emit) async {
    if (state is! VaultLoaded) return;
    final loaded = state as VaultLoaded;
    final row = await (_db.select(_db.pages)..where((p) => p.ulid.equals(e.ulid)))
        .getSingleOrNull();
    if (row == null) return;
    final root = Directory(loaded.rootPath);
    final src = await _repo.readPage(row.relativePath, root: root);
    final newUlid = _ulids.generate();
    final newTitle = e.titleOverride ?? '${src.title} (copy)';

    // Replace id + title entries; keep others.
    final entries = <FrontmatterEntry>[];
    for (final ent in src.frontmatter.entries) {
      if (ent.key == 'id') {
        entries.add(FrontmatterEntry(
          key: 'id',
          rawScalar: newUlid,
          type: FrontmatterType.ulid,
          value: newUlid,
        ));
      } else if (ent.key == 'title') {
        entries.add(FrontmatterEntry(
          key: 'title',
          rawScalar: newTitle,
          type: FrontmatterType.text,
          value: newTitle,
        ));
      } else {
        entries.add(ent);
      }
    }
    if (!entries.any((x) => x.key == 'id')) {
      entries.insert(
        0,
        FrontmatterEntry(
          key: 'id',
          rawScalar: newUlid,
          type: FrontmatterType.ulid,
          value: newUlid,
        ),
      );
    }
    if (!entries.any((x) => x.key == 'title')) {
      entries.add(FrontmatterEntry(
        key: 'title',
        rawScalar: newTitle,
        type: FrontmatterType.text,
        value: newTitle,
      ));
    }

    final folder = e.targetFolder ?? p.dirname(src.relativePath);
    final fileName = _safeFileName(newTitle);
    final relativePath =
        folder.isEmpty || folder == '.' ? '$fileName.md' : p.join(folder, '$fileName.md');
    final next = Page(
      ulid: newUlid,
      relativePath: relativePath,
      title: newTitle,
      frontmatter: Frontmatter(entries: entries),
      body: src.body,
      mtimeMs: DateTime.now().millisecondsSinceEpoch,
    );
    try {
      await _repo.writePage(next, root: root);
      await _indexer.upsertPage(next);
      // If the source was inside a database folder, the copy is too —
      // preserve database_id.
      if (row.databaseId != null) {
        await (_db.update(_db.pages)..where((row) => row.ulid.equals(newUlid)))
            .write(PagesCompanion(databaseId: Value(row.databaseId)));
      }
      final tree = await _buildTree(root);
      final count = (await _db.select(_db.pages).get()).length;
      emit(loaded.copyWith(tree: tree, pageCount: count));
      e.onCreated?.call(newUlid);
    } catch (err) {
      emit(VaultError('Duplicate failed: $err'));
      emit(loaded);
    }
  }

  Future<void> _onToggleFavorite(
      ToggleFavorite e, Emitter<VaultState> emit) async {
    if (state is! VaultLoaded) return;
    final loaded = state as VaultLoaded;
    final list = [...loaded.workspace.favorites];
    if (list.contains(e.ulid)) {
      list.remove(e.ulid);
    } else {
      list.add(e.ulid);
    }
    final next = loaded.workspace.copyWith(favorites: list);
    try {
      await next.save(Directory(loaded.rootPath));
      emit(loaded.copyWith(workspace: next));
    } catch (err) {
      emit(VaultError('Favorites write failed: $err'));
      emit(loaded);
    }
  }

  Future<void> _onCreateFolder(CreateFolder e, Emitter<VaultState> emit) async {
    if (state is! VaultLoaded) return;
    final loaded = state as VaultLoaded;
    final safe = e.name
        .trim()
        .replaceAll(RegExp(r'[\\/<>:"|?*]+'), '-')
        .replaceAll(RegExp(r'\s+'), ' ');
    if (safe.isEmpty || safe == '.' || safe == '..') return;
    final rel = e.parentFolder.isEmpty ? safe : p.join(e.parentFolder, safe);
    final dir = Directory(p.join(loaded.rootPath, rel));
    if (await dir.exists()) {
      emit(VaultError('Folder "$rel" already exists.'));
      emit(loaded);
      return;
    }
    try {
      await dir.create(recursive: true);
      final tree = await _buildTree(Directory(loaded.rootPath));
      emit(loaded.copyWith(tree: tree));
    } catch (err) {
      emit(VaultError('Create folder failed: $err'));
      emit(loaded);
    }
  }

  Future<void> _onRenamePage(RenamePage e, Emitter<VaultState> emit) async {
    if (state is! VaultLoaded) return;
    final loaded = state as VaultLoaded;
    final row = await (_db.select(_db.pages)..where((p) => p.ulid.equals(e.ulid)))
        .getSingleOrNull();
    if (row == null) return;
    final safe = _safeFileName(e.newBasename);
    if (safe.isEmpty) return;
    final root = Directory(loaded.rootPath);
    final folder = p.dirname(row.relativePath);
    final folderRel = folder == '.' ? '' : folder;
    final currentBase = p.basenameWithoutExtension(row.relativePath);
    if (currentBase == safe) return;
    final newRel = folderRel.isEmpty ? '$safe.md' : p.join(folderRel, '$safe.md');
    final src = File(p.join(root.path, row.relativePath));
    final dest = File(p.join(root.path, newRel));
    if (!await src.exists()) return;
    if (await dest.exists()) {
      emit(VaultError(
          'Rename skipped: $safe.md already exists in the same folder.'));
      emit(loaded);
      return;
    }
    try {
      await src.rename(dest.path);
      final updated = await _repo.readPage(newRel, root: root);
      await _indexer.upsertPage(updated);
      final tree = await _buildTree(root);
      final count = (await _db.select(_db.pages).get()).length;
      emit(loaded.copyWith(tree: tree, pageCount: count));
    } catch (err) {
      emit(VaultError('Rename failed: $err'));
      emit(loaded);
    }
  }

  Future<void> _onMovePage(MovePage e, Emitter<VaultState> emit) async {
    if (state is! VaultLoaded) return;
    final loaded = state as VaultLoaded;
    final row = await (_db.select(_db.pages)..where((p) => p.ulid.equals(e.ulid)))
        .getSingleOrNull();
    if (row == null) return;
    final root = Directory(loaded.rootPath);
    final currentFolder = p.dirname(row.relativePath);
    final normalisedTarget = e.targetFolder == '.' ? '' : e.targetFolder;
    final normalisedCurrent = currentFolder == '.' ? '' : currentFolder;
    if (normalisedTarget == normalisedCurrent) return;
    final basename = p.basename(row.relativePath);
    final newRel = normalisedTarget.isEmpty
        ? basename
        : p.join(normalisedTarget, basename);
    final src = File(p.join(root.path, row.relativePath));
    final dest = File(p.join(root.path, newRel));
    if (!await src.exists()) return;
    if (await dest.exists()) {
      emit(VaultError(
          'Move skipped: ${dest.path.split('/').last} already exists in target folder.'));
      emit(loaded);
      return;
    }
    try {
      await dest.parent.create(recursive: true);
      await src.rename(dest.path);
      // Update drift's relative_path and re-read the page so the tree
      // can pick it up. The frontmatter doesn't change, and the ULID
      // stays the same — wikilinks remain valid.
      final updated = await _repo.readPage(newRel, root: root);
      await _indexer.upsertPage(updated);
      final tree = await _buildTree(root);
      final count = (await _db.select(_db.pages).get()).length;
      emit(loaded.copyWith(tree: tree, pageCount: count));
    } catch (err) {
      emit(VaultError('Move failed: $err'));
      emit(loaded);
    }
  }

  String _safeFileName(String title) {
    var stripped = title
        .replaceAll(RegExp(r'[\\/<>:"|?*]+'), '-')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    // Tolerate users who typed the `.md` extension — strip it so the
    // caller can re-append cleanly and we don't end up with foo.md.md.
    if (stripped.toLowerCase().endsWith('.md')) {
      stripped = stripped.substring(0, stripped.length - 3).trim();
    }
    return stripped.isEmpty ? 'Untitled' : stripped;
  }

  /// In-place refresh. Unlike [LoadFromPath], does NOT emit VaultLoading,
  /// keeps expandedFolders, and is robust to transient FS errors (e.g. a
  /// half-rendered rename event from the watcher).
  Future<void> _onRefresh(RefreshFromDisk e, Emitter<VaultState> emit) async {
    if (state is! VaultLoaded) return;
    final loaded = state as VaultLoaded;
    final dir = Directory(loaded.rootPath);
    if (!dir.existsSync()) return;
    try {
      await _indexer.reindex(dir);
      final tree = await _buildTree(dir);
      final count = (await _db.select(_db.pages).get()).length;
      emit(loaded.copyWith(tree: tree, pageCount: count));
    } catch (_) {
      // Swallow — the next watcher tick (or manual reindex) will retry.
    }
  }

  /// Tries to restore the last-opened vault. Returns false if none stored.
  /// On failure, the saved path is cleared and the picker is shown again
  /// (rather than displaying a stale error from an inaccessible path).
  Future<bool> tryRestore() async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getString(_prefVaultPath);
    if (last == null || last.isEmpty) return false;
    if (!Directory(last).existsSync()) {
      await prefs.remove(_prefVaultPath);
      return false;
    }
    _isAutoRestoring = true;
    add(LoadFromPath(last));
    return true;
  }

  /// Build the on-disk tree by walking once and collecting page ULIDs from
  /// the freshly-indexed Drift cache (cheap lookup by relativePath).
  Future<VaultTree> _buildTree(Directory root) async {
    final pageRows = await _db.select(_db.pages).get();
    final ulidByPath = {for (final p in pageRows) p.relativePath: p.ulid};
    // Collect frontmatter `icon:` values for surfacing in the sidebar.
    final iconByPath = <String, String>{};
    for (final row in pageRows) {
      final emoji = emojiFromFrontmatterJson(row.frontmatterJson);
      if (emoji != null) iconByPath[row.relativePath] = emoji;
    }

    Future<List<VaultNode>> walk(Directory dir) async {
      final entries = dir.listSync()..sort((a, b) {
        final ad = a is Directory;
        final bd = b is Directory;
        if (ad != bd) return ad ? -1 : 1; // folders first
        return p.basename(a.path).toLowerCase().compareTo(p.basename(b.path).toLowerCase());
      });
      final nodes = <VaultNode>[];
      for (final e in entries) {
        final name = p.basename(e.path);
        if (name.startsWith('.')) continue;
        if (const {'node_modules', '_meta'}.contains(name)) continue;
        final rel = p.relative(e.path, from: root.path);
        if (e is Directory) {
          final children = await walk(e);
          // Only include folders with content (or always — the design shows
          // empty folders too, so keep them).
          nodes.add(VaultFolder(name: name, relativePath: rel, children: children));
        } else if (e is File && p.extension(e.path) == '.md') {
          final ulid = ulidByPath[rel] ?? '';
          nodes.add(VaultFile(
            name: name,
            relativePath: rel,
            ulid: ulid,
            icon: iconByPath[rel],
          ));
        }
      }
      return nodes;
    }

    final topLevel = await walk(root);
    return VaultTree(topLevel: topLevel);
  }

  Set<String> _expandTopLevel(VaultTree tree) {
    return {
      for (final n in tree.topLevel)
        if (n is VaultFolder) n.relativePath,
    };
  }
}
