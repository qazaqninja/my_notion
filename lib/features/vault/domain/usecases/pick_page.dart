// Pure-Dart pickers used by the command-palette navigation handlers
// (`Open largest / smallest / last-edited / most-linked page`). Lives
// in the domain layer so the decision logic is layer-correct and
// unit-testable without a widget tree — the M988 arch-audit flagged
// the accumulating CA-04 pattern (Drift queried directly in
// presentation), and this is the first migration that lifts the
// *decision* out of presentation while leaving the I/O (the
// `db.select(...).get()` call and the navigation) where it belongs.
//
// Records rather than entities here on purpose: callers map from
// the Drift `Page` row to the minimum subset of fields needed for
// the pick, and the pickers operate only on that subset. Keeps the
// usecase layer free of Drift imports without taking on the full
// entity-mapping surface — that's a follow-up if/when more
// presentation logic moves down here.

import 'dart:math' as math;

/// Minimum subset of page columns the navigation pickers need. The
/// `bodyText` field is the full markdown body — needed by the
/// open-todo and empty-page filters; pickers that only care about
/// `bodyLen` ignore it. Dart strings are by-reference internally so
/// the extra slot has negligible memory cost even on big vaults.
typedef PageRef = ({
  String ulid,
  String title,
  int bodyLen,
  int mtimeMs,
  List<String> tags,
  String bodyText,
});

/// Minimum subset of relation columns the most-linked picker needs.
typedef RelationRef = ({String fromUlid, String toUlid});

/// Filter to the pages whose `tags` list is empty. Pure-Dart so the
/// command-palette "Open random untagged page" entry can pick a
/// random element off the result without mixing concerns. Order is
/// preserved from the input.
List<PageRef> filterUntagged(List<PageRef> pages) =>
    [for (final p in pages) if (p.tags.isEmpty) p];

/// Top N pages by `bodyLen`, descending. Returns at most `n` items
/// in size-descending order; ties are broken by most-recent
/// `mtimeMs`. Powers the M987 "Show heaviest pages" hygiene dialog.
/// Negative or zero `n` returns empty; `n` larger than the page
/// count returns every page.
List<PageRef> topByBodyLen(List<PageRef> pages, int n) {
  if (n <= 0) return [];
  final sorted = [...pages]
    ..sort((a, b) {
      if (a.bodyLen != b.bodyLen) return b.bodyLen.compareTo(a.bodyLen);
      return b.mtimeMs.compareTo(a.mtimeMs);
    });
  return sorted.take(n).toList();
}

/// Top N pages by `mtimeMs`, descending (most-recently-edited
/// first). Same N-and-tie-break contract as [topByBodyLen]; ties on
/// mtimeMs are broken by ULID lex order for determinism.
List<PageRef> topByMtime(List<PageRef> pages, int n) {
  if (n <= 0) return [];
  final sorted = [...pages]
    ..sort((a, b) {
      if (a.mtimeMs != b.mtimeMs) return b.mtimeMs.compareTo(a.mtimeMs);
      return a.ulid.compareTo(b.ulid);
    });
  return sorted.take(n).toList();
}

/// Top N pages by inbound wikilink count, descending. Returns pages
/// with at least one inbound link; ties are broken by most-recent
/// `mtimeMs`. Powers the M988 "Show hub pages" dialog. Pages absent
/// from `relations` simply don't appear.
List<PageRef> topByBacklinkCount(
  List<PageRef> pages,
  List<RelationRef> relations,
  int n,
) {
  if (n <= 0) return [];
  final inbound = <String, int>{};
  for (final r in relations) {
    inbound[r.toUlid] = (inbound[r.toUlid] ?? 0) + 1;
  }
  final eligible = [
    for (final p in pages)
      if ((inbound[p.ulid] ?? 0) > 0) p,
  ];
  eligible.sort((a, b) {
    final ca = inbound[a.ulid] ?? 0;
    final cb = inbound[b.ulid] ?? 0;
    if (ca != cb) return cb.compareTo(ca);
    return b.mtimeMs.compareTo(a.mtimeMs);
  });
  return eligible.take(n).toList();
}

/// Pick one element at random from the list, using the supplied
/// [Random] source so the choice is deterministic in tests. Returns
/// `null` for an empty input. Callers in presentation typically
/// pass `math.Random(DateTime.now().microsecondsSinceEpoch.abs())`
/// for a fresh per-invocation seed.
PageRef? pickRandom(List<PageRef> pages, math.Random random) {
  if (pages.isEmpty) return null;
  return pages[random.nextInt(pages.length)];
}

