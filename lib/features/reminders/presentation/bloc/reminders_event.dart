import 'package:equatable/equatable.dart';

sealed class RemindersEvent extends Equatable {
  const RemindersEvent();
  @override
  List<Object?> get props => [];
}

/// Schedule a reminder for a page. Emits a state with `ulid` added to
/// `scheduled`. The actual OS notification is scheduled via the
/// `NotificationScheduler` injected into the bloc; on platforms where the
/// scheduler is a no-op (Linux, Windows pre-21.0) the bloc still records
/// the in-memory state so the UI can surface the badge.
class ScheduleReminder extends RemindersEvent {
  const ScheduleReminder({
    required this.ulid,
    required this.title,
    required this.when,
  });

  final String ulid;
  final String title;
  final DateTime when;

  @override
  List<Object?> get props => [ulid, title, when];
}

/// Cancel a previously-scheduled reminder by page ULID. No-op if no
/// reminder is registered for that ULID.
class CancelReminder extends RemindersEvent {
  const CancelReminder(this.ulid);

  final String ulid;

  @override
  List<Object?> get props => [ulid];
}

/// Cancel every scheduled reminder. Used during vault close so a page
/// loaded from a different vault doesn't fire stale notifications.
class CancelAllReminders extends RemindersEvent {
  const CancelAllReminders();
}
