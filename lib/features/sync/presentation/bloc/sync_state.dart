import 'package:equatable/equatable.dart';

import '../../domain/entities/sync_file.dart';

enum SyncStatus { idle, busy, connected, error }

/// Single-state shape for the SyncBloc. The status enum + nullable
/// fields keep the state shape flat — easier to inspect from the UI
/// than a sealed hierarchy.
class SyncState extends Equatable {
  const SyncState({
    this.status = SyncStatus.idle,
    this.token,
    this.lastError,
    this.lastConflict,
    this.lastPush,
    this.lastFetched,
    this.knownShas = const <String, String>{},
  });

  final SyncStatus status;
  final String? token; // null until login succeeds
  final String? lastError; // human-readable; null when clean
  final SyncFileSummary? lastConflict; // populated on 409
  final SyncFileSummary? lastPush; // populated after a successful push
  /// Populated by a successful `SyncFetchFileRequested` (E23). The UI
  /// reads this to render a "Pull from server" diff / replace dialog.
  /// Cleared on logout. A 404 sets it back to null and surfaces
  /// `lastError = 'not_found'` so the UI can distinguish "no server
  /// copy" from "fetch failed".
  final SyncFileBody? lastFetched;

  /// Map of `relpath → sha256` for the last-known server-side version
  /// of each file the client has pushed or had a conflict on. Used to
  /// stamp `If-Match` on subsequent pushes so concurrent edits from
  /// another device surface as 409 conflicts instead of overwriting.
  final Map<String, String> knownShas;

  bool get isAuthed => token != null && token!.isNotEmpty;

  /// Last-known server sha for [relpath], or null if we've never seen
  /// it. Callers wire this into `ifMatch` of the next push for the
  /// same relpath.
  String? knownShaFor(String relpath) => knownShas[relpath];

  SyncState copyWith({
    SyncStatus? status,
    String? token,
    String? lastError,
    SyncFileSummary? lastConflict,
    SyncFileSummary? lastPush,
    SyncFileBody? lastFetched,
    Map<String, String>? knownShas,
    bool clearError = false,
    bool clearConflict = false,
    bool clearFetched = false,
  }) {
    return SyncState(
      status: status ?? this.status,
      token: token ?? this.token,
      lastError: clearError ? null : (lastError ?? this.lastError),
      lastConflict: clearConflict ? null : (lastConflict ?? this.lastConflict),
      lastPush: lastPush ?? this.lastPush,
      lastFetched: clearFetched ? null : (lastFetched ?? this.lastFetched),
      knownShas: knownShas ?? this.knownShas,
    );
  }

  @override
  List<Object?> get props => [
        status,
        token,
        lastError,
        lastConflict,
        lastPush,
        lastFetched,
        knownShas,
      ];
}
