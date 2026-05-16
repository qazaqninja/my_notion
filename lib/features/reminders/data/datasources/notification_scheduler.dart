import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Minimal abstraction over `flutter_local_notifications` so the
/// `RemindersBloc` (and tests) can call a domain-friendly API without
/// importing the platform package directly. Lives in `data/datasources/`
/// per Clean Architecture + RULES.md FS-01 (feature-scoped data layer).
///
/// Methods are intentionally thin pass-throughs to the plugin, with two
/// pieces of value-added behaviour:
/// 1. `init()` initialises the plugin with safe per-platform defaults and
///    loads the IANA timezone database needed for `zonedSchedule`. Callers
///    must `await scheduler.init()` once at app start before any other
///    method.
/// 2. `schedule(id, title, body, when)` packages the most common reminder
///    shape — a one-shot local notification at a specific Dart `DateTime`
///    in the user's local timezone — into a single call. The timezone
///    conversion + matchDateTimeComponents + UILocalNotificationDateInterpretation
///    boilerplate is hidden.
abstract class NotificationScheduler {
  /// Initialise the underlying plugin. Idempotent.
  Future<void> init();

  /// Schedule a one-shot local notification.
  ///
  /// - [id] must be unique across active notifications. Re-using an id
  ///   replaces the prior notification scheduled with that id.
  /// - [when] is interpreted in the user's local timezone. Past times are
  ///   silently dropped by the plugin.
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime when,
  });

  /// Cancel a previously-scheduled notification by [id]. No-op if not
  /// found.
  Future<void> cancel(int id);

  /// Cancel all scheduled notifications. Used by `CloseVault` cleanup.
  Future<void> cancelAll();
}

class LocalNotificationScheduler implements NotificationScheduler {
  LocalNotificationScheduler({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialised = false;

  @override
  Future<void> init() async {
    if (_initialised) return;
    tz_data.initializeTimeZones();
    // Initialisation settings:
    // - Android: a generic default channel.
    // - iOS / macOS: request all permissions upfront — the user OS will
    //   surface a single permission prompt the first time we schedule.
    // - Linux/Windows: not directly supported by this plugin (yet); calls
    //   from those platforms become no-ops.
    const init = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
      macOS: DarwinInitializationSettings(),
    );
    await _plugin.initialize(settings: init);
    _initialised = true;
  }

  @override
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime when,
  }) async {
    final scheduled = tz.TZDateTime.from(when, tz.local);
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduled,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'quill_reminders',
          'Reminders',
          channelDescription: 'Page reminders set via the editor kebab menu.',
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);

  @override
  Future<void> cancelAll() => _plugin.cancelAll();
}
