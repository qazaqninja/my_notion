import '../../features/vault/domain/entities/frontmatter_entry.dart';

/// Pure functions for inferring a [FrontmatterType] from a parsed Dart value.
/// Database `.database.yaml` schemas refine these (e.g. mark a string as
/// `select` against a known options list) — see `features/database`.
class TypeInference {
  const TypeInference._();

  // Relaxed Crockford — the design fixtures use the full A-Z range; the
  // `ulid` package generator stays inside Crockford's subset.
  static final _ulidRe = RegExp(r'^[0-9A-Z]{26}$');
  static final _dateRe = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  /// Most specific type that fits the value.
  static FrontmatterType infer(Object? value) {
    if (value is bool) return FrontmatterType.checkbox;
    if (value is num) return FrontmatterType.number;
    if (value is List) return FrontmatterType.multi;
    if (value is String) {
      if (_ulidRe.hasMatch(value)) return FrontmatterType.ulid;
      if (_dateRe.hasMatch(value)) return FrontmatterType.date;
      return FrontmatterType.text;
    }
    return FrontmatterType.text;
  }

  static bool isUlid(String s) => _ulidRe.hasMatch(s);
  static bool isDate(String s) => _dateRe.hasMatch(s);
}
