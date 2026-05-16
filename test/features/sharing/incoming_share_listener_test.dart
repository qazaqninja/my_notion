import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/sharing/domain/incoming_share.dart';
import 'package:my_notion/features/sharing/domain/incoming_share_source.dart';
import 'package:my_notion/features/sharing/presentation/incoming_share_listener.dart';

class _FakeSource implements IncomingShareSource {
  _FakeSource({this.initialPayload = const []});
  final List<IncomingShare> initialPayload;
  final _controller = StreamController<List<IncomingShare>>.broadcast();
  bool closed = false;
  int initialCalls = 0;

  @override
  Future<List<IncomingShare>> initial() async {
    initialCalls++;
    return initialPayload;
  }

  @override
  Stream<List<IncomingShare>> get stream => _controller.stream;

  @override
  Future<void> close() async {
    closed = true;
    await _controller.close();
  }

  void emit(List<IncomingShare> batch) => _controller.add(batch);
}

/// F1 — verifies the listener drains the OS-queued initial payload and
/// then funnels live share-stream events into QuickCapture-equivalent
/// append calls. Uses a fake appender so we never touch disk.
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('quill_share_test_');
  });
  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('Initial payload is appended at start()', () async {
    final source = _FakeSource(initialPayload: const [
      IncomingShare(text: 'first-launch-link', kind: ShareKind.url),
      IncomingShare(text: '   ', kind: ShareKind.text), // dropped (empty)
      IncomingShare(text: 'second-thing', kind: ShareKind.text),
    ]);
    final appended = <String>[];
    final listener = IncomingShareListener(
      source: source,
      vaultRoot: tempDir,
      appender: (text, _) async {
        appended.add(text);
        return 'Inbox/Quick capture.md';
      },
    );
    await listener.start();
    expect(appended, ['first-launch-link', 'second-thing']);
    expect(listener.handled, 2);
    expect(listener.isListening, isTrue);
    await listener.stop();
  });

  test('Live stream batches are appended in order', () async {
    final source = _FakeSource();
    final appended = <String>[];
    final listener = IncomingShareListener(
      source: source,
      vaultRoot: tempDir,
      appender: (text, _) async {
        appended.add(text);
        return 'Inbox/Quick capture.md';
      },
    );
    await listener.start();
    source.emit(const [IncomingShare(text: 'one')]);
    source.emit(const [
      IncomingShare(text: 'two'),
      IncomingShare(text: 'three'),
    ]);
    // Let the microtasks settle.
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(appended, ['one', 'two', 'three']);
    expect(listener.handled, 3);
    await listener.stop();
  });

  test('Empty / whitespace-only shares are skipped, not appended', () async {
    final source = _FakeSource();
    final appended = <String>[];
    final listener = IncomingShareListener(
      source: source,
      vaultRoot: tempDir,
      appender: (text, _) async {
        appended.add(text);
        return 'Inbox/Quick capture.md';
      },
    );
    await listener.start();
    source.emit(const [
      IncomingShare(text: ''),
      IncomingShare(text: '   '),
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(appended, isEmpty);
    expect(listener.handled, 0);
    await listener.stop();
  });

  test('Appender throwing for one share does not kill the subscription',
      () async {
    final source = _FakeSource();
    final appended = <String>[];
    var bombCount = 0;
    final listener = IncomingShareListener(
      source: source,
      vaultRoot: tempDir,
      appender: (text, _) async {
        if (text == 'boom') {
          bombCount++;
          throw const FileSystemException('disk on fire');
        }
        appended.add(text);
        return 'Inbox/Quick capture.md';
      },
    );
    await listener.start();
    source.emit(const [
      IncomingShare(text: 'good-1'),
      IncomingShare(text: 'boom'),
      IncomingShare(text: 'good-2'),
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(appended, ['good-1', 'good-2']);
    expect(bombCount, 1);
    // handled only counts successes — 2 good ones got through.
    expect(listener.handled, 2);
    await listener.stop();
  });

  test('start() is idempotent — second call replaces the subscription',
      () async {
    final source = _FakeSource(
      initialPayload: const [IncomingShare(text: 'initial-A')],
    );
    final appended = <String>[];
    final listener = IncomingShareListener(
      source: source,
      vaultRoot: tempDir,
      appender: (text, _) async {
        appended.add(text);
        return 'Inbox/Quick capture.md';
      },
    );
    await listener.start();
    await listener.start();
    // The initial payload is fetched twice (we don't dedupe at the
    // listener boundary — the underlying plugin clears its queue
    // between calls, but our fake doesn't model that). What we DO
    // guarantee is that no double-listening happens — a single live
    // emit lands once.
    source.emit(const [IncomingShare(text: 'live-1')]);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(appended.where((s) => s == 'live-1').length, 1);
    await listener.stop();
  });
}
