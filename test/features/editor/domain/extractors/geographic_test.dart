// Tests for the geographic extractors in
// `lib/features/editor/domain/extractors/geographic.dart`.
//
// Pulled out of `selection_line_ops_test.dart` at M1184 to satisfy
// the FS-04 mirror rule once the lib `extractors/` directory was
// created at M1175. The functions are imported via the
// re-exporting `source_line_ops.dart` barrel — same surface as
// before, just relocated.

import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/editor/domain/source_line_ops.dart';

void main() {
  group('extractGeoCoordinatesFromLinesIn', () {
    test('positive lat + negative lon extracts (SF)', () {
      const text = 'meet at 37.7749,-122.4194 today\n';
      final r = extractGeoCoordinatesFromLinesIn(
          text, 0, text.length,);
      expect(r.text, '37.7749,-122.4194\n');
    });

    test('coords with whitespace after comma extract', () {
      const text = 'hub 51.5074, -0.1278 London center\n';
      final r = extractGeoCoordinatesFromLinesIn(
          text, 0, text.length,);
      expect(r.text, '51.5074, -0.1278\n');
    });

    test('both negative coords extract (southern + western)', () {
      const text = 'point -33.8688,-70.6483 santiago\n';
      final r = extractGeoCoordinatesFromLinesIn(
          text, 0, text.length,);
      expect(r.text, '-33.8688,-70.6483\n');
    });

    test('both positive coords extract', () {
      const text = 'eastern 35.6762,139.6503 tokyo\n';
      final r = extractGeoCoordinatesFromLinesIn(
          text, 0, text.length,);
      expect(r.text, '35.6762,139.6503\n');
    });

    test('integer pair NOT matched (no decimals)', () {
      // The regex requires a decimal fraction in both lat and
      // lon. Integer pairs are rejected as too ambiguous.
      const text = 'rough 37,-122 here\n';
      final r = extractGeoCoordinatesFromLinesIn(
          text, 0, text.length,);
      expect(r.text, '\n');
    });

    test('IPv4 127.0.0.1 NOT matched', () {
      // IPv4 has three dots and no comma; cannot match the
      // `lat.frac,lon.frac` template.
      const text = 'ip 127.0.0.1 here\n';
      final r = extractGeoCoordinatesFromLinesIn(
          text, 0, text.length,);
      expect(r.text, '\n');
    });

    test('embedded inside longer numeric run NOT matched', () {
      // `12345.6,7.89` — the lookbehind `(?<!\d)` blocks matches
      // that would start inside a longer numeric run; the leading
      // `123` has too many digits before the decimal.
      const text = 'long 12345.6,7.89 alone\n';
      final r = extractGeoCoordinatesFromLinesIn(
          text, 0, text.length,);
      expect(r.text, '\n');
    });

    test('multiple coord pairs on one line each extract', () {
      const text = 'route 40.7128,-74.0060 to 51.5074,-0.1278 OK\n';
      final r = extractGeoCoordinatesFromLinesIn(
          text, 0, text.length,);
      expect(r.text, '40.7128,-74.0060\n51.5074,-0.1278\n');
    });

    test('lines without coords dropped from output', () {
      const text = 'plain prose\nset 48.8566,2.3522 paris\nbye\n';
      final r = extractGeoCoordinatesFromLinesIn(
          text, 0, text.length,);
      expect(r.text, '48.8566,2.3522\n');
    });

    test('empty input stays empty', () {
      expect(extractGeoCoordinatesFromLinesIn('', 0, 0).text,
          '',);
    });
  });

  group('extractUkPostcodesFromLinesIn', () {
    test('royal postcode SW1A 1AA extracts', () {
      const text = 'palace SW1A 1AA address\n';
      final r = extractUkPostcodesFromLinesIn(
          text, 0, text.length,);
      expect(r.text, 'SW1A 1AA\n');
    });

    test('Manchester M1 1AE extracts (short outward)', () {
      const text = 'office M1 1AE today\n';
      final r = extractUkPostcodesFromLinesIn(
          text, 0, text.length,);
      expect(r.text, 'M1 1AE\n');
    });

    test('London EC1A 1BB extracts (A9A form)', () {
      const text = 'old EC1A 1BB site here\n';
      final r = extractUkPostcodesFromLinesIn(
          text, 0, text.length,);
      expect(r.text, 'EC1A 1BB\n');
    });

    test('Birmingham B33 8TH extracts (single-letter outward)', () {
      const text = 'midlands B33 8TH delivery\n';
      final r = extractUkPostcodesFromLinesIn(
          text, 0, text.length,);
      expect(r.text, 'B33 8TH\n');
    });

    test('South Croydon CR2 6XH extracts', () {
      const text = 'south CR2 6XH border\n';
      final r = extractUkPostcodesFromLinesIn(
          text, 0, text.length,);
      expect(r.text, 'CR2 6XH\n');
    });

    test('lowercase postcode rejected', () {
      // Royal Mail uses uppercase canonically; lowercase
      // strings would be normalised before printing.
      const text = 'shy sw1a 1aa here\n';
      final r = extractUkPostcodesFromLinesIn(
          text, 0, text.length,);
      expect(r.text, '\n');
    });

    test('missing space separator rejected', () {
      // Single space is the canonical separator. `SW1A1AA`
      // (no space) is not accepted.
      const text = 'nospace SW1A1AA invalid\n';
      final r = extractUkPostcodesFromLinesIn(
          text, 0, text.length,);
      expect(r.text, '\n');
    });

    test('wrong inward-code shape rejected', () {
      // `1A1` (digit-letter-digit) isn't a valid inward code.
      const text = 'fake SW1A 1A1 invalid\n';
      final r = extractUkPostcodesFromLinesIn(
          text, 0, text.length,);
      expect(r.text, '\n');
    });

    test('multiple postcodes on one line each extract', () {
      const text = 'send SW1A 1AA and EC1A 1BB both\n';
      final r = extractUkPostcodesFromLinesIn(
          text, 0, text.length,);
      expect(r.text, 'SW1A 1AA\nEC1A 1BB\n');
    });

    test('lines without postcodes dropped from output', () {
      const text = 'plain prose\noffice M1 1AE here\nbye\n';
      final r = extractUkPostcodesFromLinesIn(
          text, 0, text.length,);
      expect(r.text, 'M1 1AE\n');
    });

    test('empty input stays empty', () {
      expect(extractUkPostcodesFromLinesIn('', 0, 0).text, '');
    });
  });

  group('extractDmsCoordinatesFromLinesIn', () {
    test('classic NY DMS extracts', () {
      const text = "see 40°26'46\"N landmark\n";
      final r = extractDmsCoordinatesFromLinesIn(
          text, 0, text.length,);
      expect(r.text, "40°26'46\"N\n");
    });

    test('western longitude extracts', () {
      const text = "lon 74°00'21\"W today\n";
      final r = extractDmsCoordinatesFromLinesIn(
          text, 0, text.length,);
      expect(r.text, "74°00'21\"W\n");
    });

    test('decimal seconds extract', () {
      const text = "precise 40°26'46.5\"N here\n";
      final r = extractDmsCoordinatesFromLinesIn(
          text, 0, text.length,);
      expect(r.text, "40°26'46.5\"N\n");
    });

    test('southern hemisphere extracts', () {
      const text = "sydney 33°51'34\"S harbour\n";
      final r = extractDmsCoordinatesFromLinesIn(
          text, 0, text.length,);
      expect(r.text, "33°51'34\"S\n");
    });

    test('east longitude extracts', () {
      const text = "tokyo 139°41'30\"E here\n";
      final r = extractDmsCoordinatesFromLinesIn(
          text, 0, text.length,);
      expect(r.text, "139°41'30\"E\n");
    });

    test('ASCII-only workaround o NOT matched', () {
      // Unicode `°` (U+00B0) required; lookalike `o` is not.
      const text = "old 40o26'46\"N legacy\n";
      final r = extractDmsCoordinatesFromLinesIn(
          text, 0, text.length,);
      expect(r.text, '\n');
    });

    test('missing cardinal direction rejected', () {
      // `40°26'46"` without N/S/E/W is incomplete.
      const text = "incomplete 40°26'46\" alone\n";
      final r = extractDmsCoordinatesFromLinesIn(
          text, 0, text.length,);
      expect(r.text, '\n');
    });

    test('invalid cardinal like X rejected', () {
      // Only N/S/E/W are valid cardinals.
      const text = "fake 40°26'46\"X invalid\n";
      final r = extractDmsCoordinatesFromLinesIn(
          text, 0, text.length,);
      expect(r.text, '\n');
    });

    test('lat + lon pair on one line each extract', () {
      const text = "ny 40°26'46\"N 74°00'21\"W full\n";
      final r = extractDmsCoordinatesFromLinesIn(
          text, 0, text.length,);
      expect(r.text, "40°26'46\"N\n74°00'21\"W\n");
    });

    test('lines without DMS dropped from output', () {
      const text = "plain prose\nlat 40°26'46\"N here\nbye\n";
      final r = extractDmsCoordinatesFromLinesIn(
          text, 0, text.length,);
      expect(r.text, "40°26'46\"N\n");
    });

    test('empty input stays empty', () {
      expect(
          extractDmsCoordinatesFromLinesIn('', 0, 0).text, '',);
    });
  });
}
