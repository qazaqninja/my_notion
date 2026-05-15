/// Some entries trigger an async UI flow (file picker, etc.) rather than
/// inserting a literal snippet. The source view dispatches based on [action].
enum SlashAction {
  insertSnippet,
  pickImage,
  pickFile,
  insertToday,
  insertTimestamp,
  insertDailyNoteLink,
  pickEmoji,
  insertRandomPageLink,
  insertCurrentUser,
  /// Reverse the order of the lines in the current selection. Falls
  /// back to a single-line no-op when there is no selection.
  reverseSelectedLines,
  /// Walk the entire body for `:shortcode:` patterns and replace each
  /// match with its emoji glyph (`:tada:` → 🎉). Unknown shortcodes
  /// stay verbatim.
  expandEmojiShortcodes,
  /// Strip trailing whitespace from every line in the selection (or
  /// the entire body when no selection is active). Common cleanup
  /// before committing — many tools reject trailing whitespace.
  trimTrailingWhitespace,
  /// Uppercase the lines touched by the selection.
  uppercaseSelectedLines,
  /// Lowercase the lines touched by the selection.
  lowercaseSelectedLines,
  /// Title-case the lines touched by the selection.
  titleCaseSelectedLines,
  /// Insert a freshly-generated ULID at the caret. Useful for users
  /// who want a stable placeholder identifier before they decide what
  /// the linked page will be.
  insertUlid,
  /// Insert yesterday's date as a `@YYYY-MM-DD` pill.
  insertYesterday,
  /// Insert tomorrow's date as a `@YYYY-MM-DD` pill.
  insertTomorrow,
  /// Sort the lines touched by the selection in descending order
  /// (Z→A, case-insensitive).
  sortLinesDescending,
  /// Toggle a `- ` bullet prefix on every line in the selection. Strips
  /// the prefix when every line already has it; adds it otherwise.
  toggleBulletList,
  /// Toggle a `- [ ] ` task-list prefix on every line in the selection.
  /// Strips when every line is already a task; adds an unchecked
  /// checkbox otherwise.
  toggleTaskList,
  /// Toggle a `N. ` numbered-list prefix on every line in the
  /// selection. Adding renumbers from 1; stripping recognises any
  /// `\d+. ` prefix.
  toggleNumberedList,
  /// Sort the lines touched by the selection using **natural**
  /// ordering (file2 < file10).
  sortLinesNatural,
  /// Toggle a `> ` blockquote prefix on every line in the selection.
  /// Strips when every line is already quoted; adds otherwise.
  toggleBlockquote,
  /// Shuffle the lines touched by the selection uniformly at random.
  shuffleLines,
  /// Slugify every line in the selection (e.g. "My Cool Title" →
  /// "my-cool-title"). Useful for generating URL fragments.
  slugifyLines,
  /// Sentence-case every line in the selection. Lowercases the whole
  /// line then capitalises the first letter of each sentence.
  sentenceCaseSelectedLines,
  /// Strip leading whitespace (spaces / tabs) from every line in the
  /// selection. The trim-trailing-whitespace mirror.
  stripLeadingWhitespace,
  /// Replace every tab on every selected line with 2 spaces.
  tabsToSpaces,
  /// Convert every leading 2-space indent on every selected line
  /// into a tab. Inverse of [tabsToSpaces] (indent-only).
  spacesToTabs,
  /// Convert decimal integers on every selected line to Roman
  /// numerals (1..3999). Non-numeric lines stay untouched.
  decimalToRoman,
  /// Convert Roman numerals on every selected line to decimal.
  romanToDecimal,
  /// Apply typographic substitutions to every selected line:
  /// `"x"` → `“x”`, `'x'` → `‘x’`, `...` → `…`, `--` → `—`.
  smartTypography,
  /// Inverse of [smartTypography]: turn Unicode typographic
  /// characters back into ASCII.
  dumbifyTypography,
  /// Base64-encode every selected line using UTF-8 bytes.
  base64Encode,
  /// Base64-decode every selected line; invalid Base64 stays as-is.
  base64Decode,
  /// URL-encode every selected line via Uri.encodeComponent.
  urlEncode,
  /// URL-decode every selected line; malformed sequences stay as-is.
  urlDecode,
  /// Convert decimal integers on every selected line to lowercase
  /// hex prefixed with `0x`.
  decimalToHex,
  /// Convert hex values (with or without `0x`) on every selected
  /// line to decimal.
  hexToDecimal,
  /// Reverse the characters of every selected line in place.
  reverseCharactersInLine,
  /// Apply the ROT13 cipher per line (its own inverse).
  rot13,
  /// HTML-escape the 5 standard entities on every selected line.
  htmlEscape,
  /// HTML-unescape the 5 standard entities on every selected line.
  htmlUnescape,
  /// Convert decimal integers on every selected line to binary `0b…`.
  decimalToBinary,
  /// Convert `0b1010`-prefixed binary on every selected line to
  /// decimal.
  binaryToDecimal,
  /// Convert decimal integers on every selected line to octal `0o…`.
  decimalToOctal,
  /// Convert `0o`-prefixed octal on every selected line to decimal.
  octalToDecimal,
  /// Left-pad every selected line with `0` so it reaches the
  /// length of the longest line in the block (auto width).
  zeroPadLines,
  /// Right-pad every selected line with spaces to the longest
  /// line's width — for column alignment.
  padRightLines,
  /// Insert a one-line stats summary (`(N words · N characters · N
  /// lines)`) about the surrounding body at the caret.
  insertTextStats,
  /// Sort the lines touched by the selection by length, shortest
  /// first.
  sortLinesByLength,
  /// Sort the lines touched by the selection by length, longest
  /// first.
  sortLinesByLengthDesc,
  /// Reverse the words on every selected line (preserving any
  /// trailing whitespace).
  reverseWordsInLine,
  /// Center every selected line within a uniform field of spaces.
  centerLines,
  /// Collapse selected lines into a single comma-separated row.
  joinLinesWithComma,
  /// Split each selected line on `,` into multiple lines.
  splitOnComma,
  /// Convert every selected line to `snake_case`.
  snakeCaseLines,
  /// Convert every selected line to `camelCase`.
  camelCaseLines,
  /// Convert every selected line to `PascalCase`.
  pascalCaseLines,
  /// Convert every selected line to `CONSTANT_CASE`.
  constantCaseLines,
  /// Wrap every non-blank selected line in `**…**`.
  boldLines,
  /// Wrap every non-blank selected line in `*…*`.
  italicLines,
  /// Wrap every non-blank selected line in `` `…` ``.
  codeLines,
  /// Wrap every non-blank selected line in `~~…~~`.
  strikethroughLines,
  /// Wrap every non-blank selected line in `==…==`.
  highlightLines,
  /// Strip outer markdown-formatting marks (`**…**`, `*…*`, `~~…~~`,
  /// `==…==`, `` `…` ``) from each line.
  unwrapInlineFormatting,
  /// Insert a 16-char random password at the caret.
  insertPassword,
  /// Insert a UUID v4 at the caret (8-4-4-4-12 hyphenated form).
  insertUuid,
}

