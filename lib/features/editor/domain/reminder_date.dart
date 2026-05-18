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
/// editor_page.dart `_setReminder` toast suffix so the WYSIWYG and
/// legacy editors say the same thing for the same pick.
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
