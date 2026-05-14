/// Backlinks + title resolution for the relations cache.
abstract class RelationsRepository {
  /// Look up a page's display title by ULID. Returns `null` if unknown.
  Future<String?> resolveTitle(String ulid);

  /// Backlinks for [toUlid] — every page whose body contains `[[toUlid]]`.
  /// Returns title + relativePath + a short snippet of the linking body.
  Future<List<Backlink>> backlinksFor(String toUlid);
}

class Backlink {
  const Backlink({
    required this.fromUlid,
    required this.title,
    required this.relativePath,
    required this.snippet,
  });

  final String fromUlid;
  final String title;
  final String relativePath;
  final String snippet;
}