/// Entries shown by the slash command menu. Each entry carries:
/// - [icon]: QuillIcon name
/// - [label]: shown bold in the row
/// - [hint]: shown right-aligned (e.g. "H1", "→")
/// - [keywords]: extra strings the query matches against
/// - [snippet]: the markdown to splice at the cursor (for snippet entries)
/// - [cursorOffset]: caret position inside [snippet] after splice; defaults
///   to end of snippet
/// - [action]: defaults to insertSnippet
class SlashEntry {
  const SlashEntry({
    required this.icon,
    required this.label,
    required this.hint,
    this.snippet = '',
    this.cursorOffset,
    this.keywords = const [],
    this.action = SlashAction.insertSnippet,
    this.linePrefix,
  });

  final String icon;
  final String label;
  final String hint;
  final String snippet;
  final int? cursorOffset;
  final List<String> keywords;
  final SlashAction action;

  /// When non-null, picking this entry CONVERTS the current line by
  /// stripping its existing markdown prefix and prepending this one.
  /// Inline-style entries (page link, image, inline math) leave this
  /// null and fall back to plain snippet insertion at the cursor.
  final String? linePrefix;

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
    linePrefix: '# ',
    keywords: ['h1', 'title', 'heading'],
  ),
  SlashEntry(
    icon: 'note',
    label: 'Heading 2',
    hint: 'H2',
    snippet: '## ',
    linePrefix: '## ',
    keywords: ['h2', 'heading'],
  ),
  SlashEntry(
    icon: 'note',
    label: 'Heading 3',
    hint: 'H3',
    snippet: '### ',
    linePrefix: '### ',
    keywords: ['h3', 'heading'],
  ),
  SlashEntry(
    icon: 'note',
    label: 'Bulleted list',
    hint: '•',
    snippet: '- ',
    linePrefix: '- ',
    keywords: ['ul', 'bullet', 'list'],
  ),
  SlashEntry(
    icon: 'note',
    label: 'Numbered list',
    hint: '1.',
    snippet: '1. ',
    linePrefix: '1. ',
    keywords: ['ol', 'ordered', 'list', 'number'],
  ),
  SlashEntry(
    icon: 'checksquare',
    label: 'To-do',
    hint: '☐',
    snippet: '- [ ] ',
    linePrefix: '- [ ] ',
    keywords: ['todo', 'task', 'checkbox', 'check'],
  ),
  SlashEntry(
    icon: 'note',
    label: 'Quote',
    hint: '> ',
    snippet: '> ',
    linePrefix: '> ',
    keywords: ['quote', 'blockquote'],
  ),
  SlashEntry(
    icon: 'note',
    label: 'Quote with attribution',
    hint: '> "…" — author',
    snippet: '> \n> — ',
    // Caret right after `> ` on line 1 so the user types the quote
    // first; they then ↓ End to fill the author.
    cursorOffset: 2,
    keywords: ['quote', 'attribution', 'author', 'cite', 'citation'],
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
    label: 'Mermaid diagram',
    hint: '```mermaid',
    snippet: '```mermaid\ngraph TD\n  A[Start] --> B[End]\n```\n',
    cursorOffset: 18, // inside the diagram body
    keywords: ['mermaid', 'diagram', 'flowchart', 'graph', 'chart'],
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
  SlashEntry(
    icon: 'link',
    label: 'External link',
    hint: '⌘K',
    snippet: '[label](https://)',
    // Place caret right after the opening paren so the user can paste
    // a URL and immediately Tab back to edit the label.
    cursorOffset: 9,
    keywords: ['link', 'url', 'external', 'web', 'href'],
  ),
  SlashEntry(
    icon: 'file',
    label: 'Image',
    hint: '![',
    action: SlashAction.pickImage,
    keywords: ['image', 'picture', 'photo', 'upload'],
  ),
  SlashEntry(
    icon: 'file',
    label: 'File attachment',
    hint: 'pdf · doc · zip',
    action: SlashAction.pickFile,
    keywords: ['file', 'attach', 'pdf', 'doc', 'zip', 'video', 'audio'],
  ),
  SlashEntry(
    icon: 'note',
    label: 'Table of contents',
    hint: 'toc',
    snippet: '[toc]\n',
    keywords: ['toc', 'contents', 'outline', 'index'],
  ),
  SlashEntry(
    icon: 'note',
    label: 'Breadcrumb',
    hint: 'path',
    snippet: '[breadcrumb]\n',
    keywords: ['breadcrumb', 'path', 'trail', 'crumbs'],
  ),
  SlashEntry(
    icon: 'note',
    label: 'Toggle (collapsible)',
    hint: '⌄',
    snippet: '<details><summary>Summary</summary>\nBody\n</details>\n',
    cursorOffset: 19, // inside summary
    keywords: ['toggle', 'collapse', 'details', 'expand'],
  ),
  SlashEntry(
    icon: 'note',
    label: 'Two columns',
    hint: '⫶⫶',
    snippet: ':::cols\nLeft column\n:::col\nRight column\n:::\n',
    cursorOffset: 8, // start of "Left column"
    keywords: ['column', 'columns', 'cols', 'layout', 'side', 'two'],
  ),
  SlashEntry(
    icon: 'link',
    label: 'Button',
    hint: '⏵',
    snippet:
        ':::button\nlabel: Click me\naction: url\nvalue: https://example.com\n:::\n',
    cursorOffset: 17, // start of label text after "label: "
    keywords: ['button', 'action', 'link', 'url', 'click'],
  ),
  SlashEntry(
    icon: 'table',
    label: 'Inline database',
    hint: '⫼',
    snippet: ':::db Customers\nview: main\nlimit: 10\n:::\n',
    cursorOffset: 6, // after ":::db " ready for folder name
    keywords: ['db', 'database', 'inline', 'table', 'embed', 'view'],
  ),
  SlashEntry(
    icon: 'calendar',
    label: "Today's date",
    hint: '@today',
    action: SlashAction.insertToday,
    keywords: ['today', 'date', 'now', '@'],
  ),
  SlashEntry(
    icon: 'calendar',
    label: "Today's daily note link",
    hint: '[[…]]',
    action: SlashAction.insertDailyNoteLink,
    keywords: ['daily', 'today', 'journal', 'link', 'wikilink'],
  ),
  SlashEntry(
    icon: 'calendar',
    label: 'Current time',
    hint: '@now',
    action: SlashAction.insertTimestamp,
    keywords: ['now', 'time', 'timestamp', 'date'],
  ),
  SlashEntry(
    icon: 'users',
    label: 'Mention me',
    hint: '@me',
    action: SlashAction.insertCurrentUser,
    keywords: ['me', 'mention', 'user', 'self', 'assign'],
  ),
  SlashEntry(
    icon: 'sync',
    label: 'Reverse selected lines',
    hint: 'flip ↕',
    action: SlashAction.reverseSelectedLines,
    keywords: ['reverse', 'flip', 'invert', 'lines', 'rev'],
  ),
  SlashEntry(
    icon: 'sync',
    label: 'Sort lines descending',
    hint: 'Z → A',
    action: SlashAction.sortLinesDescending,
    keywords: ['sort', 'desc', 'descending', 'reverse', 'z-a', 'lines'],
  ),
  SlashEntry(
    icon: 'list',
    label: 'Toggle bullet list',
    hint: '- …',
    action: SlashAction.toggleBulletList,
    keywords: ['bullet', 'list', 'toggle', 'unordered', 'ul', 'dash'],
  ),
  SlashEntry(
    icon: 'check',
    label: 'Toggle task list',
    hint: '- [ ] …',
    action: SlashAction.toggleTaskList,
    keywords: ['task', 'todo', 'checkbox', 'list', 'toggle', 'check'],
  ),
  SlashEntry(
    icon: 'list',
    label: 'Toggle numbered list',
    hint: '1. …',
    action: SlashAction.toggleNumberedList,
    keywords: ['number', 'numbered', 'ordered', 'list', 'toggle', 'ol'],
  ),
  SlashEntry(
    icon: 'sync',
    label: 'Sort lines naturally',
    hint: 'file2 < file10',
    action: SlashAction.sortLinesNatural,
    keywords: ['natural', 'sort', 'numeric', 'human', 'version'],
  ),
  SlashEntry(
    icon: 'quote',
    label: 'Toggle blockquote',
    hint: '> …',
    action: SlashAction.toggleBlockquote,
    keywords: ['quote', 'blockquote', 'toggle', 'indent', 'gt'],
  ),
  SlashEntry(
    icon: 'sync',
    label: 'Shuffle selected lines',
    hint: '🎲',
    action: SlashAction.shuffleLines,
    keywords: ['shuffle', 'random', 'reorder', 'mix', 'randomize', 'lines'],
  ),
  SlashEntry(
    icon: 'link',
    label: 'Slugify selected lines',
    hint: 'a-b-c',
    action: SlashAction.slugifyLines,
    keywords: ['slug', 'slugify', 'url', 'permalink', 'anchor', 'kebab'],
  ),
  SlashEntry(
    icon: 'tag',
    label: 'Expand :shortcodes: → emoji',
    hint: ':tada: → 🎉',
    action: SlashAction.expandEmojiShortcodes,
    keywords: ['emoji', 'shortcode', 'expand', 'replace', 'tada', 'fire'],
  ),
  SlashEntry(
    icon: 'edit',
    label: 'Trim trailing whitespace',
    hint: 'cleanup',
    action: SlashAction.trimTrailingWhitespace,
    keywords: ['trim', 'whitespace', 'cleanup', 'strip', 'tabs'],
  ),
  SlashEntry(
    icon: 'edit',
    label: 'Strip leading whitespace',
    hint: 'left-trim',
    action: SlashAction.stripLeadingWhitespace,
    keywords: ['strip', 'leading', 'whitespace', 'indent', 'left', 'trim'],
  ),
  SlashEntry(
    icon: 'edit',
    label: 'Tabs → spaces',
    hint: '\\t → "  "',
    action: SlashAction.tabsToSpaces,
    keywords: ['tab', 'spaces', 'expand', 'convert', 'indent'],
  ),
  SlashEntry(
    icon: 'edit',
    label: 'Spaces → tabs',
    hint: '"  " → \\t',
    action: SlashAction.spacesToTabs,
    keywords: ['tab', 'spaces', 'compact', 'convert', 'indent'],
  ),
  SlashEntry(
    icon: 'hash',
    label: 'Decimal → Roman',
    hint: '7 → VII',
    action: SlashAction.decimalToRoman,
    keywords: ['roman', 'numeral', 'decimal', 'convert', 'number'],
  ),
  SlashEntry(
    icon: 'hash',
    label: 'Roman → decimal',
    hint: 'VII → 7',
    action: SlashAction.romanToDecimal,
    keywords: ['roman', 'numeral', 'decimal', 'convert', 'number'],
  ),
  SlashEntry(
    icon: 'quote',
    label: 'Smart typography',
    hint: '" → “ ” …',
    action: SlashAction.smartTypography,
    keywords: ['smart', 'quotes', 'typography', 'curly', 'ellipsis', 'dash'],
  ),
  SlashEntry(
    icon: 'quote',
    label: 'Dumbify typography',
    hint: '“ ” → "',
    action: SlashAction.dumbifyTypography,
    keywords: ['dumb', 'ascii', 'straight', 'quotes', 'typography', 'plain'],
  ),
  SlashEntry(
    icon: 'lock',
    label: 'Base64 encode',
    hint: 'abc → YWJj',
    action: SlashAction.base64Encode,
    keywords: ['base64', 'encode', 'b64'],
  ),
  SlashEntry(
    icon: 'lock',
    label: 'Base64 decode',
    hint: 'YWJj → abc',
    action: SlashAction.base64Decode,
    keywords: ['base64', 'decode', 'b64'],
  ),
  SlashEntry(
    icon: 'link',
    label: 'URL encode',
    hint: 'foo bar → foo%20bar',
    action: SlashAction.urlEncode,
    keywords: ['url', 'encode', 'percent', 'escape', 'query'],
  ),
  SlashEntry(
    icon: 'link',
    label: 'URL decode',
    hint: 'foo%20bar → foo bar',
    action: SlashAction.urlDecode,
    keywords: ['url', 'decode', 'percent', 'unescape', 'query'],
  ),
  SlashEntry(
    icon: 'hash',
    label: 'Decimal → hex',
    hint: '255 → 0xff',
    action: SlashAction.decimalToHex,
    keywords: ['hex', 'hexadecimal', 'decimal', 'convert', 'base16'],
  ),
  SlashEntry(
    icon: 'hash',
    label: 'Hex → decimal',
    hint: '0xff → 255',
    action: SlashAction.hexToDecimal,
    keywords: ['hex', 'hexadecimal', 'decimal', 'convert', 'base16'],
  ),
  SlashEntry(
    icon: 'sync',
    label: 'Reverse characters per line',
    hint: 'abc → cba',
    action: SlashAction.reverseCharactersInLine,
    keywords: ['reverse', 'mirror', 'flip', 'characters', 'chars', 'palindrome'],
  ),
  SlashEntry(
    icon: 'sync',
    label: 'Reverse words per line',
    hint: 'a b → b a',
    action: SlashAction.reverseWordsInLine,
    keywords: ['reverse', 'words', 'flip', 'mirror', 'order'],
  ),
  SlashEntry(
    icon: 'lock',
    label: 'ROT13',
    hint: 'a ↔ n, N ↔ A',
    action: SlashAction.rot13,
    keywords: ['rot13', 'cipher', 'caesar', 'encode', 'decode', 'fun'],
  ),
  SlashEntry(
    icon: 'code',
    label: 'HTML escape',
    hint: '< → &lt;',
    action: SlashAction.htmlEscape,
    keywords: ['html', 'escape', 'entity', 'amp', 'encode'],
  ),
  SlashEntry(
    icon: 'code',
    label: 'HTML unescape',
    hint: '&lt; → <',
    action: SlashAction.htmlUnescape,
    keywords: ['html', 'unescape', 'entity', 'decode'],
  ),
  SlashEntry(
    icon: 'hash',
    label: 'Decimal → binary',
    hint: '5 → 0b101',
    action: SlashAction.decimalToBinary,
    keywords: ['binary', 'decimal', 'convert', 'base2', 'bits'],
  ),
  SlashEntry(
    icon: 'hash',
    label: 'Binary → decimal',
    hint: '0b101 → 5',
    action: SlashAction.binaryToDecimal,
    keywords: ['binary', 'decimal', 'convert', 'base2', 'bits'],
  ),
  SlashEntry(
    icon: 'hash',
    label: 'Decimal → octal',
    hint: '8 → 0o10',
    action: SlashAction.decimalToOctal,
    keywords: ['octal', 'decimal', 'convert', 'base8'],
  ),
  SlashEntry(
    icon: 'hash',
    label: 'Octal → decimal',
    hint: '0o10 → 8',
    action: SlashAction.octalToDecimal,
    keywords: ['octal', 'decimal', 'convert', 'base8'],
  ),
  SlashEntry(
    icon: 'edit',
    label: 'Zero-pad lines',
    hint: '5 → 005',
    action: SlashAction.zeroPadLines,
    keywords: ['pad', 'zero', 'leading', 'align', 'right-align', 'numeric'],
  ),
  SlashEntry(
    icon: 'edit',
    label: 'Pad lines right with spaces',
    hint: 'abc → abc__',
    action: SlashAction.padRightLines,
    keywords: ['pad', 'right', 'trailing', 'align', 'column', 'spaces'],
  ),
  SlashEntry(
    icon: 'edit',
    label: 'Center lines',
    hint: 'a → _a_',
    action: SlashAction.centerLines,
    keywords: ['center', 'centre', 'align', 'pad', 'middle'],
  ),
  SlashEntry(
    icon: 'list',
    label: 'Join lines with comma',
    hint: 'a / b → a, b',
    action: SlashAction.joinLinesWithComma,
    keywords: ['join', 'comma', 'csv', 'collapse', 'flatten'],
  ),
  SlashEntry(
    icon: 'list',
    label: 'Split on comma',
    hint: 'a, b → a / b',
    action: SlashAction.splitOnComma,
    keywords: ['split', 'comma', 'csv', 'explode', 'separate'],
  ),
  SlashEntry(
    icon: 'edit',
    label: 'snake_case',
    hint: 'a_b_c',
    action: SlashAction.snakeCaseLines,
    keywords: ['snake', 'case', 'underscore', 'identifier'],
  ),
  SlashEntry(
    icon: 'edit',
    label: 'camelCase',
    hint: 'aBc',
    action: SlashAction.camelCaseLines,
    keywords: ['camel', 'case', 'lower', 'identifier'],
  ),
  SlashEntry(
    icon: 'edit',
    label: 'PascalCase',
    hint: 'ABc',
    action: SlashAction.pascalCaseLines,
    keywords: ['pascal', 'case', 'upper', 'identifier'],
  ),
  SlashEntry(
    icon: 'edit',
    label: 'CONSTANT_CASE',
    hint: 'A_B_C',
    action: SlashAction.constantCaseLines,
    keywords: ['constant', 'case', 'screaming', 'snake', 'env', 'macro'],
  ),
  SlashEntry(
    icon: 'bold',
    label: 'Wrap each line in bold',
    hint: '**…**',
    action: SlashAction.boldLines,
    keywords: ['bold', 'strong', 'wrap', 'stars'],
  ),
  SlashEntry(
    icon: 'italic',
    label: 'Wrap each line in italic',
    hint: '*…*',
    action: SlashAction.italicLines,
    keywords: ['italic', 'em', 'wrap', 'star'],
  ),
  SlashEntry(
    icon: 'code',
    label: 'Wrap each line in inline code',
    hint: '`…`',
    action: SlashAction.codeLines,
    keywords: ['code', 'mono', 'backtick', 'wrap', 'inline'],
  ),
  SlashEntry(
    icon: 'strikethrough',
    label: 'Wrap each line in strikethrough',
    hint: '~~…~~',
    action: SlashAction.strikethroughLines,
    keywords: ['strikethrough', 'strike', 'tilde', 'wrap', 'crossed'],
  ),
  SlashEntry(
    icon: 'edit',
    label: 'Wrap each line in highlight',
    hint: '==…==',
    action: SlashAction.highlightLines,
    keywords: ['highlight', 'mark', 'yellow', 'pandoc', 'wrap'],
  ),
  SlashEntry(
    icon: 'edit',
    label: 'Unwrap inline formatting',
    hint: '**a** → a',
    action: SlashAction.unwrapInlineFormatting,
    keywords: ['unwrap', 'strip', 'bold', 'italic', 'code', 'plain'],
  ),
  SlashEntry(
    icon: 'lock',
    label: 'Insert password',
    hint: '16 chars',
    action: SlashAction.insertPassword,
    keywords: ['password', 'secret', 'random', 'generate', 'pwd'],
  ),
  SlashEntry(
    icon: 'link',
    label: 'Insert UUID',
    hint: '8-4-4-4-12',
    action: SlashAction.insertUuid,
    keywords: ['uuid', 'guid', 'id', 'identifier', 'v4', 'random'],
  ),
  SlashEntry(
    icon: 'hash',
    label: 'Insert text statistics',
    hint: '(N w · N c · N l)',
    action: SlashAction.insertTextStats,
    keywords: ['stats', 'word', 'character', 'count', 'metrics', 'length'],
  ),
  SlashEntry(
    icon: 'sync',
    label: 'Sort lines by length',
    hint: 'shortest first',
    action: SlashAction.sortLinesByLength,
    keywords: ['sort', 'length', 'short', 'long', 'asc', 'size'],
  ),
  SlashEntry(
    icon: 'sync',
    label: 'Sort lines by length (descending)',
    hint: 'longest first',
    action: SlashAction.sortLinesByLengthDesc,
    keywords: ['sort', 'length', 'long', 'desc', 'descending', 'size'],
  ),
  SlashEntry(
    icon: 'edit',
    label: 'Uppercase selected lines',
    hint: 'AAA',
    action: SlashAction.uppercaseSelectedLines,
    keywords: ['upper', 'uppercase', 'case', 'capitalize', 'shout'],
  ),
  SlashEntry(
    icon: 'edit',
    label: 'Lowercase selected lines',
    hint: 'aaa',
    action: SlashAction.lowercaseSelectedLines,
    keywords: ['lower', 'lowercase', 'case'],
  ),
  SlashEntry(
    icon: 'edit',
    label: 'Title case selected lines',
    hint: 'Title Case',
    action: SlashAction.titleCaseSelectedLines,
    keywords: ['title', 'case', 'caps', 'capitalize', 'headline'],
  ),
  SlashEntry(
    icon: 'edit',
    label: 'Sentence case selected lines',
    hint: 'Aa…',
    action: SlashAction.sentenceCaseSelectedLines,
    keywords: ['sentence', 'case', 'lowercase', 'capitalize'],
  ),
  SlashEntry(
    icon: 'link',
    label: 'Insert ULID',
    hint: '26 chars',
    action: SlashAction.insertUlid,
    keywords: ['ulid', 'id', 'uuid', 'identifier', 'random'],
  ),
  SlashEntry(
    icon: 'edit',
    label: 'Keyboard chip',
    hint: '<kbd>⌘K</kbd>',
    snippet: '<kbd>⌘K</kbd>',
    // Caret right after `<kbd>` so the user can replace the placeholder.
    cursorOffset: 5,
    keywords: ['kbd', 'keyboard', 'key', 'shortcut', 'chip'],
  ),
  SlashEntry(
    icon: 'calendar',
    label: "Yesterday's date",
    hint: '@…-1d',
    action: SlashAction.insertYesterday,
    keywords: ['yesterday', 'date', 'day'],
  ),
  SlashEntry(
    icon: 'calendar',
    label: "Tomorrow's date",
    hint: '@…+1d',
    action: SlashAction.insertTomorrow,
    keywords: ['tomorrow', 'date', 'day'],
  ),
  SlashEntry(
    icon: 'tag',
    label: 'Emoji…',
    hint: '🙂',
    action: SlashAction.pickEmoji,
    keywords: ['emoji', 'icon', 'sticker', 'reaction', 'smiley', 'glyph'],
  ),
  SlashEntry(
    icon: 'edit',
    label: 'Highlight',
    hint: '==…==',
    snippet: '==highlight==',
    cursorOffset: 2, // start of inner text
    keywords: ['highlight', 'mark', 'yellow', 'emphasis'],
  ),
  SlashEntry(
    icon: 'note',
    label: 'Footnote ref',
    hint: '[^1]',
    snippet: '[^1]',
    cursorOffset: 2,
    keywords: ['footnote', 'ref', 'reference', 'citation', 'cite'],
  ),
  SlashEntry(
    icon: 'note',
    label: 'Footnote definition',
    hint: '[^1]: text',
    snippet: '[^1]: ',
    // Caret lands right after `[^` so the user can name the marker
    // before the colon-text.
    cursorOffset: 2,
    keywords: ['footnote', 'def', 'definition', 'citation', 'cite'],
  ),
  SlashEntry(
    icon: 'edit',
    label: 'Subscript',
    hint: '~x~',
    snippet: '~sub~',
    cursorOffset: 1,
    keywords: ['subscript', 'sub', 'chemistry', 'math'],
  ),
  SlashEntry(
    icon: 'edit',
    label: 'Superscript',
    hint: '^x^',
    snippet: '^sup^',
    cursorOffset: 1,
    keywords: ['superscript', 'sup', 'exponent', 'power', 'math'],
  ),
  SlashEntry(
    icon: 'sync',
    label: 'Random page link',
    hint: '[[?]]',
    action: SlashAction.insertRandomPageLink,
    keywords: ['random', 'wormhole', 'link', 'page', 'shuffle', 'serendipity'],
  ),
  SlashEntry(
    icon: 'note',
    label: 'Lorem ipsum',
    hint: '3 paras',
    snippet:
        'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do '
        'eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut '
        'enim ad minim veniam, quis nostrud exercitation ullamco laboris '
        'nisi ut aliquip ex ea commodo consequat.\n\n'
        'Duis aute irure dolor in reprehenderit in voluptate velit esse '
        'cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat '
        'cupidatat non proident, sunt in culpa qui officia deserunt '
        'mollit anim id est laborum.\n\n'
        'Sed ut perspiciatis unde omnis iste natus error sit voluptatem '
        'accusantium doloremque laudantium, totam rem aperiam, eaque ipsa '
        'quae ab illo inventore veritatis et quasi architecto beatae '
        'vitae dicta sunt explicabo.\n',
    keywords: ['lorem', 'ipsum', 'placeholder', 'dummy', 'fill', 'mock'],
  ),
];

