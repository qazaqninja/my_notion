import 'incoming_share.dart';

/// Streaming source of OS-share-sheet payloads. Abstracted away from
/// the `receive_sharing_intent` plugin so tests can inject a fake.
///
/// Implementations should:
///   - Drain any initial-launch payload via [initial] (the OS may have
///     queued a share that opened the app).
///   - Emit subsequent live shares on [stream] until [close] is called.
abstract class IncomingShareSource {
  /// Drains the OS-queued payload from when the app was launched via
  /// the share-sheet. Returns the empty list if there was none.
  Future<List<IncomingShare>> initial();

  /// Live shares received while the app is running.
  Stream<List<IncomingShare>> get stream;

  /// Stops listening. Idempotent.
  Future<void> close();
}
