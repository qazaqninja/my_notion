import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/repositories/sync_repository.dart';
import 'sync_event.dart';
import 'sync_state.dart';

/// SharedPreferences key for the persisted JWT (E15). Empty / missing
/// means no token cached.
const _kTokenPrefKey = 'sync.token';

/// Default cadence for the E27 background `/sync/list` ping. Picked to
/// be small enough that an external edit shows up before the user's
/// next save in a typical editing session, but large enough not to
/// flood the backend when the app is idle on a public Wi-Fi.
const Duration kDefaultSyncListPingInterval = Duration(seconds: 60);

/// Coordinates v2 backend auth + push/pull lifecycle from the Flutter
/// app. Lives at top-level via `app.dart`'s MultiBlocProvider so any
/// route can `context.read<SyncBloc>().add(SyncPushFileRequested(...))`.
///
/// Transformer choice:
/// - Auth events (login/signup/logout) use `sequential()` so back-to-back
///   form submissions don't race (BL-10).
/// - Push events use `sequential()` too so concurrent saves keep order.
class SyncBloc extends Bloc<SyncEvent, SyncState> {
  SyncBloc({
    required SyncRepository repo,
    Duration listPingInterval = kDefaultSyncListPingInterval,
  })  : _repo = repo,
        _listPingInterval = listPingInterval,
        super(const SyncState()) {
    on<SyncLoginRequested>(_onLogin, transformer: sequential());
    on<SyncSignupRequested>(_onSignup, transformer: sequential());
    // E37 (orchestrator BL-10): rapid double-tap of "Log out" would
    // otherwise race two SharedPreferences writes against each other.
    // droppable() guarantees only the first one runs while it's
    // in-flight.
    on<SyncLogoutRequested>(_onLogout, transformer: droppable());
    on<SyncRestoreRequested>(_onRestore);
    on<SyncListRequested>(_onList, transformer: sequential());
    on<SyncPushFileRequested>(_onPush, transformer: sequential());
    on<SyncDeleteFileRequested>(_onDelete, transformer: sequential());
    on<SyncFetchFileRequested>(_onFetch, transformer: sequential());
    on<SyncFetchCleared>(_onFetchCleared);
    on<SyncPingRequested>(_onPing, transformer: sequential());
    on<SyncPendingPushDelta>(_onPendingDelta);
    // E37 (orchestrator BL-10): the bulk-push handler dispatches a
    // tight loop of SyncPushFileRequested. A second SyncPushAllRequested
    // landing mid-loop would interleave dispatches; droppable() keeps
    // the first batch atomic.
    on<SyncPushAllRequested>(_onPushAll, transformer: droppable());
  }

  /// E30 — overrides Bloc.add so a `+1` to `pendingPushes` is observed
  /// at dispatch time (capturing queued-but-not-yet-running pushes)
  /// rather than only when the handler enters the `sequential()` slot.
  @override
  void add(SyncEvent event) {
    if (event is SyncPushFileRequested) {
      super.add(const SyncPendingPushDelta(1));
    }
    super.add(event);
  }

  void _onPushAll(
    SyncPushAllRequested e,
    Emitter<SyncState> emit,
  ) {
    if (!state.isAuthed) {
      emit(state.copyWith(
        status: SyncStatus.error,
        lastError: 'not_authenticated',
      ));
      return;
    }
    for (final entry in e.entries) {
      // Skip relpaths whose tracker already matches the local sha — no
      // need to round-trip the body to land an empty change. The first
      // push for any new relpath has no tracker entry yet, so this
      // check naturally returns false and the push is dispatched.
      if (state.knownShaFor(entry.relpath) == entry.sha256) continue;
      add(SyncPushFileRequested(
        relpath: entry.relpath,
        body: entry.body,
      ));
    }
  }