/// Filter the catalog by [query] (case-insensitive). Empty query returns all.
/// Score an entry by how strongly it matches [q]. Higher = better.
/// Returns null when the entry doesn't match at all.
///   3 — label starts with q
///   2 — keyword equals q, OR keyword starts with q
///   1 — label or any keyword contains q
int? _scoreEntry(SlashEntry e, String q) {
  final lbl = e.label.toLowerCase();
  if (lbl.startsWith(q)) return 3;
  for (final k in e.keywords) {
    if (k == q || k.startsWith(q)) return 2;
  }
  if (lbl.contains(q)) return 1;
  for (final k in e.keywords) {
    if (k.contains(q)) return 1;
  }
  return null;
}

List<SlashEntry> filterSlashEntries(String query) {
  if (query.isEmpty) return kSlashEntries;
  final q = query.toLowerCase();
  // Score every entry then return the best matches first. Stable sort
  // preserves catalog order within a score bucket.
  final scored = <(int, int, SlashEntry)>[];
  for (var i = 0; i < kSlashEntries.length; i++) {
    final score = _scoreEntry(kSlashEntries[i], q);
    if (score != null) scored.add((score, i, kSlashEntries[i]));
  }
  scored.sort((a, b) {
    final c = b.$1.compareTo(a.$1);
    if (c != 0) return c;
    return a.$2.compareTo(b.$2);
  });
  return [for (final t in scored) t.$3];
}
