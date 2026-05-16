import 'dart:async';
import 'dart:io';

import '../../vault/presentation/bloc/vault_bloc.dart';
import '../../vault/presentation/bloc/vault_state.dart';
import '../domain/incoming_share_source.dart';
import 'incoming_share_listener.dart';

/// Glues the [VaultBloc] lifecycle to the [IncomingShareListener]: the
/// share listener can only run when a vault is open (otherwise there's
/// nowhere to write `Inbox/Quick capture.md`), so we start it whenever
/// the bloc transitions into `VaultLoaded` and stop it on the way out.
///
/// The vault root is determined by the loaded state — a different
/// vault path means tear down + rebuild a fresh listener so shares
/// always land in the *currently-open* vault.
class IncomingShareBinder {
  IncomingShareBinder({
    required VaultBloc vaultBloc,
    required IncomingShareSource Function() sourceFactory,
    IncomingShareListener Function({
      required IncomingShareSource source,
      required Directory vaultRoot,
    })? listenerFactory,
  })  : _bloc = vaultBloc,
        _sourceFactory = sourceFactory,
        _listenerFactory = listenerFactory ??
            ((
                {required IncomingShareSource source,
                required Directory vaultRoot}) =>
                IncomingShareListener(
                  source: source,
                  vaultRoot: vaultRoot,
                ));

  final VaultBloc _bloc;
  final IncomingShareSource Function() _sourceFactory;
  final IncomingShareListener Function({
    required IncomingShareSource source,
    required Directory vaultRoot,
  }) _listenerFactory;

  StreamSubscription<VaultState>? _sub;
  IncomingShareSource? _activeSource;
  IncomingShareListener? _activeListener;
  String? _activeRoot;

  /// Currently-running listener, or null when no vault is loaded.
  /// Exposed for tests and a future status indicator.
  IncomingShareListener? get listener => _activeListener;

  Future<void> attach() async {
    // React to the initial state too — VaultBloc may already be in
    // VaultLoaded by the time we attach (e.g. after a quick restore).
    await _react(_bloc.state);
    _sub = _bloc.stream.listen(_react);
  }

  Future<void> _react(VaultState state) async {
    if (state is VaultLoaded) {
      if (_activeRoot == state.rootPath) return; // already bound
      await _stopActive();
      final source = _sourceFactory();
      final listener = _listenerFactory(
        source: source,
        vaultRoot: Directory(state.rootPath),
      );
      _activeSource = source;
      _activeListener = listener;
      _activeRoot = state.rootPath;
      // F9 / orchestrator BL-11: guard `listener.start()` so a crash
      // inside the share-plugin's initial-payload read doesn't kill
      // the bloc-stream subscription on the way out. We swallow the
      // error here — the next VaultLoaded emission will re-create
      // the listener from scratch.
      try {
        await listener.start();
      } catch (_) {
        await _stopActive();
      }
    } else {
      // VaultPicking / VaultError / VaultInitial — tear down anything
      // we previously spun up; nothing to bind to.
      await _stopActive();
    }
  }

  Future<void> _stopActive() async {
    await _activeListener?.stop();
    await _activeSource?.close();
    _activeListener = null;
    _activeSource = null;
    _activeRoot = null;
  }

  Future<void> detach() async {
    await _sub?.cancel();
    _sub = null;
    await _stopActive();
  }
}