  void _onPendingDelta(
    SyncPendingPushDelta e,
    Emitter<SyncState> emit,
  ) {
    final next = state.pendingPushes + e.delta;
    // Defensive clamp — counters should never go negative even if a
    // failure path forgets to dispatch its -1.
    emit(state.copyWith(pendingPushes: next < 0 ? 0 : next));
  }

  final SyncRepository _repo;
  final Duration _listPingInterval;

  /// Background ping that re-runs `/sync/list` while the bloc is authed
  /// so concurrent edits from another device show up as conflicts on
  /// the next save instead of silent overwrites. Started by
  /// `_startListPing`, cancelled by `_stopListPing` whenever the bloc
  /// transitions out of authed state (logout, 401 token invalidation,
  /// or `close()`).
  Timer? _listPingTimer;

  void _startListPing() {
    _listPingTimer?.cancel();
    _listPingTimer = Timer.periodic(_listPingInterval, (_) {
      // Re-dispatch through the event system so the sequential
      // transformer on SyncListRequested keeps concurrent pings ordered.
      // Also fire a /health ping each tick so the UI's "Backend
      // reachable" indicator (E29) stays fresh even when the user
      // isn't editing files.
      if (state.isAuthed) {
        add(const SyncListRequested());
        add(const SyncPingRequested());
      }
    });
  }

  void _stopListPing() {
    _listPingTimer?.cancel();
    _listPingTimer = null;
  }

  @override
  Future<void> close() async {
    _stopListPing();
    return super.close();
  }

  Future<void> _onLogin(
    SyncLoginRequested e,
    Emitter<SyncState> emit,
  ) async {
    emit(state.copyWith(status: SyncStatus.busy, clearError: true));
    try {
      final token = await _repo.login(email: e.email, password: e.password);
      await _persistToken(token);
      emit(state.copyWith(status: SyncStatus.connected, token: token));
      // E20: kick off a listing so the first post-login push already
      // has a real If-Match for every relpath the server knows about.
      add(const SyncListRequested());
      // E27: keep the listing fresh in the background so concurrent
      // edits from another device surface as conflicts before the
      // user's next save.
      _startListPing();
    } on SyncAuthException {
      emit(state.copyWith(
        status: SyncStatus.error,
        lastError: 'invalid_credentials',
      ));
    } on SyncNetworkException catch (err) {
      emit(state.copyWith(
        status: SyncStatus.error,
        lastError: err.message,
      ));
    }
  }

  Future<void> _onSignup(
    SyncSignupRequested e,
    Emitter<SyncState> emit,
  ) async {
    emit(state.copyWith(status: SyncStatus.busy, clearError: true));
    try {
      final token = await _repo.signup(email: e.email, password: e.password);
      await _persistToken(token);
      emit(state.copyWith(status: SyncStatus.connected, token: token));
      // Fresh accounts will receive an empty list; the call is still
      // cheap and keeps the post-login flow symmetric with login.
      add(const SyncListRequested());
      _startListPing();
    } on SyncEmailTakenException {
      emit(state.copyWith(
        status: SyncStatus.error,
        lastError: 'email_taken',
      ));
    } on SyncAuthException {
      // E.g. 400 invalid_email_or_password from server-side validation.
      emit(state.copyWith(
        status: SyncStatus.error,
        lastError: 'invalid_signup',
      ));
    } on SyncNetworkException catch (err) {
      emit(state.copyWith(
        status: SyncStatus.error,
        lastError: err.message,
      ));
    }
  }

  Future<void> _onLogout(
    SyncLogoutRequested e,
    Emitter<SyncState> emit,
  ) async {
    await _clearToken();
    _stopListPing();
    // Returning the default SyncState() also clears knownShas — fresh
    // login starts with a clean tracker.
    emit(const SyncState());
  }

