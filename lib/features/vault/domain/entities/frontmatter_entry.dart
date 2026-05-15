import 'package:meta/meta.dart';

/// Display-level type of a frontmatter value, inferred from the raw YAML
/// scalar shape (and refined by `.database.yaml` schemas later).
enum FrontmatterType {
  ulid,
  text,
  number,
  date,
  select,
  multi,
  relation,
  checkbox,
  formula,
  file,
}

/// One entry in a frontmatter block. [rawScalar] is preserved exactly as it
/// appeared in YAML so re-serialisation can be byte-identical for unedited
/// pages. [value] is the parsed Dart value (String, num, bool, List, etc.).
@immutable
class FrontmatterEntry {
  const FrontmatterEntry({
    required this.key,
    required this.rawScalar,
    required this.type,
    required this.value,
  });

  final String key;
  final String rawScalar;
  final FrontmatterType type;
  final Object? value;

  FrontmatterEntry copyWith({String? key, String? rawScalar, FrontmatterType? type, Object? value}) {
    return FrontmatterEntry(
      key: key ?? this.key,
      rawScalar: rawScalar ?? this.rawScalar,
      type: type ?? this.type,
      value: value ?? this.value,
    );
  }

  @override
  String toString() => 'FrontmatterEntry($key: $rawScalar [$type])';

  @override
  bool operator ==(Object other) =>
      other is FrontmatterEntry &&
      other.key == key &&
      other.rawScalar == rawScalar &&
      other.type == type;

  @override
  int get hashCode => Object.hash(key, rawScalar, type);
}
