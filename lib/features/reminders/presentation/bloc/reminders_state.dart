import 'package:equatable/equatable.dart';

/// Observable shape of the reminders feature. `scheduled` is the set of
/// page ULIDs that currently have an OS-level reminder armed via the
/// `NotificationScheduler`.
///
/// The frontmatter `reminder:` field is the source of truth for *when*
/// each reminder fires; this state only tracks *which* pages have an
/// active OS-level schedule so the UI can render a badge / chip without
/// re-scanning every page.
class RemindersState extends Equatable {
  const RemindersState({this.scheduled = const <String>{}});

  final Set<String> scheduled;

  RemindersState copyWith({Set<String>? scheduled}) =>
      RemindersState(scheduled: scheduled ?? this.scheduled);

  bool isScheduled(String ulid) => scheduled.contains(ulid);

  int get count => scheduled.length;

  @override
  List<Object?> get props => [scheduled];
}