  Future<void> _onRestore(
    SyncRestoreRequested e,
    Emitter<SyncState> emit,
  ) async {
    final token = await _readToken();
    if (token == null || token.isEmpty) return;
    // Optimistic: trust the persisted token. A 401 on the next call
    // (push / list / get) will trip `_onPush`'s SyncAuthException
    // branch and reset to error: token_invalid.
    emit(state.copyWith(status: SyncStatus.connected, token: token));
    // E20: on relaunch, hydrate knownShas immediately so the first
    // push for any tracked relpath already has a real If-Match. Also
    // serves as a token-validity ping: a 401 here will clear the
    // stale token early instead of waiting for the first save.
    add(const SyncListRequested());
    _startListPing();
  }

  Future<void> _onList(
    SyncListRequested e,
    Emitter<SyncState> emit,
  ) async {
    final token = state.token;
    if (token == null || token.isEmpty) return;
    try {
      final summaries = await _repo.list(token: token);
      // E33: race-guard. A logout could have landed between the
      // outer token check and the listing response — if so, do NOT
      // emit, otherwise the freshly-empty state would be polluted
      // by the previous user's relpaths.
      if (!state.isAuthed) return;
      if (summaries.isEmpty) return;
      // Merge — don't replace. A push that already happened during the
      // listing round-trip should not be clobbered by a snapshot taken
      // before it landed.
      final next = <String, String>{...state.knownShas};
      for (final s in summaries) {
        next[s.relpath] = s.sha256;
      }
      emit(state.copyWith(knownShas: next));
    } on SyncAuthException {
      // Token was already invalidated server-side. Reuse the same
      // recovery as a push 401: clear the cached token, error out.
      await _clearToken();
      _stopListPing();
      emit(const SyncState(
        status: SyncStatus.error,
        lastError: 'token_invalid',
      ));
    } on SyncNetworkException {
      // List is best-effort; the next push will still re-attempt
      // and gracefully re-conflict if needed. Don't surface a hard
      // error — silently leave the tracker as-is.
    }
  }

  Future<void> _onPush(
    SyncPushFileRequested e,
    Emitter<SyncState> emit,
  ) async {
    final token = state.token;
    if (token == null) {
      emit(state.copyWith(
        status: SyncStatus.error,
        lastError: 'not_authenticated',
      ));
      // The +1 was dispatched in add(); we still need a -1 here so the
      // counter doesn't drift even when auth fails fast.
      add(const SyncPendingPushDelta(-1));
      return;
    }
    emit(state.copyWith(status: SyncStatus.busy, clearError: true));
    try {
      // E19: if the caller didn't provide an explicit ifMatch, fall back
      // to the bloc's tracked last-known-server-sha for this relpath.
      // Result: edits made on another device since our last push surface
      // as conflicts rather than silently overwriting.
      final effectiveIfMatch =
          e.ifMatch ?? state.knownShaFor(e.relpath);
      final outcome = await _repo.put(
        token: token,
        relpath: e.relpath,
        body: e.body,
        ifMatch: effectiveIfMatch,
      );
      switch (outcome) {
        case SyncPutSuccess(:final summary):
          emit(state.copyWith(
            status: SyncStatus.connected,
            lastPush: summary,
            knownShas: {
              ...state.knownShas,
              summary.relpath: summary.sha256,
            },
            clearConflict: true,
          ));
        case SyncPutConflict(:final current):
          emit(state.copyWith(
            status: SyncStatus.error,
            lastError: 'conflict',
            lastConflict: current,
            // Update the tracker to the server's view so the next push
            // for this relpath won't immediately re-conflict on the same
            // stale sha — the client picks reconciliation strategy
            // (rebase / overwrite) and pushes again.
            knownShas: {
              ...state.knownShas,
              current.relpath: current.sha256,
            },
          ));
      }
    } on SyncAuthException {
      // Token expired or revoked. Drop it; UI can re-prompt for login.
      await _clearToken();
      _stopListPing();
      emit(const SyncState(
        status: SyncStatus.error,
        lastError: 'token_invalid',
      ));
    } on SyncNetworkException catch (err) {
      emit(state.copyWith(
        status: SyncStatus.error,
        lastError: err.message,
      ));
    } finally {
      // E30 — pair every +1 (dispatched in add()) with a -1, regardless
      // of how _onPush exited. Reset emitted by the 401 branch already
      // zeroes pendingPushes via const SyncState(), but it's harmless
      // to enqueue another -1: _onPendingDelta clamps at 0.
      add(const SyncPendingPushDelta(-1));
    }
  }