/// Filter to pages whose title contains the query (case-insensitive
/// substring match, trimmed on both sides). Empty query returns
/// empty rather than wildcarding — same convention as
/// [filterByTag]. Order is preserved from the input.
List<PageRef> filterTitleContains(List<PageRef> pages, String query) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return [];
  return [
    for (final p in pages)
      if (p.title.toLowerCase().contains(needle)) p,
  ];
}

/// Look up a single page by exact title match, optionally
/// case-sensitive. Returns the first match (in input order) or
/// `null` when no page matches. The title comparison happens AFTER
/// trimming both sides — leading/trailing whitespace differences
/// don't fail the match. Useful for "Jump to page named X"
/// navigation features.
PageRef? pickByTitle(
  List<PageRef> pages,
  String title, {
  bool caseSensitive = false,
}) {
  final needle = title.trim();
  if (needle.isEmpty) return null;
  final foldedNeedle = caseSensitive ? needle : needle.toLowerCase();
  for (final p in pages) {
    final t = p.title.trim();
    final folded = caseSensitive ? t : t.toLowerCase();
    if (folded == foldedNeedle) return p;
  }
  return null;
}

/// Look up a single page by ULID, returning `null` when no match.
/// Linear scan — fine for vault sizes Quill targets (a few thousand
/// pages max); callers that need O(1) lookup over a hot loop should
/// build a `{for (p in pages) p.ulid: p}` map themselves.
PageRef? pickByUlid(List<PageRef> pages, String ulid) {
  for (final p in pages) {
    if (p.ulid == ulid) return p;
  }
  return null;
}

/// Count occurrences of each tag across the page set, returning a
/// frequency map keyed by the trimmed-non-empty raw tag string
/// (case preserved — callers that want case-folded counts can
/// lowercase the keys themselves). Empty / whitespace-only tag
/// entries are skipped so a stray `tags: ['  ']` doesn't pollute
/// the output. Mirrors the inline computation `_showVaultStats`
/// does today.
Map<String, int> countTagFrequency(List<PageRef> pages) {
  final counts = <String, int>{};
  for (final p in pages) {
    for (final t in p.tags) {
      final s = t.trim();
      if (s.isEmpty) continue;
      counts[s] = (counts[s] ?? 0) + 1;
    }
  }
  return counts;
}

/// Filter to the pages that carry the given tag (case-insensitive
/// match against entries in their `tags` list). Tag whitespace is
/// trimmed on both sides before comparison — matches the convention
/// used by `_showVaultStats`' frequency map. Empty `tag` argument
/// returns an empty list (a wildcard query would invite confusion
/// with `filterUntagged`'s inverse).
List<PageRef> filterByTag(List<PageRef> pages, String tag) {
  final needle = tag.trim().toLowerCase();
  if (needle.isEmpty) return [];
  return [
    for (final p in pages)
      if (p.tags.any((t) => t.trim().toLowerCase() == needle)) p,
  ];
}

/// Filter to the pages with no inbound AND no outbound wikilinks —
/// the "orphan" set the M988 / dialog hygiene entry surfaces. Order
/// is preserved from the input; callers typically sort by
/// most-recent-edit afterward.
List<PageRef> filterOrphan(
  List<PageRef> pages,
  List<RelationRef> relations,
) {
  final linked = <String>{};
  for (final r in relations) {
    linked.add(r.fromUlid);
    linked.add(r.toUlid);
  }
  return [for (final p in pages) if (!linked.contains(p.ulid)) p];
}

/// Filter to the pages whose `mtimeMs` is older than the given
/// cutoff. Mirrors the "stale (90+ days)" hygiene entry: callers
/// pass `DateTime.now().subtract(...).millisecondsSinceEpoch` as the
/// cutoff and get back the candidates for archive / refresh review.
List<PageRef> filterStale(List<PageRef> pages, int cutoffMs) =>
    [for (final p in pages) if (p.mtimeMs < cutoffMs) p];

/// Filter to pages whose `bodyText.trim()` is empty — placeholder
/// pages that were created but never filled in. Distinct from
/// `filterOrphan` (no incoming/outgoing wikilinks) and from "no
/// title" (the title column is blank): an empty page has a title
/// and frontmatter but no body content.
List<PageRef> filterEmpty(List<PageRef> pages) =>
    [for (final p in pages) if (p.bodyText.trim().isEmpty) p];

