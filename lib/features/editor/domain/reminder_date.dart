/// Serialise a [DateTime] to the date-only YYYY-MM-DD form that the
/// `reminder:` frontmatter field expects.
///
/// Time-of-day is dropped; only year, month, and day are encoded.
/// Year is padded to 4 digits, month/day to 2 digits each.
String isoDate(DateTime d) {
  final yyyy = d.year.toString().padLeft(4, '0');
  final mm = d.month.toString().padLeft(2, '0');
  final dd = d.day.toString().padLeft(2, '0');
  return '$yyyy-$mm-$dd';
}

/// User-visible "today / tomorrow / in N days / N days ago" label
/// for a reminder date relative to "now". Mirrors the legacy
/// `_setReminder` toast suffix so the WYSIWYG editor matches the
/// historical phrasing for the same pick.
///
/// Comparison is on the calendar date (time-of-day is ignored) so a
/// 23:59 pick and a 00:01 "now" the next morning still report
/// "tomorrow", not "today".
String relativeReminderLabel({
  required DateTime picked,
  required DateTime now,
}) {
  final today = DateTime(now.year, now.month, now.day);
  final tPicked = DateTime(picked.year, picked.month, picked.day);
  final days = tPicked.difference(today).inDays;
  if (days == 0) return 'today';
  if (days == 1) return 'tomorrow';
  if (days > 0) return 'in $days days';
  final ago = -days;
  return '$ago ${ago == 1 ? 'day' : 'days'} ago';
}

/// Pick the "base day" to add a snooze offset to. Mirrors the legacy
/// `_snoozeReminder` semantics: snooze always lands in the future, so
/// if the existing reminder is already past, count from `today`
/// instead of the past — otherwise "+ 7 days" on a 2025-01-01
/// reminder produces 2025-01-08, still in the past.
///
/// - `existing == null` → returns `today` (no reminder set; the caller
///   will SnackBar "no reminder" but the math still works).
/// - `existing` strictly before `today` → returns `today`.
/// - otherwise → returns the start-of-day of `existing`.
DateTime snoozeBaseFor({
  required DateTime? existing,
  required DateTime today,
}) {
  final startOfToday = DateTime(today.year, today.month, today.day);
  if (existing == null) return startOfToday;
  final existingDay = DateTime(existing.year, existing.month, existing.day);
  return existingDay.isBefore(startOfToday) ? startOfToday : existingDay;
}
