// Geographic / location extractors — pulled out of
// `source_line_ops.dart` at M1175 as the first step of the FS-02 split
// the M1155-M1168 audit scheduled. Each function preserves the same
// `(String text, int start, int end) -> SortLinesResult` contract as
// every other extraction-family member and is re-exported from
// `source_line_ops.dart` via the `export 'extractors/geographic.dart';`
// line so callers don't need to change their imports.
//
// Group rationale: decimal-degree coordinates, DMS coordinates, and
// UK postcodes all answer "where on Earth is this?" The shape of the
// regex differs but the doc-audit use case is the same. Tests live in
// `test/features/editor/selection_line_ops_test.dart` next to every
// other selection-range op test.

import '../source_line_ops.dart';

/// Extract every geo coordinate pair (`lat,lon` in decimal
/// degrees) from each selected line. Useful for travel-note
/// triage, field-trip planning, postmortem incident location
/// inventories, and field-report data scrapes.
///
/// Recognition: `(?<!\d)-?\d{1,3}\.\d+,\s*-?\d{1,3}\.\d+(?!\d)`
/// - Optional leading `-` for southern / western hemispheres.
/// - 1-3 digit integer degrees component (allows real lat in
///   -90..90 and lon in -180..180 to round-trip).
/// - Decimal point + decimal fraction (both lat and lon).
/// - Comma separator; optional whitespace after the comma is
///   accepted, e.g. `37.7749, -122.4194` matches.
/// - Lookarounds `(?<!\d)` and `(?!\d)` prevent the regex from
///   slicing inside longer numeric runs (so `12345.6,7.8` won't
///   yield `45.6,7.8` as a sub-match).
///
/// Whole-number coordinates without a decimal fraction (`37,
/// -122`) are NOT matched — the decimal-degrees convention
/// expects fractional precision and the requirement filters
/// out integer-pair false positives.
///
/// IP addresses (`127.0.0.1`) are not matched because the
/// dotted-quad shape can't fit into the `lat.frac,lon.frac`
/// template (only one comma is allowed, but an IP has three
/// dots and no comma).
///
/// 94th member of the extraction family.
SortLinesResult extractGeoCoordinatesFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(
        r'(?<!\d)-?\d{1,3}\.\d+,\s*-?\d{1,3}\.\d+(?!\d)',
      );
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(0)!);
        }
      }
      return out;
    });

/// Extract every UK postcode from each selected line. Useful
/// for address-list audits, location inventory in CRM notes,
/// and contact-info scrapes.
///
/// Recognition: `\b[A-Z]{1,2}\d[A-Z\d]?\s\d[A-Z]{2}\b`
/// - Outward code: 1-2 uppercase letters, 1 digit, optional
///   trailing letter or digit. Examples: `SW1A`, `M1`,
///   `EC1A`, `B33`.
/// - Single literal space separator.
/// - Inward code: 1 digit, 2 uppercase letters. Examples:
///   `1AA`, `1AE`, `8TH`.
///
/// Matches:
/// - `SW1A 1AA`     — Buckingham Palace area (royal)
/// - `M1 1AE`       — Manchester
/// - `EC1A 1BB`     — London (City)
/// - `B33 8TH`      — Birmingham
/// - `CR2 6XH`      — South Croydon
///
/// Case-sensitive (uppercase only) per Royal Mail's canonical
/// presentation. Lowercase strings would be normalised before
/// printing addresses. Single-space separator only —
/// hyphenated or no-separator forms are non-standard.
///
/// The pattern covers all real UK formats (A9, A9A, AA9, AA9A,
/// AA99) by the optional `[A-Z\d]?` in the outward code.
/// Validity against the Royal Mail's PAF database is NOT
/// checked — that's a downstream lookup beyond regex scope.
///
/// 106th member of the extraction family.
SortLinesResult extractUkPostcodesFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(r'\b[A-Z]{1,2}\d[A-Z\d]?\s\d[A-Z]{2}\b');
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(0)!);
        }
      }
      return out;
    });

/// Extract every DMS (degree-minute-second) coordinate from
/// each selected line. Useful for travel-note triage, surveyor
/// field-report scrapes, maritime / aviation log harvests, and
/// legacy GPS reference inventories.
///
/// Recognition:
/// `\b\d{1,3}°\d{1,2}'\d{1,2}(?:\.\d+)?"[NSEW]`
/// - 1-3 digit degrees, then literal `°` (degree sign).
/// - 1-2 digit minutes, then literal `'` (apostrophe).
/// - 1-2 digit seconds, optional decimal fraction, then literal
///   `"` (double quote).
/// - Cardinal direction: `N`, `S`, `E`, or `W`.
///
/// Matches:
/// - `40°26'46"N`           — classic NY-style
/// - `74°00'21"W`
/// - `40°26'46.5"N`         — with decimal seconds
/// - `33°51'34"S`           — southern hemisphere
///
/// Distinct from [extractGeoCoordinatesFromLinesIn] (M1158 —
/// decimal-degree form `lat,lon`). DMS uses the
/// degree-minute-second triple with explicit cardinal direction
/// instead of a sign.
///
/// Unicode degree sign `°` (U+00B0) is required. ASCII `o` and
/// asterisk `*` workarounds (`40o26'46"N`) are NOT matched.
/// Authorial notes should use the canonical Unicode symbols.
///
/// 109th member of the extraction family.
SortLinesResult extractDmsCoordinatesFromLinesIn(
        String text, int start, int end,) =>
    transformLinesIn(text, start, end, (lines) {
      final re = RegExp(
        r"""\b\d{1,3}°\d{1,2}'\d{1,2}(?:\.\d+)?"[NSEW]""",
      );
      final out = <String>[];
      for (final l in lines) {
        for (final m in re.allMatches(l)) {
          out.add(m.group(0)!);
        }
      }
      return out;
    });
