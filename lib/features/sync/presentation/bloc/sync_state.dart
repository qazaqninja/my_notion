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
  });

  final SyncStatus status;
  final String? token; // null until login succeeds
  final String? lastError; // human-readable; null when clean
  final SyncFileSummary? lastConflict; // populated on 409
  final SyncFileSummary? lastPush; // populated after a successful push

  bool get isAuthed => token != null && token!.isNotEmpty;

  SyncState copyWith({
    SyncStatus? status,
    String? token,
    String? lastError,
    SyncFileSummary? lastConflict,
    SyncFileSummary? lastPush,
    bool clearError = false,
    bool clearConflict = false,
  }) {
    return SyncState(
      status: status ?? this.status,
      token: token ?? this.token,
      lastError: clearError ? null : (lastError ?? this.lastError),
      lastConflict: clearConflict ? null : (lastConflict ?? this.lastConflict),
      lastPush: lastPush ?? this.lastPush,
    );
  }

  @override
  List<Object?> get props =>
      [status, token, lastError, lastConflict, lastPush];
}
