/// H2.5 — leading-edge throttle. The first call fires the
/// wrapped function immediately and records the stamp; subsequent
/// calls within [window] are suppressed until [window] has elapsed
/// since the last fire. After the window, the next call fires
/// again and the cycle restarts.
///
/// Use to gate UX side effects that can be triggered by bursty
/// upstream events — e.g. a "Multiplayer disconnected" toast
/// driven by `SyncConnectionLostException` (which a flaky network
/// can emit several times per second).
///
/// Time source is injectable via [now] so tests can advance the
/// clock without sleeping. Defaults to `DateTime.now`.
class Throttle<T> {
  Throttle(this.window, {DateTime Function()? now})
      : _now = now ?? DateTime.now;

  /// Minimum spacing between successive fires.
  final Duration window;
  final DateTime Function() _now;
  DateTime? _lastFiredAt;

  /// Run [fn] iff [window] has elapsed since the last fire (or no
  /// prior fire). Returns the function's value when fired, or
  /// `null` when suppressed.
  T? run(T Function() fn) {
    final now = _now();
    final last = _lastFiredAt;
    if (last != null && now.difference(last) < window) {
      return null;
    }
    _lastFiredAt = now;
    return fn();
  }

  /// Clear the last-fired stamp so the next call to [run] always
  /// fires. Useful when a state change makes prior throttling
  /// irrelevant (e.g. user explicitly retries).
  void reset() {
    _lastFiredAt = null;
  }
}
