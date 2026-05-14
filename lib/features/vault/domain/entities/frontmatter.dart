import 'frontmatter_entry.dart';

/// Ordered list of frontmatter entries — key order matters and is preserved
/// across reads/writes. NOT a Map; lookups walk the list.
class Frontmatter {
  const Frontmatter({required this.entries, this.rawYaml});

  /// Parsed entries in declared order.
  final List<FrontmatterEntry> entries;

  /// Verbatim YAML block (without the surrounding `---` lines). When set,
  /// serialisation re-emits this string unchanged. If null, serialiser
  /// regenerates from [entries].
  final String? rawYaml;

  static const Frontmatter empty = Frontmatter(entries: []);

  bool get isEmpty => entries.isEmpty;
  bool get isNotEmpty => entries.isNotEmpty;

  FrontmatterEntry? find(String key) {
    for (final e in entries) {
      if (e.key == key) return e;
    }
    return null;
  }

  Object? get(String key) => find(key)?.value;

  /// ULID — `id` field if present.
  String? get id {
    final v = get('id');
    return v is String ? v : null;
  }

  String? get title {
    final v = get('title');
    return v is String ? v : null;
  }

  List<String> get keys => entries.map((e) => e.key).toList(growable: false);

  Frontmatter withEntries(List<FrontmatterEntry> next) {
    // Editing invalidates the cached raw YAML; serialise will regenerate.
    return Frontmatter(entries: next);
  }
}
