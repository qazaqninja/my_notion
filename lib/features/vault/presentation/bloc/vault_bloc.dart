import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/db/quill_database.dart' hide Page;
import '../../../../core/ulid/ulid_generator.dart';
import '../../data/indexer.dart';
import '../../data/vault_watcher.dart';
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
      emit(VaultLoaded(
        rootPath: e.path,
        tree: tree,
        expandedFolders: _expandTopLevel(tree),
        pageCount: count,
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

  Future<void> _onCreatePage(CreatePage e, Emitter<VaultState> emit) async {
    if (state is! VaultLoaded) return;
    final loaded = state as VaultLoaded;
    final root = Directory(loaded.rootPath);
    final ulid = _ulids.generate();
    final safe = _safeFileName(e.title);
    final relativePath = e.folderPath.isEmpty ? '$safe.md' : p.join(e.folderPath, '$safe.md');
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

  String _safeFileName(String title) {
    final stripped = title
        .replaceAll(RegExp(r'[\\/<>:"|?*]+'), '-')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
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
          nodes.add(VaultFile(name: name, relativePath: rel, ulid: ulid));
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
