// Selection-range "make this paste plain" transforms — strip markdown
// emphasis, link/image syntax, inline HTML tags, and leading
// number-enumerator prefixes from every line that a selection
// touches. Extracted from `source_line_ops.dart` (M983) because the
// parent file crossed 3,000 lines and the cleanup family is a
// self-contained group with no cross-family dependencies.
//
// Each function preserves the same `(String text, int start, int end)`
// → `SortLinesResult` contract as the rest of the line-op family and
// is dispatched from `source_view.dart` through the shared
// `_applyLinesTransformAfterSlash` helper. Tests live in
// `test/features/editor/selection_line_ops_test.dart` next to every
// other selection-range op.

import 'source_line_ops.dart';

/// Strip diacritics from every selected line, folding common
/// Latin-Extended accented characters to their ASCII base letter.
/// `café` → `cafe`, `naïve` → `naive`, `RÉSUMÉ` → `RESUME`.
/// Ligatures expand to their two-letter form: `æ` → `ae`, `Œ` → `OE`,
/// `ß` → `ss`. Characters outside the cover set (Greek, Cyrillic,
/// CJK, etc.) pass through.
///
/// Useful for normalizing user-entered text before generating an ID
/// or filename — sits alongside `slugifyLines`, which goes further
/// (lowercase + non-alphanumeric → `-`). Run this first if you want
/// to keep casing but lose the accents.
SortLinesResult removeAccentsLinesIn(String text, int start, int end) =>
    transformLinesIn(text, start, end, (lines) {
      // ASCII-fold table covering Latin-Extended-A (most of) and the
      // commonly-seen Latin-1 Supplement diacritics. Multi-letter
      // outputs (æ→ae, ß→ss) are intentional — the gesture is
      // "preserve readable text," not "preserve byte count."
      const fold = <String, String>{
        'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a',
        'ā': 'a', 'ă': 'a', 'ą': 'a', 'ǎ': 'a', 'ǻ': 'a',
        'À': 'A', 'Á': 'A', 'Â': 'A', 'Ã': 'A', 'Ä': 'A', 'Å': 'A',
        'Ā': 'A', 'Ă': 'A', 'Ą': 'A', 'Ǎ': 'A', 'Ǻ': 'A',
        'ç': 'c', 'ć': 'c', 'ĉ': 'c', 'ċ': 'c', 'č': 'c',
        'Ç': 'C', 'Ć': 'C', 'Ĉ': 'C', 'Ċ': 'C', 'Č': 'C',
        'đ': 'd', 'ď': 'd', 'Đ': 'D', 'Ď': 'D',
        'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', 'ē': 'e', 'ĕ': 'e',
        'ė': 'e', 'ę': 'e', 'ě': 'e',
        'È': 'E', 'É': 'E', 'Ê': 'E', 'Ë': 'E', 'Ē': 'E', 'Ĕ': 'E',
        'Ė': 'E', 'Ę': 'E', 'Ě': 'E',
        'ĝ': 'g', 'ğ': 'g', 'ġ': 'g', 'ģ': 'g',
        'Ĝ': 'G', 'Ğ': 'G', 'Ġ': 'G', 'Ģ': 'G',
        'ĥ': 'h', 'ħ': 'h', 'Ĥ': 'H', 'Ħ': 'H',
        'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', 'ĩ': 'i', 'ī': 'i',
        'ĭ': 'i', 'į': 'i', 'ı': 'i',
        'Ì': 'I', 'Í': 'I', 'Î': 'I', 'Ï': 'I', 'Ĩ': 'I', 'Ī': 'I',
        'Ĭ': 'I', 'Į': 'I', 'İ': 'I',
        'ĵ': 'j', 'Ĵ': 'J',
        'ķ': 'k', 'Ķ': 'K',
        'ĺ': 'l', 'ļ': 'l', 'ľ': 'l', 'ł': 'l',
        'Ĺ': 'L', 'Ļ': 'L', 'Ľ': 'L', 'Ł': 'L',
        'ñ': 'n', 'ń': 'n', 'ņ': 'n', 'ň': 'n',
        'Ñ': 'N', 'Ń': 'N', 'Ņ': 'N', 'Ň': 'N',
        'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', 'ø': 'o',
        'ō': 'o', 'ŏ': 'o', 'ő': 'o', 'ǒ': 'o',
        'Ò': 'O', 'Ó': 'O', 'Ô': 'O', 'Õ': 'O', 'Ö': 'O', 'Ø': 'O',
        'Ō': 'O', 'Ŏ': 'O', 'Ő': 'O', 'Ǒ': 'O',
        'ŕ': 'r', 'ŗ': 'r', 'ř': 'r', 'Ŕ': 'R', 'Ŗ': 'R', 'Ř': 'R',
        'ś': 's', 'ŝ': 's', 'ş': 's', 'š': 's', 'ș': 's',
        'Ś': 'S', 'Ŝ': 'S', 'Ş': 'S', 'Š': 'S', 'Ș': 'S',
        'ţ': 't', 'ť': 't', 'ŧ': 't', 'ț': 't',
        'Ţ': 'T', 'Ť': 'T', 'Ŧ': 'T', 'Ț': 'T',
        'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', 'ũ': 'u', 'ū': 'u',
        'ŭ': 'u', 'ů': 'u', 'ű': 'u', 'ų': 'u', 'ǔ': 'u',
        'Ù': 'U', 'Ú': 'U', 'Û': 'U', 'Ü': 'U', 'Ũ': 'U', 'Ū': 'U',
        'Ŭ': 'U', 'Ů': 'U', 'Ű': 'U', 'Ų': 'U', 'Ǔ': 'U',
        'ŵ': 'w', 'Ŵ': 'W',
        'ý': 'y', 'ÿ': 'y', 'ŷ': 'y', 'Ý': 'Y', 'Ÿ': 'Y', 'Ŷ': 'Y',
        'ź': 'z', 'ż': 'z', 'ž': 'z', 'Ź': 'Z', 'Ż': 'Z', 'Ž': 'Z',
        'ß': 'ss', 'æ': 'ae', 'Æ': 'AE', 'œ': 'oe', 'Œ': 'OE',
      };
      return [
        for (final l in lines)
          (() {
            final buf = StringBuffer();
            for (final c in l.split('')) {
              buf.write(fold[c] ?? c);
            }
            return buf.toString();
          })(),
      ];
    });

