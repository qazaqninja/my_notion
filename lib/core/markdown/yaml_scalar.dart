/// YAML scalar quoting helpers. Centralises the escape logic that
/// otherwise gets copy-pasted across importers, the bloc, the database
/// repo, the properties panel, the title field, etc. — each call site
/// would otherwise reinvent the same regex, and any future fix to one
/// instance would skip the rest.
///
/// Two flavours:
///
/// - [yamlSafeScalar] — block-mapping value, e.g. `title: foo`. Quotes
///   on YAML reserved glyphs (`:`, `#`, `>`, `[`, `]`, `{`, `}`, `|`,
///   `"`, `'`, etc.) and on leading / trailing whitespace.
/// - [yamlFlowItem] — flow-list element, e.g. `tags: [foo, bar]`. Adds
///   `,` to the unsafe set since flow lists separate on commas. Returns
///   `""` for empty strings so they round-trip.
///
/// Both return the input unchanged when no escaping is needed. The
/// escaped form wraps in double quotes and backslash-escapes `\` and
/// `"` inside the value. Re-parsing through `package:yaml` recovers
/// the original string verbatim.
library;

final _unsafeBlock = RegExp(r'''[#:>\[\]\{\}\|"'`%@&!*]''');
final _unsafeFlow = RegExp(r'''[,#:>\[\]\{\}\|"'`%@&!*]''');

String _escapeForDoubleQuote(String value) =>
    value.replaceAll(r'\', r'\\')
        .replaceAll('"', r'\"')
        .replaceAll('\n', r'\n')
        .replaceAll('\r', r'\r')
        .replaceAll('\t', r'\t');

/// Block-mapping value escape. Returns [value] unchanged when it parses
/// safely as a YAML plain scalar; otherwise wraps in double quotes
/// with `\\` / `\"` escaping inside, plus `\n` / `\r` / `\t` so a
/// multi-line value stays on one line (yaml double-quoted scalars
/// interpret these escapes the same as JSON).
String yamlSafeScalar(String value) {
  if (value.isEmpty) return value;
  final needs = _unsafeBlock.hasMatch(value) ||
      value.startsWith(' ') ||
      value.endsWith(' ') ||
      value.contains('\n') ||
      value.contains('\r') ||
      value.contains('\t');
  if (!needs) return value;
  return '"${_escapeForDoubleQuote(value)}"';
}

/// Flow-list element escape — same as [yamlSafeScalar] but also quotes
/// on `,` so list items containing commas don't split. Empty strings
/// become `""` (rather than disappearing into the flow grammar).
String yamlFlowItem(String value) {
  if (value.isEmpty) return '""';
  final needs = _unsafeFlow.hasMatch(value) ||
      value.startsWith(' ') ||
      value.endsWith(' ') ||
      value.contains('\n') ||
      value.contains('\r') ||
      value.contains('\t');
  if (!needs) return value;
  return '"${_escapeForDoubleQuote(value)}"';
}

final _unsafeKeyGlyphs = RegExp(r'''[#:>\[\]\{\}\|"'`%@&!*,/\\]''');
final _whitespaceRun = RegExp(r'\s+');
final _underscoreRun = RegExp(r'_+');
final _trimUnderscores = RegExp(r'^_|_$');

/// Strip a single layer of YAML double- or single-quotes around [s].
/// Idempotent on unquoted scalars.
String _stripYamlQuotes(String s) {
  if (s.length < 2) return s;
  if ((s.startsWith('"') && s.endsWith('"')) ||
      (s.startsWith("'") && s.endsWith("'"))) {
    return s.substring(1, s.length - 1);
  }
  return s;
}

/// Parse a YAML flow list scalar (e.g. `[draft, "high, priority"]`)
/// into its constituent strings. Tracks quote state so a comma INSIDE
/// a quoted item doesn't split the list. Plain scalar input (no
/// surrounding `[ ]`) is wrapped as a one-element list, so callers
/// can treat both shapes uniformly.
///
/// Used by every site that needs to enumerate the elements of a
/// multi-value frontmatter entry (tag aggregation, cell renderers,
/// rollup readers, the flow-list reader in frontmatter_icon.dart).
List<String> parseYamlFlowList(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return const [];
  if (!trimmed.startsWith('[') || !trimmed.endsWith(']')) {
    final s = _stripYamlQuotes(trimmed);
    return s.isEmpty ? const [] : [s];
  }
  final inner = trimmed.substring(1, trimmed.length - 1);
  if (inner.trim().isEmpty) return const [];
  final out = <String>[];
  final buf = StringBuffer();
  var inQuotes = false;
  String? quoteChar;
  for (var i = 0; i < inner.length; i++) {
    final ch = inner[i];
    if (inQuotes) {
      if (ch == quoteChar) {
        inQuotes = false;
        quoteChar = null;
      } else {
        buf.write(ch);
      }
    } else if (ch == '"' || ch == "'") {
      inQuotes = true;
      quoteChar = ch;
    } else if (ch == ',') {
      final v = buf.toString().trim();
      if (v.isNotEmpty) out.add(_stripYamlQuotes(v));
      buf.clear();
    } else {
      buf.write(ch);
    }
  }
  final tail = buf.toString().trim();
  if (tail.isNotEmpty) out.add(_stripYamlQuotes(tail));
  return out;
}

/// Quote-aware split of a user-typed multi-value text into items.
/// Accepts both the bracket flow-list form (`[a, "b, c"]`) and the
/// bare comma-separated form (`a, "b, c"`) — the latter is what
/// shows up in a multi-cell or properties-panel TextField.
///
/// A user typing `"high, priority", normal` gets two items:
/// `['high, priority', 'normal']`. A user typing the more familiar
/// `tag1, tag2` (no quotes) gets two items too. Without this, the
/// edit path naively split on every `,` and the quoted form was
/// shredded into bogus items.
List<String> parseMultiValueInput(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return const [];
  // Wrap bare input in `[ ]` so the same flow-list parser handles
  // both shapes uniformly. A single token without commas survives
  // the round-trip as a one-element list.
  final wrapped = trimmed.startsWith('[') && trimmed.endsWith(']')
      ? trimmed
      : '[$trimmed]';
  return parseYamlFlowList(wrapped);
}

/// Convert a free-form label (CSV column name, Asana field, etc.) into a
/// YAML-safe block-mapping key. Lowercases, replaces every YAML
/// structure / quote / slash glyph + whitespace with `_`, collapses
/// duplicate underscores, and strips leading/trailing `_`. Falls back to
/// `'col'` on empty input so a key is always non-empty and never needs
/// quoting on emit.
///
/// Used by importers that derive frontmatter keys from user-typed
/// column headers (csv_importer M759, asana_importer M760).
String yamlSnakeKey(String label) {
  var s = label.trim().toLowerCase();
  s = s.replaceAll(_unsafeKeyGlyphs, '_');
  s = s.replaceAll(_whitespaceRun, '_');
  s = s.replaceAll(_underscoreRun, '_');
  s = s.replaceAll(_trimUnderscores, '');
  return s.isEmpty ? 'col' : s;
}
