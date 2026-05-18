import '../../vault/domain/entities/frontmatter_entry.dart';

/// Reads the current `tags:` list from a frontmatter entry, handling
/// both the YAML-flow-list shape (`tags: [foo, bar]` → `List<dynamic>`)
/// and the bare-string shape (`tags: draft` → `String`). Every entry
/// is trimmed and dropped if empty after trim. Mirrors the legacy
/// `_addTags` inline read.
///
/// Returns `[]` for null entries, unsupported value types, or
/// all-whitespace strings.
List<String> readExistingTags(FrontmatterEntry? entry) {
  if (entry == null) return const [];
  final v = entry.value;
  if (v is List) {
    final out = <String>[];
    for (final t in v) {
      final s = '$t'.trim();
      if (s.isNotEmpty) out.add(s);
    }
    return out;
  }
  if (v is String) {
    final s = v.trim();
    if (s.isNotEmpty) return [s];
  }
  return const [];
}

/// Outcome of [mergeTags]: the full deduped list to persist plus the
/// subset that wasn't already present (for the SnackBar payload).
class TagMergeResult {
  const TagMergeResult({required this.merged, required this.actuallyNew});

  /// Full merged list to write back to frontmatter. Current first,
  /// then genuinely-new additions in their input order. Casing of
  /// existing tags is preserved (M786).
  final List<String> merged;

  /// Subset of `added` that wasn't already present (case-insensitive).
  /// Empty when the user re-typed only existing tags. Used by the
  /// SnackBar to report "Added N tag(s)" and the comma-joined echo.
  final List<String> actuallyNew;
}

/// Merge user-typed additions into the current tag list with the
/// legacy editor's semantics: case-insensitive dedup against existing
/// + within the addition list itself, preserving the order +
/// original casing of existing tags. Mirrors the legacy
/// `_addTags` inline merge loop.
TagMergeResult mergeTags({
  required List<String> current,
  required List<String> added,
}) {
  final merged = <String>[...current];
  final mergedLower = {for (final t in current) t.toLowerCase()};
  final actuallyNew = <String>[];
  for (final t in added) {
    final lower = t.toLowerCase();
    if (!mergedLower.contains(lower)) {
      merged.add(t);
      mergedLower.add(lower);
      actuallyNew.add(t);
    }
  }
  return TagMergeResult(merged: merged, actuallyNew: actuallyNew);
}

/// User-visible toast label for "Added N tag(s)" — singular only for
/// `n == 1`. Matches the project-wide plural-for-zero convention used
/// by `wordGoalLabel` (M1745) and `copiedCharsLabel` (M1737).
String addedTagsLabel(int n) {
  return n == 1 ? 'Added 1 tag' : 'Added $n tags';
}
