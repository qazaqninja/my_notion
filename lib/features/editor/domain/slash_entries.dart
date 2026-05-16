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
  /// Trim BOTH leading and trailing whitespace from every line in
  /// the selected block.
  trimWhitespaceLines,
  /// Uppercase the lines touched by the selection.
  uppercaseSelectedLines,
  /// Lowercase the lines touched by the selection.
  lowercaseSelectedLines,
  /// Title-case the lines touched by the selection.
  titleCaseSelectedLines,
  /// Toggle the case of every cased character on every selected line:
  /// uppercase becomes lowercase and vice versa.
  swapCaseSelectedLines,
  /// Capitalize just the first letter of each selected line,
  /// leaving the rest untouched.
  capitalizeFirstLetterPerLine,
  /// Strip every non-ASCII character from each selected line,
  /// keeping only codepoints `U+0000`–`U+007F`.
  asciiOnlyLines,
  /// Strip markdown emphasis / decoration markers (`**`, `*`, `_`,
  /// `~~`, `==`, backticks) from every selected line so the inner
  /// text remains as plain prose.
  stripMarkdownEmphasisLines,
  /// Strip markdown link / image syntax from every selected line:
  /// `[label](url)` → `label`, `![alt](src)` → `alt`. Wikilinks
  /// `[[ULID]]` are preserved (they're the canonical Quill relation).
  stripMarkdownLinksLines,
  /// Strip inline HTML tags from every selected line, leaving the
  /// text content between them.
  stripHtmlTagsLines,
  /// Prefix every selected line with its 1-based index, zero-padded
  /// to the width of the largest index.
  prefixLinesWithIndex,
  /// Strip a leading number-enumerator prefix (`1. ` / `1) ` /
  /// `1] ` / `1: ` / `1- `) from every selected line, preserving
  /// any leading indentation.
  stripLeadingNumberPrefix,
  /// Split each selected line on sentence boundaries, emitting one
  /// sentence per output line.
  splitLinesOnSentences,
  /// Split each selected line on sentence boundaries AND prefix
  /// every sentence with `- ` (bullet form).
  bulletizeSentences,
  /// Join every non-blank selected line into a single space-separated
  /// paragraph. Inverse of `splitLinesOnSentences`.
  joinLinesWithSpace,
  /// Strip emoji glyphs (Unicode pictograph + dingbat blocks plus
  /// joiner / variation selectors) from every selected line.
  stripEmojiLines,
  /// Fold accented Latin characters to their ASCII base letter on
  /// every selected line. `café` → `cafe`, `Œuvre` → `OEuvre`.
  removeAccentsLines,
  /// Insert a classic three-sentence lorem-ipsum paragraph at the
  /// caret. Useful for layout testing and template stubs.
  insertLoremIpsum,
  /// Insert a four-section meeting-notes scaffold at the caret
  /// (Attendees / Agenda / Decisions / Action items).
  insertMeetingNotesScaffold,
  /// Insert a three-section daily-standup scaffold at the caret
  /// (Yesterday / Today / Blockers).
  insertStandupScaffold,
  /// Insert a three-section retrospective scaffold at the caret
  /// (What went well / What didn't / Action items).
  insertRetroScaffold,
  /// Insert a three-section ADR (Architecture Decision Record)
  /// scaffold at the caret (Context / Decision / Consequences).
  insertAdrScaffold,
  /// Insert a four-section 1:1 meeting scaffold at the caret
  /// (Their topics / My topics / Career / Action items).
  insertOneOnOneScaffold,
  /// Insert a four-section incident post-mortem scaffold at the
  /// caret (Summary / Timeline / Root cause / Action items).
  insertPostMortemScaffold,
  /// Add a two-space indent to every selected line.
  indentLines,
  /// Wrap each selected line at an 80-character column boundary,
  /// breaking on the last whitespace at or before column 80.
  wrapLinesAt80,
  /// Escape markdown control characters on every selected line so
  /// the content renders verbatim instead of being parsed.
  escapeMarkdownLines,
  /// Prefix every selected line with its character count
  /// (`[12] hello world`), padded so columns align.
  prefixLinesWithCharCount,
  /// Strip a leading bracketed char-count prefix (the inverse of
  /// `prefixLinesWithCharCount`) from every selected line.
  stripLeadingCharCountPrefix,
  /// Strip bare http/https/ftp URLs from every selected line,
  /// leaving the surrounding prose intact.
  removeUrlsLines,
  /// Prefix every selected line with its word count
  /// (`[3] one two three`), padded so columns align.
  prefixLinesWithWordCount,
  /// Unconditionally strip a leading `> ` blockquote prefix from
  /// every selected line that has one (mixed selections welcome).
  stripBlockquotePrefix,
  /// Unconditionally ADD a `> ` blockquote prefix to every
  /// non-blank selected line (idempotent on already-quoted lines —
  /// they become nested quotes).
  addBlockquotePrefix,
  /// Strip blank lines from the edges of the selected block,
  /// preserving every line in the interior.
  trimBlankEdgeLines,
  /// Remove the common leading whitespace from every line in the
  /// selected block (standard "dedent" semantics).
  dedentLines,
  /// Strip a leading ATX heading marker (`# ` to `###### `) from
  /// every selected line that has one.
  stripHeadingMarker,
  /// Strip up to two leading spaces (one indent level) from every
  /// selected line.
  outdentLines,
  /// Insert the current calendar quarter tag (`YYYY-Qn`) at the caret.
  insertYearQuarter,
  /// Insert the current year-month tag (`YYYY-MM`) at the caret.
  insertYearMonth,
  /// Insert the current ISO year-week tag (`YYYY-Www`) at the caret.
  insertIsoYearWeek,
  /// Insert a session-checkpoint marker: a horizontal rule followed
  /// by a bolded ISO timestamp, with the caret on the line below.
  insertCheckpoint,
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
  /// Sort numeric lines by absolute value ascending; non-numeric
  /// lines drop to the bottom.
  sortLinesByAbsValue,
  /// Sort by the first signed number found anywhere in each line;
  /// lines with no number drop to the bottom.
  sortLinesByFirstNumber,
  /// Sort by the LAST signed number found anywhere in each line;
  /// lines with no number drop to the bottom.
  sortLinesByLastNumber,
  /// Sort by the SUM of every signed number found in each line,
  /// ascending. Lines with no number sum to 0 and sort with the
  /// other zero-sum lines.
  sortLinesBySumOfNumbers,
  /// Sort by the LARGEST signed number found anywhere in each
  /// line, ascending. Lines with no number drop to the bottom.
  sortLinesByMaxNumber,
  /// Sort by the SMALLEST signed number found anywhere in each
  /// line, ascending. Lines with no number drop to the bottom.
  sortLinesByMinNumber,
  /// Sort by the MEDIAN of all numbers in each line, ascending.
  /// Outlier-resistant per-row ranking.
  sortLinesByMedianNumber,
  /// Extract every signed-decimal number from each selected line
  /// and emit them one-per-line.
  extractNumbersFromLines,
  /// Extract every email-shaped substring from each selected line
  /// and emit them one-per-line.
  extractEmailsFromLines,
  /// Extract every http/https/ftp URL from each selected line and
  /// emit them one-per-line.
  extractUrlsFromLines,
  /// Extract every `#hashtag` from each selected line and emit them
  /// one-per-line, without the leading `#`.
  extractHashtagsFromLines,
  /// Extract every `@mention` from each selected line and emit them
  /// one-per-line, without the leading `@`.
  extractMentionsFromLines,
  /// Extract every Quill wikilink (ULID, optionally with anchor or
  /// alias) from each selected line, without the wrapping brackets.
  extractWikilinksFromLines,
  /// Collapse runs of identical consecutive lines down to a single
  /// occurrence (Unix `uniq` semantics). Non-consecutive duplicates
  /// are kept.
  collapseConsecutiveDuplicates,
  /// Collapse runs of identical consecutive lines, prefixing each
  /// kept line with its count (Unix `uniq -c` semantics).
  countConsecutiveDuplicates,
  /// Split each selected line on whitespace runs, emitting one
  /// word per output line.
  splitOnSpaces,
  /// Extract the body of every GFM unchecked-todo line in the
  /// selection, emitting each body without its `- [ ] ` marker.
  extractOpenTodoBodies,
  /// Extract the body of every GFM CHECKED-todo line in the
  /// selection, emitting each body without its `- [x] ` marker.
  extractDoneTodoBodies,
  /// Extract every ISO-shaped date (`YYYY-MM-DD`) from each
  /// selected line and emit them one-per-line.
  extractIsoDatesFromLines,
  /// Extract every bare ULID (`[0-9A-Z]{26}`) from each selected
  /// line, including ULIDs outside `[[wikilinks]]`.
  extractUlidsFromLines,
  /// Extract every CSS hex color code (`#RGB` / `#RRGGBB` / `#RGBA`
  /// / `#RRGGBBAA`) from each selected line.
  extractHexColorsFromLines,
  /// Extract every IPv4 dotted-quad (`a.b.c.d`, each octet 0..255)
  /// from each selected line.
  extractIpv4FromLines,
  /// Extract every UUID-shaped substring (`8-4-4-4-12` hex form)
  /// from each selected line.
  extractUuidsFromLines,
  /// Extract every semver-shaped version string (`MAJOR.MINOR.PATCH`
  /// with optional `-PRERELEASE` and `+BUILD`) from each selected
  /// line.
  extractSemverFromLines,
  /// Extract every MAC-address-shaped substring (`XX:XX:XX:XX:XX:XX`
  /// or `XX-XX-XX-XX-XX-XX`) from each selected line.
  extractMacAddressesFromLines,
  /// Extract every backtick-delimited inline code span
  /// (`` `foo` `` → `foo`) from each selected line.
  extractMarkdownCodeSpansFromLines,
  /// Extract the title text from every ATX-style markdown heading
  /// (`# H1`, `## H2`, … `###### H6`) on each selected line.
  extractMarkdownHeadingsFromLines,
  /// Extract the quoted content from every markdown blockquote
  /// line (`> quoted text` → `quoted text`).
  extractMarkdownBlockquoteContentFromLines,
  /// Extract the item content from every markdown list line
  /// (`- foo` / `* foo` / `+ foo` / `1. foo` → `foo`).
  extractMarkdownListContentFromLines,
  /// Extract the content of every GFM strikethrough span
  /// (`~~struck~~` → `struck`) from each selected line.
  extractMarkdownStrikethroughFromLines,
  /// Extract the language hint from every markdown fenced-code
  /// opener (`` ```dart `` → `dart`) on each selected line.
  extractMarkdownCodeFenceLangsFromLines,
  /// Extract the content of every markdown bold span
  /// (`**foo**` or `__foo__` → `foo`) from each selected line.
  extractMarkdownBoldFromLines,
  /// Extract the content of every markdown single-delimiter
  /// italic span (`*foo*` or `_foo_` → `foo`) from each selected
  /// line.
  extractMarkdownItalicFromLines,
  /// Extract every markdown footnote ID (`[^id]` → `id`) from
  /// each selected line.
  extractMarkdownFootnoteIdsFromLines,
  /// Extract the body text from every markdown footnote
  /// definition line (`[^id]: text` → `text`).
  extractMarkdownFootnoteBodiesFromLines,
  /// Extract every bare-domain URL (no protocol prefix) from each
  /// selected line.
  extractBareUrlsFromLines,
  /// Extract every 4-digit year substring (1800-2099 range) from
  /// each selected line.
  extractYearsFromLines,
  /// Extract every markdown autolink URL (`<https://x.test>` →
  /// `https://x.test`) from each selected line.
  extractMarkdownAutolinksFromLines,
  /// Extract every HTML tag name (`<div>`, `</body>`, `<br/>`)
  /// from each selected line.
  extractHtmlTagsFromLines,
  /// Extract every HTML attribute name (the part before `=`)
  /// from each selected line.
  extractHtmlAttributeNamesFromLines,
  /// Extract every HTML attribute value (the part inside the
  /// quotes) from each selected line.
  extractHtmlAttributeValuesFromLines,
  /// Extract the label from every CommonMark inline reference-link
  /// usage site (`[text][label]` → `label`) on each selected line.
  extractMarkdownReferenceLinkUsageLabelsFromLines,
  /// Extract every American-style calendar date (`January 1, 2024`,
  /// `Jan 1, 2024`, `Apr 1st, 2024`) from each selected line.
  extractCalendarDatesFromLines,
  /// Extract every ISO 8601 week-number substring (`YYYY-Www`,
  /// e.g. `2024-W12`) from each selected line.
  extractIsoWeeksFromLines,
  /// Extract the label from every CommonMark inline image-reference
  /// usage site (`![alt][label]` → `label`) on each selected line.
  extractMarkdownImageReferenceUsageLabelsFromLines,
  /// Extract every CIDR-notation IPv4 substring (`a.b.c.d/N`) from
  /// each selected line.
  extractCidrFromLines,
  /// Extract the content of every HTML comment (`<!-- text -->` →
  /// `text`) on each selected line.
  extractHtmlCommentsFromLines,
  /// Extract the domain portion from every email address on each
  /// selected line (`user@example.com` → `example.com`).
  extractEmailDomainsFromLines,
  /// Extract the local-part portion from every email address on
  /// each selected line (`user@example.com` → `user`).
  extractEmailLocalPartsFromLines,
  /// Extract the alias portion from every wikilink with a custom
  /// display name (`[[ULID|alias]]` → `alias`) on each selected
  /// line.
  extractWikilinkAliasesFromLines,
  /// Extract the anchor slug from every wikilink that has one
  /// (`[[ULID#anchor]]` → `anchor`) on each selected line.
  extractWikilinkAnchorsFromLines,
  /// Extract every YouTube video ID (from any of `youtu.be/`,
  /// `youtube.com/watch?v=`, `youtube.com/embed/` URL surfaces)
  /// on each selected line.
  extractYoutubeIdsFromLines,
  /// Extract every `owner/repo` path from GitHub URLs on each
  /// selected line.
  extractGithubRepoPathsFromLines,
  /// Extract every compound year-range substring (`YYYY-YYYY` or
  /// `YYYY–YYYY` with em-dash) from each selected line.
  extractYearRangesFromLines,
  /// Extract every DOI (Digital Object Identifier) substring
  /// (`10.NNNN/suffix`) from each selected line.
  extractDoiFromLines,
  /// Extract every file extension substring (`pic.png` → `png`)
  /// from each selected line.
  extractFileExtensionsFromLines,
  /// Extract every ISBN-13 substring (`978`/`979` prefix) from
  /// each selected line.
  extractIsbn13FromLines,
  /// Extract every JIRA-style ticket reference (`PROJ-1234`)
  /// from each selected line.
  extractJiraTicketsFromLines,
  /// Extract every GitHub-style PR/issue reference (`#1234`)
  /// from each selected line.
  extractPrIssueRefsFromLines,
  /// Extract every Roman numeral substring (strict 1-3999 form,
  /// uppercase only) from each selected line.
  extractRomanNumeralsFromLines,
  /// Extract every latitude/longitude coordinate pair from each
  /// selected line.
  extractLatLngFromLines,
  /// Extract every Ethereum-style hex address substring
  /// (`0x` + 40 hex chars) from each selected line.
  extractEthAddressesFromLines,
  /// Extract every MongoDB ObjectId substring (24 hex chars,
  /// with at least one letter) from each selected line.
  extractMongoObjectIdsFromLines,
  /// Extract every AWS ARN substring
  /// (`arn:PARTITION:SERVICE:REGION:ACCOUNT:RESOURCE`) from
  /// each selected line.
  extractAwsArnsFromLines,
  /// Extract the OUI (first 3 octets, vendor/manufacturer prefix)
  /// from every MAC address on each selected line.
  extractMacOuisFromLines,
  /// Extract every Twitter/X status ID from each selected line.
  extractTwitterStatusIdsFromLines,
  /// Extract every GitHub issue/PR number (from full-URL
  /// references) on each selected line.
  extractGithubIssuePrNumbersFromLines,
  /// Extract every NPM scoped package name (`@scope/name`)
  /// from each selected line.
  extractNpmScopedPackagesFromLines,
  /// Extract every HTTP status code substring (1XX-5XX range)
  /// from each selected line.
  extractHttpStatusCodesFromLines,
  /// Extract every Stack Overflow question ID from a Stack
  /// Overflow URL on each selected line.
  extractStackOverflowQuestionIdsFromLines,
  /// Extract every time-of-day substring (`HH:MM[:SS][ AM/PM]`)
  /// from each selected line.
  extractTimeOfDayFromLines,
  /// Extract every percentage substring (`42%`, `99.9%`) from each
  /// selected line.
  extractPercentagesFromLines,
  /// Extract every currency-amount substring (`$10`, `€5.99`,
  /// `£100`, `¥500`) from each selected line.
  extractCurrencyFromLines,
  /// Extract every file-size substring (`1.5 MB`, `42KB`, `512 B`)
  /// from each selected line.
  extractFileSizesFromLines,
  /// Extract every git-short-SHA substring (7–40 lowercase hex
  /// chars with at least one letter) from each selected line.
  extractGitShasFromLines,
  /// Extract every E.164-ish international phone number from each
  /// selected line.
  extractPhoneNumbersFromLines,
  /// Canonicalize every markdown horizontal-rule line in the
  /// selected text to `---`.
  canonicalizeHorizontalRules,
  /// Extract the URL from every markdown reference-link
  /// definition line (`[label]: url`).
  extractMarkdownReferenceLinkUrlsFromLines,
  /// Extract the label from every markdown reference-link
  /// definition line (`[label]: url` → `label`).
  extractMarkdownReferenceLinkLabelsFromLines,
  /// Extract every cell from every markdown-table row line
  /// (`| a | b | c |` → `a`, `b`, `c`) on each selected line.
  extractMarkdownTableCellsFromLines,
  /// JSON-encode each selected line as a string literal (`hello` →
  /// `"hello"`, with proper escape of `"`, `\`, and control chars).
  jsonStringEncodeLines,
  /// Extract every markdown-link label (`[label](url)` → `label`)
  /// from each selected line.
  extractMarkdownLinkLabelsFromLines,
  /// Extract every markdown-link URL (`[label](url)` → `url`) from
  /// each selected line.
  extractMarkdownLinkUrlsFromLines,
  /// Extract every markdown-image URL (`![alt](url)` → `url`)
  /// from each selected line.
  extractMarkdownImageUrlsFromLines,
  /// Extract every markdown-image alt text (`![alt](url)` → `alt`)
  /// from each selected line.
  extractMarkdownImageAltsFromLines,
  /// Sort the lines touched by the selection by their word count,
  /// fewest words first.
  sortLinesByWordCount,
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
  /// Convert every selected line to `kebab-case`.
  kebabCaseLines,
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
  /// Wrap each line that looks like a URL in `[url](url)`.
  urlsToMarkdownLinks,
  /// Insert a random `#RRGGBB` colour at the caret.
  insertHexColor,
  /// Insert the current local datetime in ISO 8601 form
  /// (`YYYY-MM-DDTHH:MM:SS`).
  insertIsoDateTime,
  /// Insert the current Unix-epoch timestamp in seconds.
  insertEpochTimestamp,
  /// Convert a block of CSV-shaped lines into a GFM markdown
  /// pipe table.
  csvLinesToMarkdownTable,
  /// Inverse: convert a GFM pipe-table block back into CSV rows.
  markdownTableToCsv,
  /// Demote every selected `# ` heading by one level.
  demoteHeadings,
  /// Promote every selected heading by one level (up to `# `).
  promoteHeadings,
  /// Collapse runs of internal spaces/tabs to a single space on
  /// every selected line.
  collapseSpaces,
  /// Collapse 2+ consecutive blank lines to a single blank line.
  collapseBlankLines,
  /// Drop every blank line in the selection (stronger compaction).
  dropBlankLines,
  /// Prefix every non-blank selected line with `// `.
  commentLines,
  /// Strip a leading `// ` from every selected line that has one.
  uncommentLines,
  /// Wrap every non-blank selected line in `<!-- … -->`.
  htmlCommentLines,
  /// Strip a `<!-- … -->` wrapper from every selected line.
  htmlUncommentLines,
  /// Re-number every selected `N. ` line sequentially from 1.
  renumberListLines,
  /// Wrap every non-blank selected line in straight double quotes.
  quoteLines,
  /// Strip surrounding straight double quotes from every selected
  /// line that has them on both ends.
  unquoteLines,
  /// Collapse selected lines into a single JSON-style array.
  linesToJsonArray,
  /// Parse a JSON array of strings into one element per line.
  jsonArrayToLines,
  /// Sum every numeric line in the selection into a single total.
  sumNumericLines,
  /// Compute the arithmetic mean of every numeric line.
  averageNumericLines,
  /// Find the maximum numeric value in the selection.
  maxNumericLines,
  /// Find the minimum numeric value in the selection.
  minNumericLines,
  /// Compute the median of every numeric line.
  medianNumericLines,
  /// Replace the selection with the count of its non-blank lines.
  countLines,
  /// Multiply every numeric line into a single product.
  productNumericLines,
  /// Tally distinct non-blank lines and emit `count× line` rows.
  frequencyLines,
  /// Compute the range (max − min) of every numeric line.
  rangeNumericLines,
  /// Replace each numeric line with the running total of all
  /// preceding numeric lines plus itself.
  cumulativeSumLines,
  /// Emit consecutive deltas for every adjacent numeric pair.
  deltaNumericLines,
  /// Replace each numeric line with the running product of all
  /// preceding numeric lines times itself.
  cumulativeProductLines,
  /// Replace each numeric line with its percentage of the column
  /// total (`xx.x%`).
  percentageOfTotalLines,
  /// Compute the population standard deviation of every numeric
  /// line.
  stdDevNumericLines,
  /// Compute the population variance of every numeric line.
  varianceNumericLines,
  /// Replace every numeric line with its z-score
  /// `(x - mean) / stddev`, using the population stddev.
  zScoreNumericLines,
  /// Min-max normalise every numeric line into the [0, 1] range
  /// using `(x - min) / (max - min)`.
  normalizeNumericLines,
  /// Replace every numeric line with its 1-based rank (ascending,
  /// competition ranking: ties share, next rank skips).
  rankNumericLines,
  /// Round every numeric line to 2 decimal places.
  roundNumericLines,
  /// Replace every numeric line with its absolute value.
  absNumericLines,
  /// Replace every numeric line with its negation.
  negateNumericLines,
  /// Floor every numeric line (round toward −∞).
  floorNumericLines,
  /// Ceil every numeric line (round toward +∞).
  ceilNumericLines,
  /// Truncate every numeric line (round toward zero).
  truncateNumericLines,
  /// Replace every numeric line with its sign (`+`, `-`, or `0`).
  signNumericLines,
  /// Format every numeric line with `,`-grouped thousands separators.
  withThousandSeparatorsLines,
  /// Format every numeric line in scientific notation.
  scientificNotationLines,
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
    icon: 'calendar',
    label: 'Current quarter',
    hint: '2026-Q2',
    action: SlashAction.insertYearQuarter,
    keywords: ['quarter', 'qbr', 'q1', 'q2', 'q3', 'q4', 'fiscal'],
  ),
  SlashEntry(
    icon: 'calendar',
    label: 'Current month',
    hint: '2026-05',
    action: SlashAction.insertYearMonth,
    keywords: ['month', 'monthly', 'review', 'period'],
  ),
  SlashEntry(
    icon: 'calendar',
    label: 'Current ISO week',
    hint: '2026-W20',
    action: SlashAction.insertIsoYearWeek,
    keywords: ['week', 'iso', 'weekly', 'review', 'w20'],
  ),
  SlashEntry(
    icon: 'calendar',
    label: 'Session checkpoint',
    hint: '--- + **timestamp**',
    action: SlashAction.insertCheckpoint,
    keywords: ['checkpoint', 'session', 'mark', 'divider', 'timestamp'],
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
    label: 'Trim leading + trailing whitespace',
    hint: 'both sides at once',
    action: SlashAction.trimWhitespaceLines,
    keywords: ['trim', 'whitespace', 'both', 'cleanup', 'strip'],
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
    icon: 'edit',
    label: 'kebab-case',
    hint: 'a-b-c',
    action: SlashAction.kebabCaseLines,
    keywords: ['kebab', 'case', 'dash', 'hyphen', 'slug', 'url',
        'css', 'flag'],
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
    icon: 'link',
    label: 'URLs → markdown links',
    hint: 'http://… → [..](..)',
    action: SlashAction.urlsToMarkdownLinks,
    keywords: ['url', 'link', 'markdown', 'wrap', 'autolink'],
  ),
  SlashEntry(
    icon: 'tag',
    label: 'Insert hex colour',
    hint: '#RRGGBB',
    action: SlashAction.insertHexColor,
    keywords: ['hex', 'color', 'colour', 'random', 'css', 'design'],
  ),
  SlashEntry(
    icon: 'calendar',
    label: 'Insert ISO datetime',
    hint: 'YYYY-MM-DDTHH:MM:SS',
    action: SlashAction.insertIsoDateTime,
    keywords: ['iso', 'datetime', '8601', 'timestamp', 'sortable'],
  ),
  SlashEntry(
    icon: 'calendar',
    label: 'Insert epoch timestamp',
    hint: '1747345200',
    action: SlashAction.insertEpochTimestamp,
    keywords: ['epoch', 'unix', 'timestamp', 'seconds', 'integer'],
  ),
  SlashEntry(
    icon: 'table',
    label: 'CSV → markdown table',
    hint: 'a,b → | a | b |',
    action: SlashAction.csvLinesToMarkdownTable,
    keywords: ['csv', 'table', 'pipe', 'convert', 'markdown'],
  ),
  SlashEntry(
    icon: 'table',
    label: 'Markdown table → CSV',
    hint: '| a | b | → a,b',
    action: SlashAction.markdownTableToCsv,
    keywords: ['csv', 'table', 'pipe', 'extract', 'unmark'],
  ),
  SlashEntry(
    icon: 'edit',
    label: 'Demote headings (#→##)',
    hint: '## → ###',
    action: SlashAction.demoteHeadings,
    keywords: ['demote', 'heading', 'h1', 'h2', 'deeper', 'nest'],
  ),
  SlashEntry(
    icon: 'edit',
    label: 'Promote headings (##→#)',
    hint: '### → ##',
    action: SlashAction.promoteHeadings,
    keywords: ['promote', 'heading', 'h2', 'h1', 'shallower', 'flatten'],
  ),
  SlashEntry(
    icon: 'edit',
    label: 'Collapse runs of spaces',
    hint: 'a   b → a b',
    action: SlashAction.collapseSpaces,
    keywords: ['collapse', 'spaces', 'whitespace', 'normalize', 'tabs'],
  ),
  SlashEntry(
    icon: 'edit',
    label: 'Collapse blank lines',
    hint: '⊞⊞⊞ → ⊞',
    action: SlashAction.collapseBlankLines,
    keywords: ['collapse', 'blank', 'empty', 'paragraph', 'compact'],
  ),
  SlashEntry(
    icon: 'edit',
    label: 'Drop all blank lines',
    hint: 'compact',
    action: SlashAction.dropBlankLines,
    keywords: ['drop', 'blank', 'empty', 'remove', 'compact', 'strip'],
  ),
  SlashEntry(
    icon: 'code',
    label: 'Comment lines (//)',
    hint: 'a → // a',
    action: SlashAction.commentLines,
    keywords: ['comment', 'slash', 'prefix', 'code', 'mark'],
  ),
  SlashEntry(
    icon: 'code',
    label: 'Uncomment lines',
    hint: '// a → a',
    action: SlashAction.uncommentLines,
    keywords: ['uncomment', 'strip', 'slash', 'prefix', 'code', 'unmark'],
  ),
  SlashEntry(
    icon: 'code',
    label: 'HTML-comment lines (<!-- -->)',
    hint: 'a → <!-- a -->',
    action: SlashAction.htmlCommentLines,
    keywords: ['html', 'comment', 'wrap', 'hide', 'markdown'],
  ),
  SlashEntry(
    icon: 'code',
    label: 'HTML-uncomment lines',
    hint: '<!-- a --> → a',
    action: SlashAction.htmlUncommentLines,
    keywords: ['html', 'uncomment', 'unwrap', 'show'],
  ),
  SlashEntry(
    icon: 'list',
    label: 'Renumber list',
    hint: '7, 3, 9 → 1, 2, 3',
    action: SlashAction.renumberListLines,
    keywords: ['renumber', 'list', 'ordered', 'fix', 'sequence'],
  ),
  SlashEntry(
    icon: 'quote',
    label: 'Quote each line',
    hint: 'a → "a"',
    action: SlashAction.quoteLines,
    keywords: ['quote', 'string', 'csv', 'wrap', 'json'],
  ),
  SlashEntry(
    icon: 'code',
    label: 'JSON-encode each line',
    hint: 'a"b → "a\\"b"',
    action: SlashAction.jsonStringEncodeLines,
    keywords: ['json', 'encode', 'string', 'escape', 'quote',
        'literal', 'serialize'],
  ),
  SlashEntry(
    icon: 'quote',
    label: 'Unquote each line',
    hint: '"a" → a',
    action: SlashAction.unquoteLines,
    keywords: ['unquote', 'strip', 'string', 'csv', 'unwrap'],
  ),
  SlashEntry(
    icon: 'code',
    label: 'Lines → JSON array',
    hint: 'a / b → ["a","b"]',
    action: SlashAction.linesToJsonArray,
    keywords: ['json', 'array', 'collapse', 'list', 'serialize'],
  ),
  SlashEntry(
    icon: 'code',
    label: 'JSON array → lines',
    hint: '["a","b"] → a / b',
    action: SlashAction.jsonArrayToLines,
    keywords: ['json', 'array', 'explode', 'deserialize'],
  ),
  SlashEntry(
    icon: 'hash',
    label: 'Sum numeric lines',
    hint: '1 / 2 / 3 → 6',
    action: SlashAction.sumNumericLines,
    keywords: ['sum', 'total', 'add', 'math', 'numeric'],
  ),
  SlashEntry(
    icon: 'hash',
    label: 'Average numeric lines',
    hint: '1 / 2 / 3 → 2.0',
    action: SlashAction.averageNumericLines,
    keywords: ['average', 'mean', 'math', 'numeric'],
  ),
  SlashEntry(
    icon: 'hash',
    label: 'Max of numeric lines',
    hint: '1 / 5 / 3 → 5',
    action: SlashAction.maxNumericLines,
    keywords: ['max', 'maximum', 'largest', 'math', 'numeric'],
  ),
  SlashEntry(
    icon: 'hash',
    label: 'Min of numeric lines',
    hint: '1 / 5 / 3 → 1',
    action: SlashAction.minNumericLines,
    keywords: ['min', 'minimum', 'smallest', 'math', 'numeric'],
  ),
  SlashEntry(
    icon: 'hash',
    label: 'Median of numeric lines',
    hint: '1 / 5 / 3 → 3',
    action: SlashAction.medianNumericLines,
    keywords: ['median', 'middle', 'math', 'numeric', 'stats'],
  ),
  SlashEntry(
    icon: 'hash',
    label: 'Count non-blank lines',
    hint: 'tally',
    action: SlashAction.countLines,
    keywords: ['count', 'tally', 'how many', 'cardinality'],
  ),
  SlashEntry(
    icon: 'hash',
    label: 'Product of numeric lines',
    hint: '2 / 3 / 4 → 24',
    action: SlashAction.productNumericLines,
    keywords: ['product', 'multiply', 'math', 'numeric'],
  ),
  SlashEntry(
    icon: 'list',
    label: 'Frequency tally',
    hint: 'a/a/b → 2× a / 1× b',
    action: SlashAction.frequencyLines,
    keywords: ['frequency', 'tally', 'count', 'histogram', 'occurrence'],
  ),
  SlashEntry(
    icon: 'hash',
    label: 'Range of numeric lines',
    hint: 'max − min',
    action: SlashAction.rangeNumericLines,
    keywords: ['range', 'max', 'min', 'span', 'spread', 'math'],
  ),
  SlashEntry(
    icon: 'hash',
    label: 'Cumulative sum',
    hint: '1 / 2 / 3 → 1 / 3 / 6',
    action: SlashAction.cumulativeSumLines,
    keywords: ['cumulative', 'sum', 'running', 'total', 'cumsum'],
  ),
  SlashEntry(
    icon: 'hash',
    label: 'Consecutive deltas',
    hint: '1 / 5 / 10 → +4 / +5',
    action: SlashAction.deltaNumericLines,
    keywords: ['delta', 'difference', 'diff', 'gap', 'change'],
  ),
  SlashEntry(
    icon: 'hash',
    label: 'Cumulative product',
    hint: '2 / 3 / 4 → 2 / 6 / 24',
    action: SlashAction.cumulativeProductLines,
    keywords: ['cumulative', 'product', 'running', 'multiply'],
  ),
  SlashEntry(
    icon: 'hash',
    label: 'Percentage of total',
    hint: '10 / 30 → 25% / 75%',
    action: SlashAction.percentageOfTotalLines,
    keywords: ['percent', 'percentage', 'share', 'normalize'],
  ),
  SlashEntry(
    icon: 'hash',
    label: 'Standard deviation',
    hint: 'σ (population)',
    action: SlashAction.stdDevNumericLines,
    keywords: ['std', 'standard', 'deviation', 'sigma', 'stats'],
  ),
  SlashEntry(
    icon: 'hash',
    label: 'Variance',
    hint: 'σ² (population)',
    action: SlashAction.varianceNumericLines,
    keywords: ['variance', 'sigma', 'squared', 'stats'],
  ),
  SlashEntry(
    icon: 'hash',
    label: 'Z-score per line',
    hint: '(x - μ) / σ',
    action: SlashAction.zScoreNumericLines,
    keywords: ['zscore', 'standard', 'score', 'normalize', 'stats'],
  ),
  SlashEntry(
    icon: 'hash',
    label: 'Normalise to [0, 1]',
    hint: '(x - min) / (max - min)',
    action: SlashAction.normalizeNumericLines,
    keywords: ['normalize', 'normalise', 'minmax', 'scale', 'range', 'rescale'],
  ),
  SlashEntry(
    icon: 'hash',
    label: 'Rank per line',
    hint: 'leaderboard order, ties share',
    action: SlashAction.rankNumericLines,
    keywords: ['rank', 'leaderboard', 'position', 'order', 'ordinal'],
  ),
  SlashEntry(
    icon: 'hash',
    label: 'Round to 2 decimals',
    hint: '3.14159 → 3.14',
    action: SlashAction.roundNumericLines,
    keywords: ['round', 'decimal', 'precision', 'truncate'],
  ),
  SlashEntry(
    icon: 'hash',
    label: 'Absolute value',
    hint: '-5 → 5',
    action: SlashAction.absNumericLines,
    keywords: ['abs', 'absolute', 'value', 'positive', 'magnitude'],
  ),
  SlashEntry(
    icon: 'hash',
    label: 'Negate numeric lines',
    hint: '5 → -5',
    action: SlashAction.negateNumericLines,
    keywords: ['negate', 'flip', 'sign', 'invert', 'minus'],
  ),
  SlashEntry(
    icon: 'hash',
    label: 'Floor (round to −∞)',
    hint: '3.7 → 3',
    action: SlashAction.floorNumericLines,
    keywords: ['floor', 'round', 'down', 'negative'],
  ),
  SlashEntry(
    icon: 'hash',
    label: 'Ceil (round to +∞)',
    hint: '3.2 → 4',
    action: SlashAction.ceilNumericLines,
    keywords: ['ceil', 'ceiling', 'round', 'up', 'positive'],
  ),
  SlashEntry(
    icon: 'hash',
    label: 'Truncate (toward zero)',
    hint: '3.7 → 3 / -3.7 → -3',
    action: SlashAction.truncateNumericLines,
    keywords: ['truncate', 'integer', 'drop', 'fraction'],
  ),
  SlashEntry(
    icon: 'hash',
    label: 'Sign of numeric lines',
    hint: '5 / -3 / 0 → + / - / 0',
    action: SlashAction.signNumericLines,
    keywords: ['sign', 'signum', 'positive', 'negative', 'trend'],
  ),
  SlashEntry(
    icon: 'hash',
    label: 'Thousands separators',
    hint: '1234567 → 1,234,567',
    action: SlashAction.withThousandSeparatorsLines,
    keywords: ['thousands', 'separator', 'comma', 'format', 'readable'],
  ),
  SlashEntry(
    icon: 'hash',
    label: 'Scientific notation',
    hint: '1234 → 1.234e+3',
    action: SlashAction.scientificNotationLines,
    keywords: ['scientific', 'notation', 'exponent', 'mantissa', 'format'],
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
    icon: 'sync',
    label: 'Sort by absolute value',
    hint: '|x| ascending',
    action: SlashAction.sortLinesByAbsValue,
    keywords: ['sort', 'absolute', 'magnitude', 'ascending'],
  ),
  SlashEntry(
    icon: 'sync',
    label: 'Sort by first number in line',
    hint: 'log lines by leading score',
    action: SlashAction.sortLinesByFirstNumber,
    keywords: ['sort', 'first', 'number', 'leading', 'score', 'log'],
  ),
  SlashEntry(
    icon: 'sync',
    label: 'Sort by last number in line',
    hint: 'value-then-label rows',
    action: SlashAction.sortLinesByLastNumber,
    keywords: ['sort', 'last', 'number', 'trailing', 'score', 'log'],
  ),
  SlashEntry(
    icon: 'sync',
    label: 'Sort by sum of numbers in line',
    hint: 'per-row total ascending',
    action: SlashAction.sortLinesBySumOfNumbers,
    keywords: ['sort', 'sum', 'total', 'numbers', 'row', 'tabular'],
  ),
  SlashEntry(
    icon: 'sync',
    label: 'Sort by max number in line',
    hint: 'per-row peak ascending',
    action: SlashAction.sortLinesByMaxNumber,
    keywords: ['sort', 'max', 'maximum', 'peak', 'highest', 'numbers'],
  ),
  SlashEntry(
    icon: 'sync',
    label: 'Sort by min number in line',
    hint: 'per-row trough ascending',
    action: SlashAction.sortLinesByMinNumber,
    keywords: ['sort', 'min', 'minimum', 'trough', 'lowest', 'numbers'],
  ),
  SlashEntry(
    icon: 'sync',
    label: 'Sort by median number in line',
    hint: 'outlier-resistant ranking',
    action: SlashAction.sortLinesByMedianNumber,
    keywords: ['sort', 'median', 'middle', 'outlier', 'robust', 'numbers'],
  ),
  SlashEntry(
    icon: 'hash',
    label: 'Extract numbers from lines',
    hint: 'one number per output line',
    action: SlashAction.extractNumbersFromLines,
    keywords: ['extract', 'pull', 'numbers', 'numeric', 'column'],
  ),
  SlashEntry(
    icon: 'edit',
    label: 'Extract email addresses',
    hint: 'one address per line',
    action: SlashAction.extractEmailsFromLines,
    keywords: ['extract', 'pull', 'email', 'address', 'contact'],
  ),
  SlashEntry(
    icon: 'link',
    label: 'Extract URLs',
    hint: 'one link per line',
    action: SlashAction.extractUrlsFromLines,
    keywords: ['extract', 'pull', 'url', 'link', 'http', 'https'],
  ),
  SlashEntry(
    icon: 'tag',
    label: 'Extract hashtags',
    hint: '#tag → tag (one per line)',
    action: SlashAction.extractHashtagsFromLines,
    keywords: ['extract', 'pull', 'hashtag', 'tag', 'tags'],
  ),
  SlashEntry(
    icon: 'users',
    label: 'Extract mentions',
    hint: '@user → user (one per line)',
    action: SlashAction.extractMentionsFromLines,
    keywords: ['extract', 'pull', 'mention', 'mentions', 'user', 'at'],
  ),
  SlashEntry(
    icon: 'link',
    label: 'Extract wikilinks',
    hint: '[[ULID]] → ULID',
    action: SlashAction.extractWikilinksFromLines,
    keywords: ['extract', 'pull', 'wikilink', 'ulid', 'reference', 'relation'],
  ),
  SlashEntry(
    icon: 'sync',
    label: 'Collapse consecutive duplicates',
    hint: 'Unix uniq semantics',
    action: SlashAction.collapseConsecutiveDuplicates,
    keywords: ['uniq', 'collapse', 'consecutive', 'duplicate', 'dedup'],
  ),
  SlashEntry(
    icon: 'hash',
    label: 'Count consecutive duplicates',
    hint: 'Unix uniq -c semantics',
    action: SlashAction.countConsecutiveDuplicates,
    keywords: ['uniq', 'count', 'consecutive', 'duplicate', 'run'],
  ),
  SlashEntry(
    icon: 'edit',
    label: 'Split on whitespace',
    hint: 'one word per line',
    action: SlashAction.splitOnSpaces,
    keywords: ['split', 'whitespace', 'words', 'tokens', 'break'],
  ),
  SlashEntry(
    icon: 'check',
    label: 'Extract open-todo bodies',
    hint: '- [ ] foo → foo',
    action: SlashAction.extractOpenTodoBodies,
    keywords: ['extract', 'todo', 'todos', 'action', 'item', 'open', 'gfm'],
  ),
  SlashEntry(
    icon: 'check',
    label: 'Extract done-todo bodies',
    hint: '- [x] foo → foo',
    action: SlashAction.extractDoneTodoBodies,
    keywords: ['extract', 'todo', 'todos', 'done', 'completed', 'gfm'],
  ),
  SlashEntry(
    icon: 'calendar',
    label: 'Extract ISO dates',
    hint: 'YYYY-MM-DD per line',
    action: SlashAction.extractIsoDatesFromLines,
    keywords: ['extract', 'date', 'dates', 'iso', 'timestamp'],
  ),
  SlashEntry(
    icon: 'link',
    label: 'Extract bare ULIDs',
    hint: '26-char IDs (incl. unbracketed)',
    action: SlashAction.extractUlidsFromLines,
    keywords: ['extract', 'ulid', 'id', 'identifier', 'page'],
  ),
  SlashEntry(
    icon: 'hash',
    label: 'Extract hex colors',
    hint: '#RGB / #RRGGBB / etc.',
    action: SlashAction.extractHexColorsFromLines,
    keywords: ['extract', 'color', 'hex', 'palette', 'rgb', 'css'],
  ),
  SlashEntry(
    icon: 'link',
    label: 'Extract IPv4 addresses',
    hint: 'a.b.c.d per line',
    action: SlashAction.extractIpv4FromLines,
    keywords: ['extract', 'ip', 'ipv4', 'address', 'host', 'network'],
  ),
  SlashEntry(
    icon: 'link',
    label: 'Extract UUIDs',
    hint: '8-4-4-4-12 hex per line',
    action: SlashAction.extractUuidsFromLines,
    keywords: ['extract', 'uuid', 'guid', 'id', 'identifier'],
  ),
  SlashEntry(
    icon: 'hash',
    label: 'Extract semver versions',
    hint: '1.2.3 / 1.2.3-rc.1+build.42',
    action: SlashAction.extractSemverFromLines,
    keywords: ['extract', 'semver', 'version', 'release', 'tag',
        'major', 'minor', 'patch'],
  ),
  SlashEntry(
    icon: 'hash',
    label: 'Extract MAC addresses',
    hint: 'XX:XX:XX:XX:XX:XX',
    action: SlashAction.extractMacAddressesFromLines,
    keywords: ['extract', 'mac', 'address', 'ethernet', 'network',
        'hardware', 'nic'],
  ),
  SlashEntry(
    icon: 'code',
    label: 'Extract markdown code spans',
    hint: '`foo` → foo',
    action: SlashAction.extractMarkdownCodeSpansFromLines,
    keywords: ['extract', 'code', 'inline', 'backtick', 'span',
        'markdown', 'identifier'],
  ),
  SlashEntry(
    icon: 'hash',
    label: 'Extract markdown headings',
    hint: '## Title → Title',
    action: SlashAction.extractMarkdownHeadingsFromLines,
    keywords: ['extract', 'heading', 'header', 'title', 'h1', 'h2',
        'h3', 'h4', 'h5', 'h6', 'toc', 'markdown', 'atx'],
  ),
  SlashEntry(
    icon: 'quote',
    label: 'Extract blockquote content',
    hint: '> quoted → quoted',
    action: SlashAction.extractMarkdownBlockquoteContentFromLines,
    keywords: ['extract', 'blockquote', 'quote', 'cite', 'gt',
        'markdown'],
  ),
  SlashEntry(
    icon: 'list',
    label: 'Extract list item content',
    hint: '- foo / 1. foo → foo',
    action: SlashAction.extractMarkdownListContentFromLines,
    keywords: ['extract', 'list', 'bullet', 'item', 'ordered',
        'unordered', 'markdown'],
  ),
  SlashEntry(
    icon: 'strikethrough',
    label: 'Extract strikethrough content',
    hint: '~~struck~~ → struck',
    action: SlashAction.extractMarkdownStrikethroughFromLines,
    keywords: ['extract', 'strikethrough', 'strike', 'crossed',
        'gfm', 'markdown', 'tilde'],
  ),
  SlashEntry(
    icon: 'code',
    label: 'Extract code fence langs',
    hint: '```dart → dart',
    action: SlashAction.extractMarkdownCodeFenceLangsFromLines,
    keywords: ['extract', 'fence', 'fenced', 'lang', 'language',
        'code', 'block', 'markdown', 'backtick'],
  ),
  SlashEntry(
    icon: 'bold',
    label: 'Extract bold content',
    hint: '**foo** / __foo__ → foo',
    action: SlashAction.extractMarkdownBoldFromLines,
    keywords: ['extract', 'bold', 'strong', 'emphasis', 'markdown',
        'asterisk', 'underscore'],
  ),
  SlashEntry(
    icon: 'italic',
    label: 'Extract italic content',
    hint: '*foo* / _foo_ → foo',
    action: SlashAction.extractMarkdownItalicFromLines,
    keywords: ['extract', 'italic', 'emphasis', 'markdown',
        'asterisk', 'underscore', 'em'],
  ),
  SlashEntry(
    icon: 'hash',
    label: 'Extract footnote IDs',
    hint: '[^1] → 1',
    action: SlashAction.extractMarkdownFootnoteIdsFromLines,
    keywords: ['extract', 'footnote', 'id', 'ref', 'reference',
        'definition', 'markdown', 'gfm', 'pandoc'],
  ),
  SlashEntry(
    icon: 'note',
    label: 'Extract footnote bodies',
    hint: '[^1]: text → text',
    action: SlashAction.extractMarkdownFootnoteBodiesFromLines,
    keywords: ['extract', 'footnote', 'body', 'text', 'definition',
        'def', 'markdown', 'gfm', 'pandoc'],
  ),
  SlashEntry(
    icon: 'link',
    label: 'Extract bare URLs',
    hint: 'example.com/path',
    action: SlashAction.extractBareUrlsFromLines,
    keywords: ['extract', 'bare', 'url', 'domain', 'host', 'site',
        'noprotocol'],
  ),
  SlashEntry(
    icon: 'calendar',
    label: 'Extract years (1800-2099)',
    hint: '1995 / 2024',
    action: SlashAction.extractYearsFromLines,
    keywords: ['extract', 'year', 'date', 'citation', 'bibliography',
        'timeline'],
  ),
  SlashEntry(
    icon: 'link',
    label: 'Extract autolinks',
    hint: '<https://x> → https://x',
    action: SlashAction.extractMarkdownAutolinksFromLines,
    keywords: ['extract', 'autolink', 'angle', 'url', 'commonmark',
        'wrapped', 'markdown'],
  ),
  SlashEntry(
    icon: 'tag',
    label: 'Extract HTML tag names',
    hint: '<div> / </body> → div / body',
    action: SlashAction.extractHtmlTagsFromLines,
    keywords: ['extract', 'html', 'tag', 'element', 'name',
        'sanitize', 'audit'],
  ),
  SlashEntry(
    icon: 'tag',
    label: 'Extract HTML attribute names',
    hint: 'href="x" → href',
    action: SlashAction.extractHtmlAttributeNamesFromLines,
    keywords: ['extract', 'html', 'attribute', 'attr', 'name',
        'audit', 'sanitize'],
  ),
  SlashEntry(
    icon: 'tag',
    label: 'Extract HTML attribute values',
    hint: 'href="x" → x',
    action: SlashAction.extractHtmlAttributeValuesFromLines,
    keywords: ['extract', 'html', 'attribute', 'attr', 'value',
        'audit', 'sanitize'],
  ),
  SlashEntry(
    icon: 'link',
    label: 'Extract ref-link usage labels',
    hint: '[text][label] → label',
    action: SlashAction.extractMarkdownReferenceLinkUsageLabelsFromLines,
    keywords: ['extract', 'reference', 'ref', 'link', 'usage',
        'inline', 'label', 'markdown'],
  ),
  SlashEntry(
    icon: 'calendar',
    label: 'Extract calendar dates',
    hint: 'Jan 1, 2024 / January 1, 2024',
    action: SlashAction.extractCalendarDatesFromLines,
    keywords: ['extract', 'date', 'calendar', 'month', 'day',
        'year', 'citation', 'prose'],
  ),
  SlashEntry(
    icon: 'calendar',
    label: 'Extract ISO weeks',
    hint: 'YYYY-Www, e.g. 2024-W12',
    action: SlashAction.extractIsoWeeksFromLines,
    keywords: ['extract', 'iso', 'week', 'sprint', 'schedule',
        '8601'],
  ),
  SlashEntry(
    icon: 'link',
    label: 'Extract image-ref usage labels',
    hint: '![alt][label] → label',
    action: SlashAction.extractMarkdownImageReferenceUsageLabelsFromLines,
    keywords: ['extract', 'image', 'img', 'reference', 'ref',
        'usage', 'label', 'markdown'],
  ),
  SlashEntry(
    icon: 'hash',
    label: 'Extract CIDR notations',
    hint: '10.0.0.0/8',
    action: SlashAction.extractCidrFromLines,
    keywords: ['extract', 'cidr', 'subnet', 'network', 'ipv4',
        'firewall', 'route'],
  ),
  SlashEntry(
    icon: 'note',
    label: 'Extract HTML comments',
    hint: '<!-- foo --> → foo',
    action: SlashAction.extractHtmlCommentsFromLines,
    keywords: ['extract', 'html', 'comment', 'hidden', 'todo',
        'note', 'audit'],
  ),
  SlashEntry(
    icon: 'users',
    label: 'Extract email domains',
    hint: 'user@example.com → example.com',
    action: SlashAction.extractEmailDomainsFromLines,
    keywords: ['extract', 'email', 'domain', 'provider', 'contact',
        'mail'],
  ),
  SlashEntry(
    icon: 'users',
    label: 'Extract email local-parts',
    hint: 'user@example.com → user',
    action: SlashAction.extractEmailLocalPartsFromLines,
    keywords: ['extract', 'email', 'local', 'username', 'contact',
        'mail'],
  ),
  SlashEntry(
    icon: 'link',
    label: 'Extract wikilink aliases',
    hint: '[[ULID|alias]] → alias',
    action: SlashAction.extractWikilinkAliasesFromLines,
    keywords: ['extract', 'wikilink', 'alias', 'display', 'name',
        'i18n'],
  ),
  SlashEntry(
    icon: 'link',
    label: 'Extract wikilink anchors',
    hint: '[[ULID#anchor]] → anchor',
    action: SlashAction.extractWikilinkAnchorsFromLines,
    keywords: ['extract', 'wikilink', 'anchor', 'section', 'slug',
        'deeplink'],
  ),
  SlashEntry(
    icon: 'link',
    label: 'Extract YouTube video IDs',
    hint: 'youtu.be/XXX → XXX',
    action: SlashAction.extractYoutubeIdsFromLines,
    keywords: ['extract', 'youtube', 'video', 'id', 'watch',
        'embed'],
  ),
  SlashEntry(
    icon: 'link',
    label: 'Extract GitHub repo paths',
    hint: 'github.com/foo/bar → foo/bar',
    action: SlashAction.extractGithubRepoPathsFromLines,
    keywords: ['extract', 'github', 'repo', 'repository', 'owner',
        'slug'],
  ),
  SlashEntry(
    icon: 'calendar',
    label: 'Extract year ranges',
    hint: '1995-2024 / 2000–2010',
    action: SlashAction.extractYearRangesFromLines,
    keywords: ['extract', 'year', 'range', 'timespan', 'period',
        'copyright', 'career'],
  ),
  SlashEntry(
    icon: 'hash',
    label: 'Extract DOIs',
    hint: '10.NNNN/suffix',
    action: SlashAction.extractDoiFromLines,
    keywords: ['extract', 'doi', 'citation', 'paper', 'academic',
        'bibliography'],
  ),
  SlashEntry(
    icon: 'file',
    label: 'Extract file extensions',
    hint: 'pic.png → png',
    action: SlashAction.extractFileExtensionsFromLines,
    keywords: ['extract', 'file', 'extension', 'ext', 'type',
        'filename', 'asset'],
  ),
  SlashEntry(
    icon: 'hash',
    label: 'Extract ISBN-13s',
    hint: '978-3-16-148410-0',
    action: SlashAction.extractIsbn13FromLines,
    keywords: ['extract', 'isbn', 'book', 'bibliography',
        'catalog'],
  ),
  SlashEntry(
    icon: 'hash',
    label: 'Extract JIRA tickets',
    hint: 'PROJ-1234',
    action: SlashAction.extractJiraTicketsFromLines,
    keywords: ['extract', 'jira', 'ticket', 'issue', 'sprint',
        'project'],
  ),
  SlashEntry(
    icon: 'hash',
    label: 'Extract PR/issue refs',
    hint: '#1234',
    action: SlashAction.extractPrIssueRefsFromLines,
    keywords: ['extract', 'pr', 'issue', 'github', 'reference',
        'changelog'],
  ),
  SlashEntry(
    icon: 'hash',
    label: 'Extract Roman numerals',
    hint: 'IV / MCMXCIX',
    action: SlashAction.extractRomanNumeralsFromLines,
    keywords: ['extract', 'roman', 'numeral', 'outline', 'chapter',
        'index'],
  ),
  SlashEntry(
    icon: 'hash',
    label: 'Extract lat/lng pairs',
    hint: '40.7128,-74.0060',
    action: SlashAction.extractLatLngFromLines,
    keywords: ['extract', 'lat', 'lng', 'lon', 'longitude',
        'latitude', 'gps', 'coordinate', 'map'],
  ),
  SlashEntry(
    icon: 'hash',
    label: 'Extract ETH addresses',
    hint: '0x + 40 hex chars',
    action: SlashAction.extractEthAddressesFromLines,
    keywords: ['extract', 'eth', 'ethereum', 'address', 'wallet',
        'crypto', 'blockchain'],
  ),
  SlashEntry(
    icon: 'hash',
    label: 'Extract MongoDB ObjectIds',
    hint: '24 hex chars',
    action: SlashAction.extractMongoObjectIdsFromLines,
    keywords: ['extract', 'mongo', 'mongodb', 'objectid', 'id',
        'nosql'],
  ),
  SlashEntry(
    icon: 'hash',
    label: 'Extract AWS ARNs',
    hint: 'arn:aws:service:region:account:resource',
    action: SlashAction.extractAwsArnsFromLines,
    keywords: ['extract', 'aws', 'arn', 'amazon', 'iam',
        'resource'],
  ),
  SlashEntry(
    icon: 'hash',
    label: 'Extract MAC OUIs',
    hint: 'XX:XX:XX:67:89:AB → XX:XX:XX',
    action: SlashAction.extractMacOuisFromLines,
    keywords: ['extract', 'mac', 'oui', 'vendor', 'manufacturer',
        'prefix', 'network'],
  ),
  SlashEntry(
    icon: 'link',
    label: 'Extract Twitter/X status IDs',
    hint: 'twitter.com/u/status/N → N',
    action: SlashAction.extractTwitterStatusIdsFromLines,
    keywords: ['extract', 'twitter', 'x', 'tweet', 'status',
        'id'],
  ),
  SlashEntry(
    icon: 'link',
    label: 'Extract GitHub issue/PR #s',
    hint: 'github.com/o/r/issues/N → N',
    action: SlashAction.extractGithubIssuePrNumbersFromLines,
    keywords: ['extract', 'github', 'issue', 'pr', 'number',
        'pull', 'request'],
  ),
  SlashEntry(
    icon: 'hash',
    label: 'Extract NPM scoped packages',
    hint: '@scope/name',
    action: SlashAction.extractNpmScopedPackagesFromLines,
    keywords: ['extract', 'npm', 'package', 'scope', 'dep',
        'dependency'],
  ),
  SlashEntry(
    icon: 'hash',
    label: 'Extract HTTP status codes',
    hint: '404 / 500 / 200',
    action: SlashAction.extractHttpStatusCodesFromLines,
    keywords: ['extract', 'http', 'status', 'code', 'error',
        'response', 'api'],
  ),
  SlashEntry(
    icon: 'link',
    label: 'Extract StackOverflow Q IDs',
    hint: 'stackoverflow.com/questions/N → N',
    action: SlashAction.extractStackOverflowQuestionIdsFromLines,
    keywords: ['extract', 'stackoverflow', 'so', 'question',
        'answer', 'citation'],
  ),
  SlashEntry(
    icon: 'calendar',
    label: 'Extract times of day',
    hint: 'HH:MM / HH:MM AM',
    action: SlashAction.extractTimeOfDayFromLines,
    keywords: ['extract', 'time', 'clock', 'hour', 'minute',
        'meeting', 'schedule', 'log'],
  ),
  SlashEntry(
    icon: 'hash',
    label: 'Extract percentages',
    hint: '42% / 99.9%',
    action: SlashAction.extractPercentagesFromLines,
    keywords: ['extract', 'percent', 'percentage', 'rate', 'kpi',
        'growth', 'analytics'],
  ),
  SlashEntry(
    icon: 'hash',
    label: 'Extract currency amounts',
    hint: '\$10.99 / €5 / £100',
    action: SlashAction.extractCurrencyFromLines,
    keywords: ['extract', 'currency', 'money', 'price', 'dollar',
        'euro', 'pound', 'yen', 'amount', 'invoice', 'budget'],
  ),
  SlashEntry(
    icon: 'file',
    label: 'Extract file sizes',
    hint: '1.5 MB / 42KB / 2GiB',
    action: SlashAction.extractFileSizesFromLines,
    keywords: ['extract', 'size', 'bytes', 'kb', 'mb', 'gb', 'tb',
        'pb', 'kib', 'mib', 'gib', 'disk', 'storage'],
  ),
  SlashEntry(
    icon: 'hash',
    label: 'Extract git short SHAs',
    hint: '7-40 hex w/ ≥1 letter',
    action: SlashAction.extractGitShasFromLines,
    keywords: ['extract', 'git', 'sha', 'commit', 'hash', 'short',
        'hex', 'revision'],
  ),
  SlashEntry(
    icon: 'users',
    label: 'Extract phone numbers',
    hint: '+1-555-123-4567',
    action: SlashAction.extractPhoneNumbersFromLines,
    keywords: ['extract', 'phone', 'number', 'e164', 'tel',
        'mobile', 'contact'],
  ),
  SlashEntry(
    icon: 'sync',
    label: 'Canonicalize HR lines',
    hint: '*** / ___ / - - - → ---',
    action: SlashAction.canonicalizeHorizontalRules,
    keywords: ['canonicalize', 'normalize', 'hr', 'horizontal',
        'rule', 'divider', 'separator', 'thematic', 'break'],
  ),
  SlashEntry(
    icon: 'link',
    label: 'Extract reference-link URLs',
    hint: '[label]: url → url',
    action: SlashAction.extractMarkdownReferenceLinkUrlsFromLines,
    keywords: ['extract', 'reference', 'ref', 'link', 'url',
        'definition', 'def', 'shortcut', 'markdown'],
  ),
  SlashEntry(
    icon: 'edit',
    label: 'Extract reference-link labels',
    hint: '[label]: url → label',
    action: SlashAction.extractMarkdownReferenceLinkLabelsFromLines,
    keywords: ['extract', 'reference', 'ref', 'link', 'label',
        'definition', 'def', 'shortcut', 'markdown'],
  ),
  SlashEntry(
    icon: 'table',
    label: 'Extract table cells',
    hint: '| a | b | → a / b',
    action: SlashAction.extractMarkdownTableCellsFromLines,
    keywords: ['extract', 'table', 'cell', 'row', 'pipe',
        'markdown', 'data'],
  ),
  SlashEntry(
    icon: 'edit',
    label: 'Extract markdown link labels',
    hint: '[label](url) → label',
    action: SlashAction.extractMarkdownLinkLabelsFromLines,
    keywords: ['extract', 'link', 'label', 'markdown', 'anchor', 'text'],
  ),
  SlashEntry(
    icon: 'link',
    label: 'Extract markdown link URLs',
    hint: '[label](url) → url',
    action: SlashAction.extractMarkdownLinkUrlsFromLines,
    keywords: ['extract', 'link', 'url', 'markdown', 'href', 'target'],
  ),
  SlashEntry(
    icon: 'link',
    label: 'Extract markdown image URLs',
    hint: '![alt](url) → url',
    action: SlashAction.extractMarkdownImageUrlsFromLines,
    keywords: ['extract', 'image', 'img', 'url', 'src', 'markdown',
        'attachment', 'photo'],
  ),
  SlashEntry(
    icon: 'edit',
    label: 'Extract markdown image alts',
    hint: '![alt](url) → alt',
    action: SlashAction.extractMarkdownImageAltsFromLines,
    keywords: ['extract', 'image', 'img', 'alt', 'caption', 'accessibility',
        'markdown'],
  ),
  SlashEntry(
    icon: 'sync',
    label: 'Sort by word count',
    hint: 'fewest words first',
    action: SlashAction.sortLinesByWordCount,
    keywords: ['sort', 'word', 'count', 'words', 'terse'],
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
    icon: 'edit',
    label: 'Swap case (invert)',
    hint: 'aBC → AbC',
    action: SlashAction.swapCaseSelectedLines,
    keywords: ['swap', 'invert', 'case', 'toggle', 'flip'],
  ),
  SlashEntry(
    icon: 'edit',
    label: 'Capitalize first letter per line',
    hint: 'leave the rest untouched',
    action: SlashAction.capitalizeFirstLetterPerLine,
    keywords: ['capitalize', 'cap', 'first', 'letter', 'bullet'],
  ),
  SlashEntry(
    icon: 'edit',
    label: 'ASCII only (drop non-ASCII)',
    hint: 'aggressive Unicode strip',
    action: SlashAction.asciiOnlyLines,
    keywords: ['ascii', 'strip', 'unicode', 'plain', 'normalize'],
  ),
  SlashEntry(
    icon: 'edit',
    label: 'Strip markdown formatting',
    hint: '**bold** _it_ → bold it',
    action: SlashAction.stripMarkdownEmphasisLines,
    keywords: ['strip', 'plain', 'unwrap', 'emphasis', 'bold', 'italic',
        'markdown', 'remove'],
  ),
  SlashEntry(
    icon: 'edit',
    label: 'Strip markdown links',
    hint: '[label](url) → label',
    action: SlashAction.stripMarkdownLinksLines,
    keywords: ['strip', 'unlink', 'link', 'url', 'markdown', 'plain'],
  ),
  SlashEntry(
    icon: 'edit',
    label: 'Strip HTML tags',
    hint: '<b>Hi</b> → Hi',
    action: SlashAction.stripHtmlTagsLines,
    keywords: ['strip', 'html', 'tag', 'unwrap', 'plain', 'remove'],
  ),
  SlashEntry(
    icon: 'edit',
    label: 'Prefix lines with index',
    hint: '01. foo / 02. bar',
    action: SlashAction.prefixLinesWithIndex,
    keywords: ['prefix', 'index', 'number', 'enumerate', 'count', 'numbered'],
  ),
  SlashEntry(
    icon: 'edit',
    label: 'Strip leading number prefix',
    hint: '01. foo → foo',
    action: SlashAction.stripLeadingNumberPrefix,
    keywords: ['strip', 'unnumber', 'denumber', 'leading', 'prefix', 'remove'],
  ),
  SlashEntry(
    icon: 'edit',
    label: 'Split into sentences',
    hint: 'one sentence per line',
    action: SlashAction.splitLinesOnSentences,
    keywords: ['split', 'sentence', 'sentences', 'proofread', 'review', 'break'],
  ),
  SlashEntry(
    icon: 'edit',
    label: 'Bulletize sentences',
    hint: 'paragraph → "- " list',
    action: SlashAction.bulletizeSentences,
    keywords: ['bullet', 'list', 'sentence', 'sentences', 'paragraph', 'split'],
  ),
  SlashEntry(
    icon: 'edit',
    label: 'Join into one paragraph',
    hint: 'glue lines with spaces',
    action: SlashAction.joinLinesWithSpace,
    keywords: ['join', 'merge', 'paragraph', 'glue', 'concat', 'flow'],
  ),
  SlashEntry(
    icon: 'edit',
    label: 'Strip emoji',
    hint: 'hello 👋 → hello',
    action: SlashAction.stripEmojiLines,
    keywords: ['strip', 'emoji', 'remove', 'plain', 'unicode'],
  ),
  SlashEntry(
    icon: 'edit',
    label: 'Remove accents',
    hint: 'café → cafe',
    action: SlashAction.removeAccentsLines,
    keywords: ['accent', 'accents', 'diacritic', 'ascii', 'fold', 'normalize'],
  ),
  SlashEntry(
    icon: 'note',
    label: 'Insert lorem ipsum',
    hint: 'placeholder paragraph',
    action: SlashAction.insertLoremIpsum,
    keywords: ['lorem', 'ipsum', 'placeholder', 'fill', 'stub', 'dummy'],
  ),
  SlashEntry(
    icon: 'note',
    label: 'Meeting notes scaffold',
    hint: 'attendees / agenda / decisions / actions',
    action: SlashAction.insertMeetingNotesScaffold,
    keywords: ['meeting', 'notes', 'agenda', 'minutes', 'template', 'scaffold'],
  ),
  SlashEntry(
    icon: 'note',
    label: 'Standup notes scaffold',
    hint: 'yesterday / today / blockers',
    action: SlashAction.insertStandupScaffold,
    keywords: ['standup', 'agile', 'daily', 'scrum', 'template', 'scaffold'],
  ),
  SlashEntry(
    icon: 'note',
    label: 'Retrospective scaffold',
    hint: "went well / didn't / actions",
    action: SlashAction.insertRetroScaffold,
    keywords: ['retro', 'retrospective', 'sprint', 'review', 'template', 'scaffold'],
  ),
  SlashEntry(
    icon: 'note',
    label: 'ADR scaffold',
    hint: 'context / decision / consequences',
    action: SlashAction.insertAdrScaffold,
    keywords: ['adr', 'decision', 'architecture', 'record', 'template', 'scaffold'],
  ),
  SlashEntry(
    icon: 'note',
    label: '1:1 scaffold',
    hint: 'their topics / mine / career / actions',
    action: SlashAction.insertOneOnOneScaffold,
    keywords: ['1on1', '1:1', 'oneonone', 'one-on-one', 'sync',
        'manager', 'report', 'template', 'scaffold'],
  ),
  SlashEntry(
    icon: 'note',
    label: 'Post-mortem scaffold',
    hint: 'summary / timeline / cause / actions',
    action: SlashAction.insertPostMortemScaffold,
    keywords: ['postmortem', 'post-mortem', 'incident', 'outage',
        'rca', 'root', 'cause', 'blameless', 'template', 'scaffold'],
  ),
  SlashEntry(
    icon: 'edit',
    label: 'Indent lines',
    hint: 'add 2 spaces',
    action: SlashAction.indentLines,
    keywords: ['indent', 'tab', 'nest', 'shift', 'right'],
  ),
  SlashEntry(
    icon: 'edit',
    label: 'Wrap lines at 80 chars',
    hint: 'fold at column 80',
    action: SlashAction.wrapLinesAt80,
    keywords: ['wrap', 'fold', 'reflow', '80', 'column', 'break'],
  ),
  SlashEntry(
    icon: 'edit',
    label: 'Escape markdown',
    hint: r'**bold** → \*\*bold\*\*',
    action: SlashAction.escapeMarkdownLines,
    keywords: ['escape', 'verbatim', 'literal', 'backslash', 'markdown'],
  ),
  SlashEntry(
    icon: 'hash',
    label: 'Prefix lines with char count',
    hint: '[12] hello world',
    action: SlashAction.prefixLinesWithCharCount,
    keywords: ['count', 'chars', 'length', 'prefix', 'measure'],
  ),
  SlashEntry(
    icon: 'hash',
    label: 'Strip char-count prefix',
    hint: '[12] foo → foo',
    action: SlashAction.stripLeadingCharCountPrefix,
    keywords: ['strip', 'remove', 'count', 'prefix', 'chars', 'undo'],
  ),
  SlashEntry(
    icon: 'edit',
    label: 'Remove bare URLs',
    hint: 'http(s)/ftp → drop',
    action: SlashAction.removeUrlsLines,
    keywords: ['strip', 'remove', 'url', 'http', 'https', 'ftp', 'link'],
  ),
  SlashEntry(
    icon: 'hash',
    label: 'Prefix lines with word count',
    hint: '[3] one two three',
    action: SlashAction.prefixLinesWithWordCount,
    keywords: ['count', 'words', 'word', 'prefix', 'measure'],
  ),
  SlashEntry(
    icon: 'edit',
    label: 'Strip blockquote prefix',
    hint: '> foo → foo',
    action: SlashAction.stripBlockquotePrefix,
    keywords: ['strip', 'unquote', 'blockquote', 'quote', 'prefix'],
  ),
  SlashEntry(
    icon: 'edit',
    label: 'Add blockquote prefix',
    hint: 'foo → > foo (idempotent-add)',
    action: SlashAction.addBlockquotePrefix,
    keywords: ['add', 'quote', 'blockquote', 'prefix', 'nest'],
  ),
  SlashEntry(
    icon: 'edit',
    label: 'Trim blank edge lines',
    hint: 'drop leading + trailing blanks',
    action: SlashAction.trimBlankEdgeLines,
    keywords: ['trim', 'strip', 'blank', 'edge', 'leading', 'trailing'],
  ),
  SlashEntry(
    icon: 'edit',
    label: 'Dedent (remove common indent)',
    hint: 'strip shared prefix whitespace',
    action: SlashAction.dedentLines,
    keywords: ['dedent', 'unindent', 'flatten', 'normalize'],
  ),
  SlashEntry(
    icon: 'edit',
    label: 'Strip heading marker',
    hint: '## foo → foo',
    action: SlashAction.stripHeadingMarker,
    keywords: ['strip', 'heading', 'header', 'h1', 'h2', 'demote', 'hash'],
  ),
  SlashEntry(
    icon: 'edit',
    label: 'Outdent lines',
    hint: 'strip 2 spaces',
    action: SlashAction.outdentLines,
    keywords: ['outdent', 'untab', 'unnest', 'shift', 'left', 'dedent'],
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
