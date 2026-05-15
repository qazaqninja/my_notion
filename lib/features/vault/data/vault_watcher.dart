import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/vault_dirs.dart';

/// Watches a vault directory for external changes (editor, sync clients,
/// `mv` on the CLI). Emits debounced "something changed" pings rather than
/// per-file events — consumers reindex from disk on each tick.
///
/// Filters:
/// - Only fires for `.md`, `.database.yaml`, and directory create/rename
///   events. Other extensions and dotfiles are ignored.
/// - Skips internal app paths: the atomic-write `.tmp` siblings, paths
///   inside `.git`/`.obsidian`/`node_modules`/`_meta`/`.dart_tool`/`.idea`.
/// - Debounces bursts (multiple writes within [debounce]) into one tick.
class VaultWatcher {
  VaultWatcher({this.debounce = const Duration(milliseconds: 250)});

  final Duration debounce;
  StreamSubscription<FileSystemEvent>? _sub;
  Timer? _timer;
  Directory? _root;
  final _controller = StreamController<void>.broadcast();

  static const Set<String> _ignoredDirs = kIgnoredVaultDirs;

  /// Stream of "something changed under root" pings. One ping may
  /// represent many underlying events that arrived within [debounce].
  Stream<void> get changes => _controller.stream;

  /// Start watching [root]. Replaces any previous watch. Safe to call
  /// repeatedly with the same path; returns immediately if [root]
  /// doesn't exist.
  Future<void> watch(Directory root) async {
    await stop();
    if (!await root.exists()) return;
    _root = root;
    try {
      _sub = root
          .watch(recursive: true, events: FileSystemEvent.all)
          .listen(_onEvent, onError: (_) {});
      // ignore: avoid_catching_errors
      // UnsupportedError IS an Error subclass — but some platforms
      // (older Linux without inotify) literally throw it when
      // recursive watches aren't supported. Catching here is the
      // only way to fail open.
    } on UnsupportedError {
      // Fail open — no watcher, manual reindex only.
    }
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _timer?.cancel();
    _timer = null;
    _root = null;
  }

  Future<void> dispose() async {
    await stop();
    await _controller.close();
  }

  void _onEvent(FileSystemEvent e) {
    if (!_isRelevant(e.path)) return;
    _timer?.cancel();
    _timer = Timer(debounce, () {
      if (!_controller.isClosed) _controller.add(null);
    });
  }

  bool _isRelevant(String path) {
    // Strip the root (we're notified of root modifications whenever its
    // contents change — that's noise, the per-child events already cover it).
    if (_root != null && p.equals(path, _root!.path)) return false;
    final segments = p.split(path);
    for (final seg in segments) {
      if (_ignoredDirs.contains(seg)) return false;
    }
    final name = p.basename(path);
    if (name.endsWith('.tmp')) return false;
    // Only react to changes in markdown pages and database schemas — other
    // sidecar files (images, dotfiles, etc.) are visible on disk but don't
    // affect Drift's view of the vault.
    if (name == '.database.yaml') return true;
    return p.extension(path) == '.md';
  }
}
