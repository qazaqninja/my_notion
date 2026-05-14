/// Entries shown by the slash command menu. Each entry carries:
/// - [icon]: QuillIcon name
/// - [label]: shown bold in the row
/// - [hint]: shown right-aligned (e.g. "H1", "→")
/// - [keywords]: extra strings the query matches against
/// - [snippet]: the markdown to splice at the cursor
/// - [cursorOffset]: caret position inside [snippet] after splice; defaults
///   to end of snippet
class SlashEntry {
  const SlashEntry({
    required this.icon,
    required this.label,
    required this.hint,
    required this.snippet,
    this.cursorOffset,
    this.keywords = const [],
  });

  final String icon;
  final String label;
  final String hint;
  final String snippet;
  final int? cursorOffset;
  final List<String> keywords;

  /// Where the caret should land after insertion.
  int caretAfterInsert(int insertOffset) =>
      insertOffset + (cursorOffset ?? snippet.length);
}

/// The default catalog. New entries land here.
const List<SlashEntry> kSlashEntries = [
  SlashEntry(
    icon: 'note',
    label: 'Heading 1',
    hint: 'H1',
    snippet: '# ',
    keywords: ['h1', 'title', 'heading'],
  ),
  SlashEntry(
    icon: 'note',
    label: 'Heading 2',
    hint: 'H2',
    snippet: '## ',
    keywords: ['h2', 'heading'],
  ),
  SlashEntry(
    icon: 'note',
    label: 'Heading 3',
    hint: 'H3',
    snippet: '### ',
    keywords: ['h3', 'heading'],
  ),
  SlashEntry(
    icon: 'note',
    label: 'Bulleted list',
    hint: '•',
    snippet: '- ',
    keywords: ['ul', 'bullet', 'list'],
  ),
  SlashEntry(
    icon: 'note',
    label: 'Numbered list',
    hint: '1.',
    snippet: '1. ',
    keywords: ['ol', 'ordered', 'list', 'number'],
  ),
  SlashEntry(
    icon: 'checksquare',
    label: 'To-do',
    hint: '☐',
    snippet: '- [ ] ',
    keywords: ['todo', 'task', 'checkbox', 'check'],
  ),
  SlashEntry(
    icon: 'note',
    label: 'Quote',
    hint: '> ',
    snippet: '> ',
    keywords: ['quote', 'blockquote'],
  ),
  SlashEntry(
    icon: 'note',
    label: 'Callout',
    hint: '! ',
    snippet: '> [!NOTE]\n> ',
    keywords: ['callout', 'note', 'admonition', 'info'],
  ),
  SlashEntry(
    icon: 'note',
    label: 'Divider',
    hint: '---',
    snippet: '\n---\n\n',
    keywords: ['hr', 'rule', 'divider', 'separator'],
  ),
  SlashEntry(
    icon: 'code',
    label: 'Code block',
    hint: '```',
    snippet: '```\n\n```\n',
    cursorOffset: 4, // inside the empty fence
    keywords: ['code', 'fence', 'block', 'snippet'],
  ),
  SlashEntry(
    icon: 'code',
    label: 'Inline math',
    hint: r'$x$',
    snippet: r'$$',
    cursorOffset: 1,
    keywords: ['math', 'latex', 'katex', 'tex'],
  ),
  SlashEntry(
    icon: 'code',
    label: 'Math block',
    hint: r'$$…$$',
    snippet: '\$\$\n\n\$\$\n',
    cursorOffset: 3,
    keywords: ['math', 'block', 'equation', 'latex', 'katex'],
  ),
  SlashEntry(
    icon: 'table',
    label: 'Table',
    hint: '⫼',
    snippet: '| col1 | col2 |\n| --- | --- |\n|  |  |\n',
    keywords: ['table', 'grid'],
  ),
  SlashEntry(
    icon: 'note',
    label: 'Page link',
    hint: '[[',
    snippet: '[[',
    keywords: ['link', 'page', 'wikilink', 'relation', 'mention'],
  ),
];

/// Filter the catalog by [query] (case-insensitive). Empty query returns all.
List<SlashEntry> filterSlashEntries(String query) {
  if (query.isEmpty) return kSlashEntries;
  final q = query.toLowerCase();
  return [
    for (final e in kSlashEntries)
      if (e.label.toLowerCase().contains(q) ||
          e.keywords.any((k) => k.contains(q)))
        e,
  ];
}
