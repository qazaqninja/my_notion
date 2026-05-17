import 'package:super_editor/super_editor.dart';

/// Map a slash-entry [SlashEntry.linePrefix] string to the matching
/// super_editor `blockType` metadata attribution.
///
/// Used by EditorBetaPage (slice 2g-c, M1541) to translate a convert-
/// in-place slash pick into a `ChangeParagraphBlockTypeRequest` against
/// the node containing the trigger. Source-mode (`SourceView`) achieves
/// the same effect by prepending the literal prefix to the line text;
/// in WYSIWYG the block kind is metadata, not text, so the prefix maps
/// to a NamedAttribution instead of a string splice.
///
/// Returns null for prefixes that don't correspond to a simple
/// blockType swap — e.g. lists (`'- '`, `'1. '`) and todos (`'- [ ] '`)
/// require a ParagraphNode → ListItemNode/TaskNode node-type change
/// that's a node-replace operation, not a metadata edit. The caller
/// should treat null as "deferred" and either no-op or fall through to
/// a follow-up slice (2g-d).
NamedAttribution? blockTypeForLinePrefix(String linePrefix) {
  switch (linePrefix) {
    case '# ':
      return header1Attribution;
    case '## ':
      return header2Attribution;
    case '### ':
      return header3Attribution;
    case '> ':
      return blockquoteAttribution;
  }
  return null;
}
