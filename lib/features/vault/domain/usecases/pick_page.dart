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

/// Minimum subset of page columns the navigation pickers need.
typedef PageRef = ({
  String ulid,
  String title,
  int bodyLen,
  int mtimeMs,
  List<String> tags,
});

/// Minimum subset of relation columns the most-linked picker needs.
typedef RelationRef = ({String fromUlid, String toUlid});

/// Filter to the pages whose `tags` list is empty. Pure-Dart so the
/// command-palette "Open random untagged page" entry can pick a
/// random element off the result without mixing concerns. Order is
/// preserved from the input.
List<PageRef> filterUntagged(List<PageRef> pages) =>
    [for (final p in pages) if (p.tags.isEmpty) p];

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
