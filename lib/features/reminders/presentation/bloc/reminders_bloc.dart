import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/datasources/notification_scheduler.dart';
import 'reminders_event.dart';
import 'reminders_state.dart';

/// Manages OS-level reminder notifications. Implemented as a Bloc (not
/// Cubit) because schedule/cancel are I/O against the
/// `flutter_local_notifications` platform channel and benefit from the
/// `sequential` transformer (BL-10) — concurrent fires would race on the
/// scheduled-set, and a `droppable` transformer would silently swallow
/// rapid user toggles.
class RemindersBloc extends Bloc<RemindersEvent, RemindersState> {
  RemindersBloc({required NotificationScheduler scheduler})
      : _scheduler = scheduler,
        super(const RemindersState()) {
    on<ScheduleReminder>(_onSchedule, transformer: sequential());
    on<CancelReminder>(_onCancel, transformer: sequential());
    on<CancelAllReminders>(_onCancelAll, transformer: sequential());
  }

  final NotificationScheduler _scheduler;

  /// Maps a page ULID to a deterministic int id for the OS plugin (which
  /// only accepts ints). `hashCode` on a string is stable across runs in
  /// the same Dart VM session; for cross-session persistence we'd need
  /// our own hash, but the scheduled notifications themselves persist
  /// in the OS notification centre and survive app restarts.
  int _idFor(String ulid) => ulid.hashCode;

  Future<void> _onSchedule(
    ScheduleReminder e,
    Emitter<RemindersState> emit,
  ) async {
    try {
      await _scheduler.schedule(
        id: _idFor(e.ulid),
        title: e.title,
        body: 'Reminder: ${e.title}',
        when: e.when,
      );
    } catch (_) {
      // Scheduler failed (platform unsupported, permission denied, past
      // date). The bloc still records the intent in state — the UI badge
      // is informational and the user can re-arm by editing the date.
    }
    emit(state.copyWith(scheduled: {...state.scheduled, e.ulid}));
  }

  Future<void> _onCancel(
    CancelReminder e,
    Emitter<RemindersState> emit,
  ) async {
    if (!state.scheduled.contains(e.ulid)) return;
    try {
      await _scheduler.cancel(_idFor(e.ulid));
    } catch (_) {
      // Cancellation failed at platform level — best-effort. Drop from
      // state regardless so the UI reflects the user's intent.
    }
    final next = {...state.scheduled}..remove(e.ulid);
    emit(state.copyWith(scheduled: next));
  }

  Future<void> _onCancelAll(
    CancelAllReminders e,
    Emitter<RemindersState> emit,
  ) async {
    try {
      await _scheduler.cancelAll();
    } catch (_) {}
    emit(const RemindersState());
  }
}
