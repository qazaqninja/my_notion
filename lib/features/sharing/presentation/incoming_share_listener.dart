import 'dart:async';
import 'dart:io';

import '../../vault/data/quick_capture.dart';
import '../domain/incoming_share.dart';
import '../domain/incoming_share_source.dart';

/// Glue between an [IncomingShareSource] and the vault's
/// [QuickCapture]. Drains the OS-queued payload at start, then
/// listens for live shares, appending each to
/// `<vaultRoot>/Inbox/Quick capture.md`.
///
/// Hand-rolled (no Cubit) because the user-visible state is just the
/// side-effect on disk — once a share lands, the vault watcher
/// dispatches RefreshFromDisk on its own, and the next render sees
/// the updated Inbox. A Cubit here would only manage "did we just
/// receive a share?" UX, which we don't currently surface.
class IncomingShareListener {
  IncomingShareListener({
    required IncomingShareSource source,
    required this.vaultRoot,
    Future<String> Function(String, Directory)? appender,
  })  : _source = source,
        _append = appender ?? QuickCapture.append;

  final IncomingShareSource _source;
  final Directory vaultRoot;
  final Future<String> Function(String, Directory) _append;

  StreamSubscription<List<IncomingShare>>? _sub;
  int _handled = 0;

  /// True iff the listener is actively subscribed.
  bool get isListening => _sub != null;

  /// Total shares appended successfully since [start]. Useful for tests
  /// and a future status indicator.
  int get handled => _handled;

  /// Drains the initial payload (synchronously appends) then starts
  /// listening for live shares. Idempotent — calling twice replaces
  /// the previous subscription.
  Future<void> start() async {
    await _sub?.cancel();
    final initial = await _source.initial();
    for (final share in initial) {
      await _appendOne(share);
    }
    _sub = _source.stream.listen((batch) async {
      for (final share in batch) {
        await _appendOne(share);
      }
    });
  }

  Future<void> _appendOne(IncomingShare share) async {
    final text = share.text.trim();
    if (text.isEmpty) return; // Defensive — QuickCapture also rejects.
    try {
      await _append(text, vaultRoot);
      _handled++;
    } catch (_) {
      // Swallow individual failures so one bad share doesn't kill the
      // subscription. The shared file or vault dir might transiently
      // be inaccessible; the user can re-share.
    }
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }
}
