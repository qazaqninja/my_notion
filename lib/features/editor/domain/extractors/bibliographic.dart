// Bibliographic / publishing identifier extractors — pulled out of
// `source_line_ops.dart` at M1176 as the second step of the FS-02
// split (geographic was first at M1175). Each function preserves the
// `(String text, int start, int end) -> SortLinesResult` contract and
// is re-exported from `source_line_ops.dart` so callers (dispatch
// switch, slash entries, tests) need no import changes.
//
// Group rationale: ISBN-13, ISBN-10, ISSN, and DOI are all "this
// publication can be looked up by this canonical identifier" — the
// audit / catalog / citation use case is the same regardless of
// whether the target is a book, periodical, or paper.

import '../source_line_ops.dart';

/// Extract every ISBN-13 substring from each selected line.
/// Useful for book-inventory mining, bibliography parsing, and
/// catalog audits.
///
/// Recognition: `\b97[89][-\s]?(?:\d[-\s]?){9}\d\b`
/// - GS1 prefix `978` or `979` (strict ISBN-13 namespace).
/// - 10 more digits (registration group + publisher + title +
///   check), each optionally preceded by a hyphen or single
///   whitespace separator.
/// - Word boundaries on each end reject embedded slices.
///
/// Captures common formats:
/// - Bare: `9783161484100`
/// - Hyphenated: `978-3-16-148410-0` (standard book-cover form)
/// - Space-separated: `978 3 16 148410 0`
///
/// No semantic check-digit validation — `978-3-16-148410-9`
/// matches even if the trailing 9 isn't the correct
/// computed check digit. Downstream layer validates if needed.
///
/// ISBN-10 (no `978`/`979` prefix, 10 digits with possible `X`
/// check) is covered by [extractIsbn10FromLinesIn] in this same
/// bibliographic family.
///
/// 58th member of the extraction family.
SortLinesResult extractIsbn13FromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(r'\b97[89][-\s]?(?:\d[-\s]?){9}\d\b');
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(0)!);
        }
      }
      return out;
    });

/// Extract every Digital Object Identifier (DOI) from each
/// selected line. Useful for research-note triage, citation
/// inventory, literature-review scrapes, and reference
/// harvests for papers / preprints / books.
///
/// Recognition: `\b10\.\d{4,9}/[^\s,;()<>\[\]"']+`
/// - Literal `10.` namespace prefix (the registered DOI
///   directory at doi.org).
/// - 4-9 digit registrant code.
/// - `/` separator.
/// - Suffix: any non-whitespace, non-bracket, non-quote
///   characters. The suffix is captured greedily up to the
///   first delimiter.
///
/// Trailing punctuation often appears at the end of citations
/// (e.g. `... doi:10.1234/abc.`). The pattern excludes
/// commas, semicolons, parentheses, angle brackets, square
/// brackets, and quotes from the suffix; periods inside the
/// suffix (like `10.1234/file.json`) ARE allowed. A pure
/// trailing-period boundary is left to downstream callers
/// since DOI suffixes can legitimately end in a period.
///
/// Matches:
/// - `10.1038/nature12373`
/// - `10.1145/3236024.3236084`
/// - `10.48550/arXiv.2305.13245`
/// - `10.1109/TIT.2006.871582`
///
/// 97th member of the extraction family.
SortLinesResult extractDoisFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(
        r'\b10\.\d{4,9}/[^\s,;()<>\[\]"' "'" r']+',
      );
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(0)!);
        }
      }
      return out;
    });

/// Extract every ISBN-10 identifier from each selected line.
/// Complements the existing ISBN-13 extractor for
/// pre-2007 books and reference systems still using the
/// older 10-digit form.
///
/// Recognition: a regex that allows either:
/// - A hyphenated form `D-D-D-X` (group-language-publisher-
///   title-check, length-variable groups), or
/// - A bare 10-character form ending in the `X` check digit
///   (the `X`-check variant is distinctive enough on its own).
///
/// Each candidate is then verified to have exactly 10
/// "digit-equivalents" (the 9 digits plus 1 check digit, where
/// the check can be either 0-9 or `X`). The verification step
/// filters out plain numeric runs like `1-2-3-4` which match
/// the hyphenated shape but lack the 10-position requirement.
///
/// Bare 10-digit ISBN-10s WITHOUT a hyphenated layout and
/// WITHOUT an `X` check digit (e.g. `0306406152`) are NOT
/// matched — they're indistinguishable from arbitrary 10-digit
/// numbers in prose. Use the hyphenated presentation when
/// authoring ISBN references.
///
/// Matches:
/// - `0-306-40615-2`      — classic hyphenated form
/// - `7-803-44132-X`      — hyphenated with X check
/// - `030640615X`         — bare with X check (distinctive)
///
/// ISBN-10 check-digit validity (mod-11) is NOT verified —
/// downstream callers can run mod-11 if they want strict
/// validation.
///
/// 101st member of the extraction family.
SortLinesResult extractIsbn10FromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      // Lookarounds `(?<![\d-])` / `(?![\d-])` prevent the
      // regex from carving out the trailing 10-digit suffix of
      // an ISBN-13 like `978-0-13-468599-1` and reporting it
      // as a standalone ISBN-10.
      final re = RegExp(
        r'(?<![\d-])'
        r'(?:\d{1,5}-\d{1,7}-\d{1,6}-[\dX]|\d{9}X)'
        r'(?![\d-])',
      );
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          final s = m.group(0)!;
          // Count digit-equivalents (digits + X).
          // ISBN-10 must have exactly 10.
          final n = s.replaceAll(RegExp(r'[^\dX]'), '').length;
          if (n == 10) out.add(s);
        }
      }
      return out;
    });

/// Extract every ISSN (International Standard Serial Number)
/// from each selected line. Useful for periodical / journal
/// catalog audits, bibliography triage, and library-system
/// reference harvests.
///
/// Recognition: `(?<!\d)\d{4}-\d{3}[\dX](?!\d)`
/// - 4 digits (group prefix), hyphen, 3 digits (group suffix),
///   1 check digit (0-9 or `X`).
/// - Total 8 digit-equivalents, hyphen at position 4.
/// - Lookarounds reject matches embedded inside longer numeric
///   runs.
///
/// Matches:
/// - `0028-0836`        — Nature
/// - `1469-5448`        — Journal of Science Communication
/// - `0024-9319`        — Library Hi Tech
/// - `2049-632X`        — example with X check digit
///
/// ISSN check-digit validity (mod-11) is NOT verified — that's
/// a downstream semantic check. The regex enforces shape only.
///
/// Distinct from [extractIsbn10FromLinesIn] (book identifier
/// with hyphenated 4-group layout) and [extractIsbn13FromLinesIn]
/// (978/979-prefixed 13-digit form). ISSN's strict 4-3-check
/// shape has no overlap with those.
///
/// 102nd member of the extraction family.
SortLinesResult extractIssnFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(r'(?<!\d)\d{4}-\d{3}[\dX](?!\d)');
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(0)!);
        }
      }
      return out;
    });
