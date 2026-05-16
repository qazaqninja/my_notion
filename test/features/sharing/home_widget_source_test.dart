import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/sharing/data/home_widget_source.dart';
import 'package:my_notion/features/sharing/domain/incoming_share.dart';

class _FakeClient implements HomeWidgetClient {
  _FakeClient({this.initialValue});
  String? initialValue;
  int getCalls = 0;
  int clearCalls = 0;
  final _clickedController = StreamController<Uri?>.broadcast();

  @override
  Future<String?> getString(String key) async {
    getCalls++;
    final v = initialValue;
    return v;
  }

  @override
  Future<void> clear(String key) async {
    clearCalls++;
    initialValue = '';
  }

  @override
  Stream<Uri?> get clicked => _clickedController.stream;

  void fireClick({Uri? uri}) => _clickedController.add(uri);

  Future<void> dispose() => _clickedController.close();
}

/// G1 — drains the home_widget "Add to Inbox" payload via the same
/// IncomingShareSource interface the share-sheet uses. Verifies the
/// drain-and-clear flow plus the click → re-drain loop.
void main() {
  test('initial() returns the queued capture when the key is set', () async {
    final client = _FakeClient(initialValue: 'visit-quill.dev');
    final source = HomeWidgetSource(client: client);
    final batch = await source.initial();
    expect(batch, [
      const IncomingShare(text: 'visit-quill.dev', kind: ShareKind.text),
    ]);
    // The drain clears the key so the next call doesn't re-emit.
    expect(client.clearCalls, 1);
    await source.close();
    await client.dispose();
  });

  test('initial() returns empty when the key is missing or blank',
      () async {
    // Missing.
    var source = HomeWidgetSource(client: _FakeClient());
    expect(await source.initial(), isEmpty);
    await source.close();

    // Blank.
    final client = _FakeClient(initialValue: '   ');
    source = HomeWidgetSource(client: client);
    expect(await source.initial(), isEmpty);
    expect(client.clearCalls, 0); // blank reads do NOT clear
    await source.close();
    await client.dispose();
  });

  test('click on the widget emits a fresh capture on the stream',
      () async {
    final client = _FakeClient();
    final source = HomeWidgetSource(client: client);
    final batches = <List<IncomingShare>>[];
    final sub = source.stream.listen(batches.add);
    // Give the listen() registration a chance to wire up before we
    // fire — broadcast streams without listeners drop events.
    await Future<void>.delayed(const Duration(milliseconds: 5));

    // Simulate the OS-side widget writing a payload then issuing
    // a click.
    client.initialValue = 'note-from-widget';
    client.fireClick();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(batches.length, 1);
    expect(batches.first, [
      const IncomingShare(
        text: 'note-from-widget',
        kind: ShareKind.text,
      ),
    ]);
    expect(client.clearCalls, 1);

    await sub.cancel();
    await source.close();
    await client.dispose();
  });

  test('click with no pending capture is a no-op (does not emit)',
      () async {
    final client = _FakeClient();
    final source = HomeWidgetSource(client: client);
    final batches = <List<IncomingShare>>[];
    final sub = source.stream.listen(batches.add);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    client.fireClick();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(batches, isEmpty);
    expect(client.clearCalls, 0);
    await sub.cancel();
    await source.close();
    await client.dispose();
  });

  test('close() is idempotent + cancels the subscription', () async {
    final client = _FakeClient();
    final source = HomeWidgetSource(client: client);
    // Force subscription creation.
    final dummySub = source.stream.listen((_) {});
    await source.close();
    await source.close(); // second call must not throw
    await dummySub.cancel();
    await client.dispose();
  });
}
