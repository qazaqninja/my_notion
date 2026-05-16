import 'package:equatable/equatable.dart';

/// One payload received from the OS share-sheet (F1). Maps over the
/// `receive_sharing_intent` package's `SharedMediaFile` representation
/// into a flat `(text, kind)` shape — enough for Quill's append-to-
/// Inbox flow, decoupled from the package's evolving type names.
class IncomingShare extends Equatable {
  const IncomingShare({required this.text, this.kind = ShareKind.text});

  final String text;
  final ShareKind kind;

  @override
  List<Object?> get props => [text, kind];
}

enum ShareKind { text, url, file }
