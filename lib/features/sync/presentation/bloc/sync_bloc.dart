import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/repositories/sync_repository.dart';
import 'sync_event.dart';
import 'sync_state.dart';

/// SharedPreferences key for the persisted JWT (E15). Empty / missing
/// means no token cached.
const _kTokenPrefKey = 'sync.token';

/// Coordinates v2 backend auth + push/pull lifecycle from the Flutter
/// app. Lives at top-level via `app.dart`'s MultiBlocProvider so any
/// route can `context.read<SyncBloc>().add(SyncPushFileRequested(...))`.
///
/// Transformer choice:
/// - Auth events (login/signup/logout) use `sequential()` so back-to-back
///   form submissions don't race (BL-10).
/// - Push events use `sequential()` too so concurrent saves keep order.
class SyncBloc extends Bloc<SyncEvent, SyncState> {
  SyncBloc({required SyncRepository repo})
      : _repo = repo,
        super(const SyncState()) {
    on<SyncLoginRequested>(_onLogin, transformer: sequential());
    on<SyncSignupRequested>(_onSignup, transformer: sequential());
    on<SyncLogoutRequested>(_onLogout);
    on<SyncRestoreRequested>(_onRestore);
    on<SyncPushFileRequested>(_onPush, transformer: sequential());
  }

  final SyncRepository _repo;

  Future<void> _onLogin(
    SyncLoginRequested e,
    Emitter<SyncState> emit,
  ) async {
    emit(state.copyWith(status: SyncStatus.busy, clearError: true));
    try {
      final token = await _repo.login(email: e.email, password: e.password);
      await _persistToken(token);
      emit(state.copyWith(status: SyncStatus.connected, token: token));
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
      return;
    }
    emit(state.copyWith(status: SyncStatus.busy, clearError: true));
    try {
      final outcome = await _repo.put(
        token: token,
        relpath: e.relpath,
        body: e.body,
        ifMatch: e.ifMatch,
      );
      switch (outcome) {
        case SyncPutSuccess(:final summary):
          emit(state.copyWith(
            status: SyncStatus.connected,
            lastPush: summary,
            clearConflict: true,
          ));
        case SyncPutConflict(:final current):
          emit(state.copyWith(
            status: SyncStatus.error,
            lastError: 'conflict',
            lastConflict: current,
          ));
      }
    } on SyncAuthException {
      // Token expired or revoked. Drop it; UI can re-prompt for login.
      await _clearToken();
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