/// Escape markdown control characters on every selected line so the
/// content renders verbatim instead of being parsed. Wraps each of
/// `\`, `*`, `_`, `~`, `` ` ``, `[`, `]`, `(`, `)`, `<`, `>`, `#`,
/// `!`, and `|` with a leading backslash. Useful when pasting in
/// shell snippets, regex examples, or other prose where the source
/// must be shown to the reader literally rather than rendered.
///
/// Doesn't try to be smart about context — every occurrence of a
/// control character gets escaped. Run this BEFORE the strip-family
/// (M976/977/978) to harden a line for verbatim display; or after,
/// to escape what slipped through.
SortLinesResult escapeMarkdownLinesIn(String text, int start, int end) =>
    transformLinesIn(text, start, end, (lines) {
      const controls = r'\*_~`[]()<>#!|';
      String esc(String l) {
        final buf = StringBuffer();
        for (final c in l.split('')) {
          if (controls.contains(c)) buf.write('\\');
          buf.write(c);
        }
        return buf.toString();
      }
      return [for (final l in lines) esc(l)];
    });

/// Strip emoji glyphs from every selected line. Covers the major
/// Unicode emoji blocks (`U+1F000`-`U+1FAFF` for pictographs, plus
/// `U+2600`-`U+27BF` for Misc Symbols / Dingbats), along with the
/// variation selectors (`U+FE0E` / `U+FE0F`) and zero-width joiner
/// (`U+200D`) used to compose flag / family / profession sequences.
/// Plain ASCII text and most non-Latin scripts pass through.
///
/// Useful when emoji leaked into a paste that needs to be plain
/// prose (slugs, IDs, log lines). Completes the emoji slash-menu
/// trio alongside `pickEmoji` (insert) and `expandEmojiShortcodes`
/// (`:rocket:` → 🚀).
///
///   'hello 👋 world 🌍'  →  'hello  world '
SortLinesResult stripEmojiLinesIn(String text, int start, int end) =>
    transformLinesIn(text, start, end, (lines) {
      // Single character class covering the high-codepoint pictograph
      // ranges, the dingbats / misc-symbols block, the regional
      // indicator letters (`U+1F1E6`-`U+1F1FF` for country flags),
      // and the joiner / variation selectors. `unicode: true` lets
      // `\u{1FAFF}`-style escapes resolve as single codepoints rather
      // than UTF-16 surrogate pairs.
      final emoji = RegExp(
        r'[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{1F1E6}-\u{1F1FF}\u{FE0E}\u{FE0F}\u{200D}]',
        unicode: true,
      );
      return [for (final l in lines) l.replaceAll(emoji, '')];
    });

