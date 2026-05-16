import 'dart:async';

import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../domain/incoming_share.dart';
import '../domain/incoming_share_source.dart';

/// Adapter wrapping `receive_sharing_intent` into the Quill-side
/// [IncomingShareSource] contract. Keeps the rest of the codebase
/// decoupled from the package's evolving type names (it has reshuffled
/// `SharedMediaFile` more than once across 1.x).
class ReceiveSharingIntentSource implements IncomingShareSource {
  ReceiveSharingIntentSource({ReceiveSharingIntent? instance})
      : _instance = instance ?? ReceiveSharingIntent.instance;

  final ReceiveSharingIntent _instance;
  StreamSubscription<List<SharedMediaFile>>? _sub;
  final _controller = StreamController<List<IncomingShare>>.broadcast();

  @override
  Future<List<IncomingShare>> initial() async {
    final initial = await _instance.getInitialMedia();
    return initial.map(_map).toList();
  }

  @override
  Stream<List<IncomingShare>> get stream {
    _sub ??= _instance.getMediaStream().listen((batch) {
      _controller.add(batch.map(_map).toList());
    });
    return _controller.stream;
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    _sub = null;
    await _controller.close();
  }

  IncomingShare _map(SharedMediaFile file) {
    final raw = file.path;
    final kind = switch (file.type) {
      SharedMediaType.url => ShareKind.url,
      SharedMediaType.text => ShareKind.text,
      _ => ShareKind.file,
    };
    return IncomingShare(text: raw, kind: kind);
  }
}
