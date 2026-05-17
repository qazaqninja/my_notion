import 'dart:convert';

import 'package:equatable/equatable.dart';

/// H4b — client-side mirror of the backend
/// `backend/lib/sync/awareness_message.dart` wire DTO (M1448).
/// Identical JSON shape so encode/decode round-trips across the
/// existing per-page WebSocket sub channel.
///
/// Wire format:
/// ```json
/// {
///   "kind": "awareness",
///   "userId": "01HX...",
///   "pageUlid": "01HX...",
///   "cursorIndex": 42,
///   "color": "#FF5722"
/// }
/// ```
///
/// The Flutter side uses Equatable rather than the backend's
/// hand-rolled `operator ==` because `equatable` is already a
/// transitive dep on every other state class in the project, so
/// the cost is zero here and the consistency is worth more than
/// the symmetry with the backend file.
class AwarenessMessage extends Equatable {
  const AwarenessMessage({
    required this.userId,
    required this.pageUlid,
    required this.cursorIndex,
    required this.color,
  });

  factory AwarenessMessage.fromJson(Map<String, Object?> json) {
    final k = json['kind'];
    if (k != kind) {
      throw FormatException(
          'expected kind="$kind", got "${k ?? 'null'}"');
    }
    final userId = json['userId'];
    final pageUlid = json['pageUlid'];
    final cursorIndex = json['cursorIndex'];
    final color = json['color'];
    if (userId is! String ||
        pageUlid is! String ||
        cursorIndex is! int ||
        color is! String) {
      throw const FormatException(
          'awareness message missing required field(s)');
    }
    return AwarenessMessage(
      userId: userId,
      pageUlid: pageUlid,
      cursorIndex: cursorIndex,
      color: color,
    );
  }

  /// Wire kind tag — always `'awareness'`. The H4d dispatcher
  /// uses this to route incoming WS payloads between CRDT updates
  /// and presence cursors.
  static const String kind = 'awareness';

  /// Stable user identifier. Multiple devices for the same user
  /// share this so the overlay merges them under one cursor.
  final String userId;

  /// Page being cursored on. Redundant for routing (the WS room
  /// is already segmented by ulid) but lets receivers double-
  /// check they're processing the right page.
  final String pageUlid;

  /// Zero-based char offset in the source-mode body.
  final int cursorIndex;

  /// Display color, e.g. `'#FF5722'`. Sender-derived from a
  /// userId hash so two devices for the same user match.
  final String color;

  Map<String, Object?> toJson() => {
        'kind': kind,
        'userId': userId,
        'pageUlid': pageUlid,
        'cursorIndex': cursorIndex,
        'color': color,
      };

  String encode() => jsonEncode(toJson());

  /// Returns null instead of throwing — H4d's dispatcher uses
  /// this to fall through to the CRDT update handler when the
  /// payload isn't an awareness envelope.
  static AwarenessMessage? tryDecode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?>) return null;
      return AwarenessMessage.fromJson(decoded);
    } on FormatException {
      return null;
    }
  }

  @override
  List<Object?> get props => [userId, pageUlid, cursorIndex, color];
}
