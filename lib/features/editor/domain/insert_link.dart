/// Pure helpers for the "insert markdown link" (⌘K) flow. Splits the
/// edit into a deterministic transform so the widget can stay thin and
/// the operations are unit-testable without a render tree.
library;

class InsertLinkResult {
  const InsertLinkResult({required this.text, required this.caret});
  final String text;
  final int caret;
}

/// Insert a markdown link `[label](url)` at [start..end], replacing any
/// existing selection. The caret lands at the end of the inserted text
/// so the user can keep typing.
///
/// Empty [label] and empty [url] both stay in the output — the helper
/// is intentionally tolerant; the caller can decide what to do with
/// a half-filled prompt.
///
/// URLs that contain `(` or `)` (e.g. Wikipedia disambiguations like
/// `https://en.wikipedia.org/wiki/Apple_(disambiguation)`) are wrapped
/// in angle brackets `<…>` per CommonMark so the markdown parser can
/// still find the closing `)`. Labels that contain `]` are escaped
/// with a backslash for the same reason.
InsertLinkResult insertMarkdownLink({
  required String text,
  required int start,
  required int end,
  required String label,
  required String url,
}) {
  final a = start.clamp(0, text.length);
  final b = end.clamp(a, text.length);
  final safeLabel = label.replaceAll(']', r'\]');
  final safeUrl = (url.contains('(') || url.contains(')')) ? '<$url>' : url;
  final snippet = '[$safeLabel]($safeUrl)';
  final next = text.replaceRange(a, b, snippet);
  return InsertLinkResult(text: next, caret: a + snippet.length);
}

/// A markdown link `[label](url)` discovered around a caret offset.
class MarkdownLinkAt {
  const MarkdownLinkAt({
    required this.start,
    required this.end,
    required this.label,
    required this.url,
  });

  /// Inclusive start offset of the leading `[`.
  final int start;

  /// Exclusive end offset (one past the trailing `)`).
  final int end;
  final String label;
  final String url;
}

/// Find the markdown link `[label](url)` whose body the caret falls
/// inside. Returns null when the caret isn't inside one. Used by the
/// ⌘K dialog to pivot from "insert" to "edit existing link" mode.
///
/// Rules:
/// - The match must begin on a `[` at or before the caret.
/// - The label cannot contain `]` or a newline.
/// - The URL cannot contain `)`, whitespace, or a newline.
/// - The whole match must straddle [caret] (start ≤ caret ≤ end).
MarkdownLinkAt? findMarkdownLinkAt(String text, int caret) {
  if (caret < 0 || caret > text.length) return null;
  // Search left for a `[` that is the start of a candidate link. Stop
  // at the nearest newline so a link cannot span lines.
  var i = caret;
  if (i >= text.length) i = text.length - 1;
  if (i < 0) return null;
  while (i >= 0) {
    final c = text[i];
    if (c == '\n') return null;
    if (c == '[') break;
    i--;
  }
  if (i < 0) return null;
  final start = i;
  final closeLabel = text.indexOf(']', start + 1);
  if (closeLabel == -1) return null;
  final label = text.substring(start + 1, closeLabel);
  if (label.contains('\n') || label.contains('[')) return null;
  if (closeLabel + 1 >= text.length || text[closeLabel + 1] != '(') {
    return null;
  }
  final closeUrl = text.indexOf(')', closeLabel + 2);
  if (closeUrl == -1) return null;
  final url = text.substring(closeLabel + 2, closeUrl);
  if (url.contains('\n') ||
      url.contains(' ') ||
      url.contains('\t') ||
      url.contains('(')) {
    return null;
  }
  final end = closeUrl + 1;
  if (caret < start || caret > end) return null;
  return MarkdownLinkAt(
    start: start,
    end: end,
    label: label,
    url: url,
  );
}

/// Quick URL sniff. Recognises http(s)://, ftp://, mailto:, and bare
/// www. prefixes. Permissive enough to match what the user copies; the
/// markdown renderer is responsible for any further validation.
bool looksLikeUrl(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return false;
  if (s.contains(' ') || s.contains('\n') || s.contains('\t')) return false;
  final lower = s.toLowerCase();
  return lower.startsWith('http://') ||
      lower.startsWith('https://') ||
      lower.startsWith('ftp://') ||
      lower.startsWith('mailto:') ||
      lower.startsWith('www.');
}