/// Strip markdown emphasis / decoration markers from every selected
/// line: `**bold**` / `__bold__`, `*italic*` / `_italic_`,
/// `~~strike~~`, `==highlight==`, and `` `inline code` `` all become
/// their plain inner text. Backticks remove the wrapping; the content
/// stays. Useful when pasting formatted text from an LLM or another
/// markdown editor into a section you want as plain prose.
///
///   "**Hello** _world_ ~~oops~~"  →  "Hello world oops"
///
/// Handles nested forms by repeating the pass until nothing more
/// shrinks (e.g. `***both***` → `Hello`). Markdown links / images
/// are intentionally not touched here — those have a dedicated slash
/// entry already, and unwrapping them loses the target URL.
SortLinesResult stripMarkdownEmphasisLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      // Patterns are checked in length-descending order so `~~` and
      // `**` don't get half-eaten by their single-char cousins on the
      // first pass.
      final patterns = <RegExp>[
        RegExp(r'\*\*([^*\n]+?)\*\*'),   // **bold**
        RegExp('__([^_\\n]+?)__'),         // __bold__
        RegExp('~~([^~\\n]+?)~~'),         // ~~strike~~
        RegExp('==([^=\\n]+?)=='),         // ==highlight==
        RegExp(r'\*([^*\n]+?)\*'),       // *italic*
        RegExp('_([^_\\n]+?)_'),           // _italic_
        RegExp('`([^`\\n]+?)`'),           // `code`
      ];
      String stripOnce(String s) {
        var out = s;
        for (final p in patterns) {
          out = out.replaceAllMapped(p, (m) => m.group(1)!);
        }
        return out;
      }
      return [
        for (final l in lines)
          (() {
            var prev = l;
            // Loop until fixed-point: handles ***both*** by peeling
            // outer `**` first, then `*`. Cap at lines.length+8 iters
            // as a paranoia safety net against pathological input.
            for (var i = 0; i < 16; i++) {
              final next = stripOnce(prev);
              if (next == prev) break;
              prev = next;
            }
            return prev;
          })(),
      ];
    });

/// Strip a leading number-enumerator prefix from every selected
/// line. Matches the common forms `1. ` / `1) ` / `1] ` / `1: ` /
/// `1- ` with an arbitrary digit run (zero-padded or not) and a
/// single trailing space. Leading indentation (spaces / tabs) is
/// preserved so an indented "1. foo" inside an outer list still
/// loses its number but keeps its indent.
///
/// Inverse of `prefixLinesWithIndexIn` for the most common cases,
/// and broader than `renumberListLines` (which only resequences
/// existing `1. ` markers; this removes them entirely).
///
///   01. foo            foo
///   02. bar      →     bar
///   003) baz           baz
SortLinesResult stripLeadingNumberPrefixIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      // `^[indent]<digits><sep><space>` with sep in `. : ) ] -`.
      // Capture group 1 holds the leading whitespace — `replaceFirst`
      // takes a literal string and won't expand `$1`, so use
      // `replaceFirstMapped` to inline the captured indent.
      final re = RegExp(r'^([ \t]*)\d+[.:)\]\-] ');
      return [
        for (final l in lines) l.replaceFirstMapped(re, (m) => m.group(1)!),
      ];
    });

/// Strip inline HTML tags from every selected line, leaving the
/// text content between them. Closes the "make this paste plain"
/// trilogy alongside [stripMarkdownEmphasisLinesIn] (M976) and
/// [stripMarkdownLinksLinesIn] (M977). Useful when pasting
/// Office/Word/Notion-export HTML or LLM output where formatting
/// snuck through as raw `<tag>`s rather than markdown.
///
///   '<b>Hello</b> <span class="x">world</span>'  →  'Hello world'
///
/// Per-line scope: only tags whose open and close are on the same
/// line are stripped. Multi-line block elements (`<div>` on one line,
/// `</div>` on another) leave each line's tag chrome removed in
/// isolation. HTML entities (`&amp;` etc.) pass through unchanged —
/// unescaping is a separate gesture (`htmlUnescape`).
SortLinesResult stripHtmlTagsLinesIn(String text, int start, int end) =>
    transformLinesIn(text, start, end, (lines) {
      // `<[^>\n]+>` matches any `<` ... `>` run that stays on one
      // line. Excluding `\n` keeps a stray unclosed `<` from
      // swallowing the next line.
      final tag = RegExp(r'<[^>\n]+>');
      return [for (final l in lines) l.replaceAll(tag, '')];
    });

/// Strip markdown links and images from every selected line, keeping
/// the visible label. `[Click here](url)` becomes `Click here`;
/// `![alt text](path)` becomes `alt text`. Quill-internal wikilinks
/// (`[[ULID]]` / `![[ULID]]` / `[[ULID#anchor]]` / `[[ULID|alias]]`)
/// are deliberately **not** touched — their ULID payload is the
/// canonical relation identifier and stripping it would permanently
/// lose the link target.
///
/// Useful when copy-pasting Markdown into a section that should read
/// as plain prose without clickable URLs. Often run before or after
/// [stripMarkdownEmphasisLinesIn] depending on whether the user
/// wants formatting first or links first.
SortLinesResult stripMarkdownLinksLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      // Order matters: images first (the `!` prefix is more specific),
      // then regular links. Negative lookbehind keeps wikilinks safe
      // from the bracket regex.
      final image = RegExp(r'!\[([^\]\n]*)\]\([^)\n]*\)');
      final link = RegExp(r'(?<!\[)\[([^\]\n]+)\]\(([^)\n]*)\)');
      return [
        for (final l in lines)
          l
              .replaceAllMapped(image, (m) => m.group(1) ?? '')
              .replaceAllMapped(link, (m) => m.group(1)!),
      ];
    });
