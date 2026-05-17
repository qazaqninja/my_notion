import 'package:super_editor/super_editor.dart';

/// Three pure-function mappers that translate a slash-entry
/// [SlashEntry.linePrefix] into the corresponding super_editor convert-
/// in-place request kind. Each returns null / false when the prefix
/// doesn't apply, so the caller (`EditorBetaPage._onSlashEntryPicked`)
/// can try them in sequence:
///
/// 1. [blockTypeForLinePrefix] — `# `, `## `, `### `, `> ` →
///    `ChangeParagraphBlockTypeRequest`.
/// 2. [listItemTypeForLinePrefix] — `- `, `1. ` →
///    `ConvertParagraphToListItemRequest`.
/// 3. [isTaskLinePrefix] — `- [ ] ` →
///    `ConvertParagraphToTaskRequest`.
///
/// Source-mode (`SourceView`) achieves the same effects by prepending
/// the literal prefix to the line text; in WYSIWYG the block kind is
/// either metadata or a different node class, so the prefix maps to a
/// request shape rather than a string splice.

/// Map `# `, `## `, `### `, `> ` to header1/2/3 + blockquote
/// attributions. Null for any other prefix.
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

/// Map `- ` to unordered, `1. ` to ordered. Null for any other prefix —
/// including task `- [ ] `, which is checked separately via
/// [isTaskLinePrefix].
ListItemType? listItemTypeForLinePrefix(String linePrefix) {
  switch (linePrefix) {
    case '- ':
      return ListItemType.unordered;
    case '1. ':
      return ListItemType.ordered;
  }
  return null;
}

/// True iff [linePrefix] is the todo prefix `- [ ] `. Caller dispatches
/// `ConvertParagraphToTaskRequest(isComplete: false)` when true.
bool isTaskLinePrefix(String linePrefix) => linePrefix == '- [ ] ';