/// Filter to pages that contain at least one GFM unchecked-todo
/// (`- [ ] ` / `* [ ] ` / `+ [ ] ` with optional leading indent)
/// anywhere in `bodyText`. Powers the M985 "Show pages with open
/// todos" hygiene entry and any future "what's on my plate"
/// surfaces.
List<PageRef> filterPagesWithOpenTodos(List<PageRef> pages) {
  final todoRe = RegExp(r'^[ \t]*[-*+] \[ \] ', multiLine: true);
  return [for (final p in pages) if (todoRe.hasMatch(p.bodyText)) p];
}

/// Group pages by case-folded title, return the flat list of pages
/// in buckets of 2+ entries. Within each bucket pages appear in
/// most-recently-edited-first order; the buckets themselves are
/// ordered alphabetically by title. Empty-title pages are skipped
/// (the "no title" hygiene entry already surfaces those, so
/// double-reporting would be noise).
List<PageRef> filterDuplicateTitles(List<PageRef> pages) {
  final byKey = <String, List<PageRef>>{};
  for (final p in pages) {
    final t = p.title.trim();
    if (t.isEmpty) continue;
    byKey.putIfAbsent(t.toLowerCase(), () => []).add(p);
  }
  final out = <PageRef>[];
  final keys = byKey.keys.where((k) => byKey[k]!.length >= 2).toList()
    ..sort();
  for (final k in keys) {
    final bucket = byKey[k]!
      ..sort((a, b) => b.mtimeMs.compareTo(a.mtimeMs));
    out.addAll(bucket);
  }
  return out;
}

/// Pick the page with the highest `bodyLen`. Returns `null` for an
/// empty input. Ties broken by most-recent `mtimeMs`.
PageRef? pickLargest(List<PageRef> pages) {
  if (pages.isEmpty) return null;
  return pages.reduce((a, b) {
    if (a.bodyLen != b.bodyLen) return a.bodyLen > b.bodyLen ? a : b;
    return a.mtimeMs > b.mtimeMs ? a : b;
  });
}

/// Pick the page with the lowest `bodyLen`. Returns `null` for an
/// empty input. Ties broken by most-recent `mtimeMs` — when the user
/// has multiple stub pages, the freshly-created one is the more
/// likely "fix this now" candidate than a long-abandoned one.
PageRef? pickSmallest(List<PageRef> pages) {
  if (pages.isEmpty) return null;
  return pages.reduce((a, b) {
    if (a.bodyLen != b.bodyLen) return a.bodyLen < b.bodyLen ? a : b;
    return a.mtimeMs > b.mtimeMs ? a : b;
  });
}

/// Pick the page with the highest `mtimeMs` (most recently edited).
/// Returns `null` for an empty input.
PageRef? pickLastEdited(List<PageRef> pages) {
  if (pages.isEmpty) return null;
  return pages.reduce((a, b) => a.mtimeMs > b.mtimeMs ? a : b);
}

/// Pick the page with the lowest `mtimeMs` (oldest — hasn't been
/// touched the longest). Returns `null` for an empty input. Mirror
/// of [pickLastEdited]; surfaces the same archive-or-refresh
/// candidate the M987 "stale (90+ days)" hygiene dialog browses,
/// but as a single-shot jump.
PageRef? pickOldest(List<PageRef> pages) {
  if (pages.isEmpty) return null;
  return pages.reduce((a, b) => a.mtimeMs < b.mtimeMs ? a : b);
}

/// Pick the page with the most inbound wikilinks, returning both the
/// page and the count so the caller can render `· N inbound links`
/// in a confirmation toast. Returns `null` when no page has any
/// inbound links (e.g. brand-new vault). Ties broken by most-recent
/// `mtimeMs`.
({PageRef ref, int inboundCount})? pickMostLinked(
  List<PageRef> pages,
  List<RelationRef> relations,
) {
  if (pages.isEmpty || relations.isEmpty) return null;
  final inbound = <String, int>{};
  for (final r in relations) {
    inbound[r.toUlid] = (inbound[r.toUlid] ?? 0) + 1;
  }
  final eligible = [
    for (final p in pages)
      if ((inbound[p.ulid] ?? 0) > 0) p,
  ];
  if (eligible.isEmpty) return null;
  final pick = eligible.reduce((a, b) {
    final ca = inbound[a.ulid] ?? 0;
    final cb = inbound[b.ulid] ?? 0;
    if (ca != cb) return ca > cb ? a : b;
    return a.mtimeMs > b.mtimeMs ? a : b;
  });
  return (ref: pick, inboundCount: inbound[pick.ulid]!);
}
