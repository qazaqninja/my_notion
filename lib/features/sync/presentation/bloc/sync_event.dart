import 'package:equatable/equatable.dart';

sealed class SyncEvent extends Equatable {
  const SyncEvent();
  @override
  List<Object?> get props => [];
}

/// Log into the v2 backend with email + password. On success the bloc
/// transitions to `SyncState.connected` with the returned JWT cached.
class SyncLoginRequested extends SyncEvent {
  const SyncLoginRequested({required this.email, required this.password});
  final String email;
  final String password;
  @override
  List<Object?> get props => [email, password];
}

/// Same shape as login but creates the user. Maps `email_taken` to a
/// distinct state error.
class SyncSignupRequested extends SyncEvent {
  const SyncSignupRequested({required this.email, required this.password});
  final String email;
  final String password;
  @override
  List<Object?> get props => [email, password];
}

/// Forget the cached token; bloc returns to `SyncState.idle`.
class SyncLogoutRequested extends SyncEvent {
  const SyncLogoutRequested();
}

/// Boot-time: if SharedPreferences has a stored token, hydrate the bloc
/// into a `connected` state without round-tripping login. Used by
/// `app.dart` on construction so a quit + relaunch doesn't force the
/// user to re-authenticate.
class SyncRestoreRequested extends SyncEvent {
  const SyncRestoreRequested();
}

/// Boot / post-login: fetch the full server-side listing and merge each
/// `(relpath, sha256)` into `SyncState.knownShas`. After this completes
/// the first push for any of those relpaths already carries a real
/// `If-Match` instead of a stale local guess, so concurrent edits made
/// from another device while the app was closed surface as conflicts
/// (E19+E20) rather than silent overwrites.
class SyncListRequested extends SyncEvent {
  const SyncListRequested();
}

/// One entry in a `SyncPushAllRequested` batch: the local body the
/// caller wants the server to mirror, plus its current sha256 so the
/// bloc can skip relpaths whose `knownShas` value already matches.
class SyncBulkPushEntry {
  const SyncBulkPushEntry({
    required this.relpath,
    required this.body,
    required this.sha256,
  });
  final String relpath;
  final String body;
  final String sha256;
}

/// E31 — vault-wide bulk push. Used by "Push all unsynced files" so
/// a fresh login can seed the server with the user's existing vault
/// in one click. The handler iterates [entries] and dispatches a
/// `SyncPushFileRequested` for each one whose local sha differs from
/// the bloc's tracked `knownShas[relpath]` (or has no tracker entry
/// yet). Already-in-sync entries are skipped — bulk push is idempotent.
class SyncPushAllRequested extends SyncEvent {
  const SyncPushAllRequested(this.entries);
  final List<SyncBulkPushEntry> entries;
  @override
  List<Object?> get props => [entries];
}

/// Internal event used by `SyncBloc` to bump `pendingPushes` up or
/// down as pushes are dispatched and complete (E30). Library-private:
/// the rest of the app should not dispatch it directly. The `+1` is
/// emitted from the override of `add()` so it captures queue depth
/// (events waiting on the sequential transformer), not just in-flight
/// count.
class SyncPendingPushDelta extends SyncEvent {
  const SyncPendingPushDelta(this.delta);
  final int delta;
  @override
  List<Object?> get props => [delta];
}

/// E29 — backend liveness check. Hits `GET /health` and updates
/// `SyncState.lastPingAt` (success) or `lastError` (network failure
/// or non-200 status). Auth-agnostic; works before login too.
class SyncPingRequested extends SyncEvent {
  const SyncPingRequested();
}

/// Tell the bloc the UI has finished reading `SyncState.lastFetched`
/// — drops the value so the pull dialog doesn't re-open on the next
/// rebuild. Used by the E24 reconcile dialog's dismiss / "Keep local"
/// branches and after a successful "Use server version" replace.
class SyncFetchCleared extends SyncEvent {
  const SyncFetchCleared();
}

/// Pull the latest server copy of [relpath]. Populates
/// `SyncState.lastFetched` (E23) so the UI can diff against the local
/// page body and offer "Use server version" / "Keep local". Used by the
/// editor kebab and as a Pull action attached to conflict toasts.
class SyncFetchFileRequested extends SyncEvent {
  const SyncFetchFileRequested({required this.relpath});
  final String relpath;
  @override
  List<Object?> get props => [relpath];
}

/// Delete a single file from the server-side mirror. Used by the
/// editor's "Move to trash" flow so a trashed page disappears from
/// other devices too. 404 from the server is treated as success —
/// idempotent, the file is already gone. On success the bloc also
/// drops the relpath from `knownShas` (E19/E20 tracker) so it doesn't
/// leak into a future If-Match header.
class SyncDeleteFileRequested extends SyncEvent {
  const SyncDeleteFileRequested({required this.relpath});
  final String relpath;
  @override
  List<Object?> get props => [relpath];
}

/// Upload a single file body to the backend. Used by the editor's save
/// path (slice E14) and by manual "Push now" actions. If `ifMatch` is
/// set the server may reject with conflict — that surfaces as a
/// non-fatal state error containing the server's current summary so the
/// caller can decide how to reconcile.
class SyncPushFileRequested extends SyncEvent {
  const SyncPushFileRequested({
    required this.relpath,
    required this.body,
    this.ifMatch,
  });
  final String relpath;
  final String body;
  final String? ifMatch;
  @override
  List<Object?> get props => [relpath, body, ifMatch];
}
