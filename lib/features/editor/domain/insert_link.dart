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
InsertLinkResult insertMarkdownLink({
  required String text,
  required int start,
  required int end,
  required String label,
  required String url,
}) {
  final a = start.clamp(0, text.length);
  final b = end.clamp(a, text.length);
  final snippet = '[$label]($url)';
  final next = text.replaceRange(a, b, snippet);
  return InsertLinkResult(text: next, caret: a + snippet.length);
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
