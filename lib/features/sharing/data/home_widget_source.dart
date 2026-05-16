import 'dart:async';

import 'package:home_widget/home_widget.dart' as plugin;

import '../domain/incoming_share.dart';
import '../domain/incoming_share_source.dart';

/// Thin wrapper over the `home_widget` plugin's static API so this
/// source can be unit-tested without booting a real platform channel.
abstract class HomeWidgetClient {
  Future<String?> getString(String key);
  Future<void> clear(String key);

  /// Stream of "widget tapped" notifications. Each event triggers a
  /// drain of the pending-capture key. Implementations should never
  /// close this stream while the app is running.
  Stream<Uri?> get clicked;
}

/// Real-plugin-backed [HomeWidgetClient]. Calls
/// `HomeWidget.getWidgetData` / `HomeWidget.saveWidgetData`.
class DefaultHomeWidgetClient implements HomeWidgetClient {
  const DefaultHomeWidgetClient();

  @override
  Future<String?> getString(String key) =>
      plugin.HomeWidget.getWidgetData<String>(key);

  @override
  Future<void> clear(String key) =>
      plugin.HomeWidget.saveWidgetData<String>(key, '');

  @override
  Stream<Uri?> get clicked => plugin.HomeWidget.widgetClicked;
}

/// G1 — drains an "Add to Inbox" home-screen widget's text payload
/// into the existing inbound-share pipeline. The OS-side widget
/// writes a single string under the [pendingCaptureKey]; this source
/// reads it (once on `initial()` for the launch-via-widget case, and
/// again on every `clicked` event for live taps), then clears the
/// slot so the same capture isn't re-emitted.
class HomeWidgetSource implements IncomingShareSource {
  HomeWidgetSource({
    HomeWidgetClient? client,
    this.pendingCaptureKey = 'pending_capture',
  }) : _client = client ?? const DefaultHomeWidgetClient();

  final HomeWidgetClient _client;
  final String pendingCaptureKey;
  final _controller = StreamController<List<IncomingShare>>.broadcast();
  StreamSubscription<Uri?>? _sub;

  @override
  Future<List<IncomingShare>> initial() async {
    return _drainOnce();
  }

  @override
  Stream<List<IncomingShare>> get stream {
    _sub ??= _client.clicked.listen((_) async {
      final batch = await _drainOnce();
      if (batch.isNotEmpty) _controller.add(batch);
    });
    return _controller.stream;
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    _sub = null;
    await _controller.close();
  }

  Future<List<IncomingShare>> _drainOnce() async {
    final raw = await _client.getString(pendingCaptureKey);
    if (raw == null || raw.trim().isEmpty) return const [];
    // Clear immediately so a subsequent click doesn't re-emit the
    // same capture. Fire-and-forget — losing the clear in the rare
    // crash case is harmless (worst outcome is a duplicate line in
    // Inbox/Quick capture.md).
    unawaited(_client.clear(pendingCaptureKey));
    return [IncomingShare(text: raw.trim(), kind: ShareKind.text)];
  }
}
