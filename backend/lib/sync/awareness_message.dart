import 'dart:convert';

/// H4a — wire DTO for presence "awareness" messages broadcast over
/// the existing per-page WebSocket sub channel.
///
/// The existing [WsHub] is opaque to payload — it just fans out
/// `String` messages to peers of the same `(userId, pageUlid)`
/// room. Awareness piggybacks on that channel by tagging every
/// message with a `kind:` discriminator so receivers can route
/// `'awareness'` to the cursor overlay and `'update'` to the CRDT
/// merge pipeline.
///
/// Wire format (JSON, UTF-8 encoded then base64 stays optional — the
/// existing channel is text):
/// ```
/// {
///   "kind": "awareness",
///   "userId": "01HX...",
///   "pageUlid": "01HX...",
///   "cursorIndex": 42,
///   "color": "#FF5722"
/// }
/// ```
///
/// `color` is derived client-side from a deterministic hash of
/// userId so two devices for the same user paint the same cursor.
/// The backend doesn't validate it — bad input is the sender's
/// problem; peers just render whatever they get.
class AwarenessMessage {
  const AwarenessMessage({
    required this.userId,
    required this.pageUlid,
    required this.cursorIndex,
    required this.color,
  });

  /// Wire kind tag — always `'awareness'`. Used by the dispatcher
  /// in H4b to route incoming messages.
  static const String kind = 'awareness';

  /// Stable identifier of the user that owns this cursor. Multiple
  /// devices for the same user share the same userId so the overlay
  /// in H4c can merge them under a single avatar dot.
  final String userId;

  /// Page being cursored on. The hub already segments rooms by
  /// `(ownerId, pageUlid)`, so this field is redundant for routing
  /// but lets receivers double-check they're processing the right
  /// page in case of out-of-band channel reuse.
  final String pageUlid;

  /// Caret position in the source-mode markdown body, zero-based
  /// character offset. Sent on every meaningful cursor move
  /// (clients should debounce — H4b adds the throttle).
  final int cursorIndex;

  /// Display color, e.g. `'#FF5722'`. Sender-derived; no validation.
  final String color;

  /// Encode to the wire JSON object. Includes the kind discriminator.
  Map<String, Object?> toJson() => {
        'kind': kind,
        'userId': userId,
        'pageUlid': pageUlid,
        'cursorIndex': cursorIndex,
        'color': color,
      };

  /// Encode to a JSON string ready to push to [WsHub.broadcast].
  String encode() => jsonEncode(toJson());

  /// Inverse of [toJson]. Throws [FormatException] when the JSON
  /// is missing required fields or has the wrong `kind` tag — that
  /// way the H4b dispatcher can fall through to the next handler
  /// (e.g. CRDT update) on a mismatch.
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

  /// Convenience round-trip from the raw wire string. Returns null
  /// (rather than throws) when the string isn't a valid awareness
  /// envelope — H4b's dispatcher will pass it through to the next
  /// handler.
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
  bool operator ==(Object other) =>
      other is AwarenessMessage &&
      other.userId == userId &&
      other.pageUlid == pageUlid &&
      other.cursorIndex == cursorIndex &&
      other.color == color;

  @override
  int get hashCode => Object.hash(userId, pageUlid, cursorIndex, color);

  @override
  String toString() =>
      'AwarenessMessage($userId@$pageUlid → idx=$cursorIndex, color=$color)';
}