  Future<void> _onDelete(
    SyncDeleteFileRequested e,
    Emitter<SyncState> emit,
  ) async {
    final token = state.token;
    if (token == null) {
      emit(state.copyWith(
        status: SyncStatus.error,
        lastError: 'not_authenticated',
      ));
      return;
    }
    try {
      // The repo returns `true` for 204 and `false` for 404. Both are
      // treated as success — a 404 just means the file was already gone
      // from the server (idempotent delete). Either way, drop the
      // relpath from the tracker so a future push doesn't ship a stale
      // If-Match for a file the server has forgotten.
      await _repo.delete(token: token, relpath: e.relpath);
      final next = <String, String>{...state.knownShas}..remove(e.relpath);
      emit(state.copyWith(
        status: SyncStatus.connected,
        knownShas: next,
        clearError: true,
      ));
    } on SyncAuthException {
      await _clearToken();
      _stopListPing();
      emit(const SyncState(
        status: SyncStatus.error,
        lastError: 'token_invalid',
      ));
    } on SyncNetworkException catch (err) {
      emit(state.copyWith(
        status: SyncStatus.error,
        lastError: err.message,
      ));
    }
  }

  Future<void> _onFetch(
    SyncFetchFileRequested e,
    Emitter<SyncState> emit,
  ) async {
    final token = state.token;
    if (token == null) {
      emit(state.copyWith(
        status: SyncStatus.error,
        lastError: 'not_authenticated',
      ));
      return;
    }
    try {
      final body = await _repo.get(token: token, relpath: e.relpath);
      if (body == null) {
        emit(state.copyWith(
          status: SyncStatus.error,
          lastError: 'not_found',
          clearFetched: true,
        ));
        return;
      }
      // Trust the server's sha here too — it doubles as a known-shas
      // refresh, so a subsequent push automatically uses the latest
      // server view as If-Match.
      final next = <String, String>{...state.knownShas};
      next[body.summary.relpath] = body.summary.sha256;
      emit(state.copyWith(
        status: SyncStatus.connected,
        lastFetched: body,
        knownShas: next,
        clearError: true,
      ));
    } on SyncAuthException {
      await _clearToken();
      _stopListPing();
      emit(const SyncState(
        status: SyncStatus.error,
        lastError: 'token_invalid',
      ));
    } on SyncNetworkException catch (err) {
      emit(state.copyWith(
        status: SyncStatus.error,
        lastError: err.message,
      ));
    }
  }

  Future<void> _onPing(
    SyncPingRequested e,
    Emitter<SyncState> emit,
  ) async {
    try {
      final ok = await _repo.ping();
      if (ok) {
        emit(state.copyWith(
          lastPingAt: DateTime.now(),
          // Clear any previous network error so the banner dismisses
          // automatically once the backend comes back.
          clearError: true,
        ));
      } else {
        // 503 — server up but DB down. Surface as a network-class
        // error so the E28 banner highlights it.
        emit(state.copyWith(
          status: SyncStatus.error,
          lastError: 'backend_unhealthy',
        ));
      }
    } on SyncNetworkException catch (err) {
      emit(state.copyWith(
        status: SyncStatus.error,
        lastError: err.message,
      ));
    }
  }

  void _onFetchCleared(
    SyncFetchCleared e,
    Emitter<SyncState> emit,
  ) {
    if (state.lastFetched == null) return;
    emit(state.copyWith(clearFetched: true));
  }

  Future<void> _persistToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTokenPrefKey, token);
  }

  Future<void> _clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kTokenPrefKey);
  }

  Future<String?> _readToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kTokenPrefKey);
  }
}
