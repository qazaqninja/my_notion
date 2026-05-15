/// Strips a leading UTF-8 byte-order-mark (U+FEFF) from [s] when present.
///
/// Excel, Google Sheets, Numbers, and many Windows-native text editors
/// prepend a BOM to UTF-8 exports. Dart's `readAsString` returns the
/// BOM as a literal `﻿` character, which then poisons header
/// matching (`'﻿title' != 'title'`), YAML key generation
/// (yamlSnakeKey collapses the BOM glyph away but downstream string
/// comparisons may not), and any "starts with" prefix check.
///
/// `String.trim()` does **not** strip the BOM — U+FEFF isn't in Dart's
/// whitespace class — so importers that just `.trim()` headers leak
/// the marker through.
///
/// Cheap to call on every text-import payload.
String stripBom(String s) {
  if (s.isNotEmpty && s.codeUnitAt(0) == 0xFEFF) {
    return s.substring(1);
  }
  return s;
}
