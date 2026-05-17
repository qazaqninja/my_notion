import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/awareness_message.dart';

/// H4b — presence state for the editor's other-user cursor overlay.
/// Holds a map of `userId → AwarenessMessage` for the currently-
/// open page. The H4d wire dispatcher feeds incoming messages into
/// [remoteCursorReceived]; the editor's cursor-overlay widget
/// reads [cursors] and paints one chiclet per entry.
///
/// TTL: each per-user entry self-expires 5 seconds after the most-
/// recent message so a peer that disconnects without a clean close
/// (or just stops typing) fades out instead of pinning a ghost
/// cursor forever. Cleared on page navigation via [clear].
class PresenceState extends Equatable {
  const PresenceState({this.cursors = const <String, AwarenessMessage>{}});

  /// userId → most-recent cursor known for that user. The size
  /// matches the number of distinct peers currently active on
  /// this page.
  final Map<String, AwarenessMessage> cursors;

  PresenceState copyWith({Map<String, AwarenessMessage>? cursors}) {
    return PresenceState(cursors: cursors ?? this.cursors);
  }

  @override
  List<Object?> get props => [cursors];
}

/// Cubit (not a Bloc — no event-driven concurrency to coordinate,
/// just upsert + remove). The TTL timer per user is managed
/// internally; tests inject a [now] clock for deterministic
/// timing.
class PresenceCubit extends Cubit<PresenceState> {
  PresenceCubit({this.ttl = const Duration(seconds: 5)})
      : super(const PresenceState());

  /// How long an entry stays in [cursors] after its most-recent
  /// message before [_expire] removes it. 5 seconds matches the
  /// y_crdt awareness convention (long enough to ride a brief
  /// network blip, short enough that a closed tab disappears
  /// before users notice the lingering cursor).
  final Duration ttl;

  /// Active expiry timer per userId. Cancelled on each new
  /// message + on close so we never call [emit] after dispose.
  final Map<String, Timer> _timers = {};

  /// Upsert the entry for [msg.userId]. Restarts the TTL clock.
  void remoteCursorReceived(AwarenessMessage msg) {
    if (isClosed) return;
    final next = Map<String, AwarenessMessage>.from(state.cursors);
    next[msg.userId] = msg;
    emit(state.copyWith(cursors: next));
    _timers.remove(msg.userId)?.cancel();
    _timers[msg.userId] = Timer(ttl, () => _expire(msg.userId));
  }

  /// Drop the entry for [userId] (no-op if absent). Private —
  /// today only the per-user TTL Timer invokes it. When H4d's
  /// wire dispatcher adds an explicit `{"kind":"awareness-leave"}`
  /// envelope it can be promoted to public; until then keeping it
  /// private avoids signalling an API surface the cubit doesn't
  /// yet have.
  void _expire(String userId) {
    if (isClosed) return;
    if (!state.cursors.containsKey(userId)) return;
    final next = Map<String, AwarenessMessage>.from(state.cursors)
      ..remove(userId);
    _timers.remove(userId);
    emit(state.copyWith(cursors: next));
  }

  /// Reset to an empty cursor map. Called when the editor
  /// navigates to a different page so stale cursors from the
  /// previous page don't bleed through.
  void clear() {
    if (isClosed) return;
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
    if (state.cursors.isEmpty) return;
    emit(const PresenceState());
  }

  @override
  Future<void> close() {
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
    return super.close();
  }
}
