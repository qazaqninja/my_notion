/// Strip markdown formatting from [body] so it can be pasted as plain
/// text into a tool that doesn't render markdown (e.g. Slack message
/// body, an email). Strategy: keep the text content, strip the
/// scaffolding — bold / italic / strike / code markers, heading
/// hashes, list dashes, blockquote markers, wikilink brackets,
/// inline-code backticks, and fenced-code fences.
///
/// Conservative on transformations:
///   * fenced code blocks are dropped entirely (too noisy as text),
///   * `[[ULID]]` wikilinks are dropped (ULIDs are meaningless out of
///     vault context),
///   * `[label](url)` becomes `label (url)` so the link target is
///     visible when the rendering is gone,
///   * `![alt](path)` collapses to `alt` so images survive as
///     readable text,
///   * inline emphasis / code / highlight markers are stripped, the
///     inner text is kept.
String stripMarkdown(String body) {
  var s = body.replaceAll(RegExp(r'```[\s\S]*?```\n?'), '');
  s = s.replaceAll(RegExp(r'\[\[[0-9A-Z]{26}(?:#[^\]]+)?\]\]'), '');
  s = s.replaceAllMapped(
      RegExp(r'!\[([^\]]*)\]\([^)]*\)'), (m) => m.group(1) ?? '');
  s = s.replaceAllMapped(RegExp(r'\[([^\]]+)\]\(([^)]+)\)'),
      (m) => '${m.group(1)} (${m.group(2)})');
  s = s.replaceAllMapped(
      RegExp(r'\*\*([^*\n]+)\*\*'), (m) => m.group(1) ?? '');
  s = s.replaceAllMapped(
      RegExp(r'(?<!\*)\*([^*\n]+)\*(?!\*)'), (m) => m.group(1) ?? '');
  s = s.replaceAllMapped(RegExp(r'_([^_\n]+)_'), (m) => m.group(1) ?? '');
  s = s.replaceAllMapped(RegExp(r'~~([^~\n]+)~~'), (m) => m.group(1) ?? '');
  s = s.replaceAllMapped(RegExp(r'==([^=\n]+)=='), (m) => m.group(1) ?? '');
  s = s.replaceAllMapped(RegExp(r'`([^`\n]+)`'), (m) => m.group(1) ?? '');
  s = s.split('\n').map((line) {
    final trimmedLeft = line.trimLeft();
    final indent = line.substring(0, line.length - trimmedLeft.length);
    final h = RegExp(r'^#{1,6}\s+').firstMatch(trimmedLeft);
    if (h != null) return '$indent${trimmedLeft.substring(h.end)}';
    final m = RegExp(r'^(- \[ \] |- \[x\] |- |\* |\d+\. |> )')
        .firstMatch(trimmedLeft);
    if (m != null) return '$indent${trimmedLeft.substring(m.end)}';
    return line;
  }).join('\n');
  return s.trim();
}
