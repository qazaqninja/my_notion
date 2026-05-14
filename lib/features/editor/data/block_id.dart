/// Obsidian-compatible `^<ULID>` block-id suffix handling.
///
/// Block IDs are persistent and stored at the end of a paragraph /
/// heading / list-item line as ` ^<26-char-ULID>`. They are
/// invisible in rendered mode (the parser strips them) but survive
/// disk round-trips because the source bytes are preserved verbatim
/// outside the visible text.
///
/// Block IDs are written lazily — only when a user attaches a comment
/// to a block. The renderer's `_Block` parser drops any trailing
/// `^<id>` from the displayed text via [BlockId.split], and the
/// CommentsService can anchor `PageComment.blockId` to the same ULID.
library;

class BlockId {
  const BlockId._();

  /// Matches a trailing `^<26-char-Crockford-uppercase-ULID>` optionally
  /// preceded by a single space. Strict so emoji or wiki `^something`
  /// constructs don't accidentally consume.
  static final _re = RegExp(r' \^([0-9A-Z]{26})\s*$');

  /// Split a single line into `(visibleText, blockId?)`. The block ID
  /// is returned without the `^` prefix; the visible text drops the
  /// trailing ` ^<id>` suffix (including the leading space).
  ///
  /// Returns `(text, null)` when no suffix is present.
  static (String, String?) split(String line) {
    final m = _re.firstMatch(line);
    if (m == null) return (line, null);
    return (line.substring(0, m.start), m.group(1));
  }

  /// Pure helper to append a block ID to a line. No-op when the line
  /// already ends with the same id. Replaces any pre-existing block-id
  /// suffix.
  static String append(String line, String id) {
    final stripped = split(line).$1;
    return '$stripped ^$id';
  }
}
