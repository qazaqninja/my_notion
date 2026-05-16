/// Compact relative-time formatter used by sync-related UI (sync card
/// activity rows, pull-reconcile dialog header).
///
/// Returns one of: `now`, `Xs ago`, `Xm ago`, `Xh ago`, `Xd ago`. Future
/// timestamps map to `just now` so a clock-skew across devices doesn't
/// render absurd negative durations.
String syncRelativeTime(DateTime when) {
  final diff = DateTime.now().difference(when);
  if (diff.isNegative) return 'just now';
  if (diff.inSeconds < 5) return 'now';
  if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}
