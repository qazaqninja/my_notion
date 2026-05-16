// Tests for the bibliographic extractors in
// `lib/features/editor/domain/extractors/bibliographic.dart`.
//
// Pulled out of `selection_line_ops_test.dart` at M1185 to satisfy
// the FS-04 mirror rule. The functions are imported via the
// re-exporting `source_line_ops.dart` barrel — same surface as
// before, just relocated.

import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/editor/domain/source_line_ops.dart';

void main() {
  group('extractIsbn13FromLinesIn', () {
    test('bare ISBN-13 extracts', () {
      const text = 'book ISBN 9783161484100 today\n';
      final r = extractIsbn13FromLinesIn(text, 0, text.length);
      expect(r.text, '9783161484100\n');
    });

    test('hyphenated ISBN-13 extracts intact', () {
      const text = 'see 978-3-16-148410-0 cover\n';
      final r = extractIsbn13FromLinesIn(text, 0, text.length);
      expect(r.text, '978-3-16-148410-0\n');
    });

    test('space-separated ISBN-13 extracts intact', () {
      const text = 'book 978 3 16 148410 0 form\n';
      final r = extractIsbn13FromLinesIn(text, 0, text.length);
      expect(r.text, '978 3 16 148410 0\n');
    });

    test('GS1 prefix 979 (music) extracts', () {
      const text = 'music ISBN 9790123456789 logged\n';
      final r = extractIsbn13FromLinesIn(text, 0, text.length);
      expect(r.text, '9790123456789\n');
    });

    test('invalid prefix `980` is NOT an ISBN-13', () {
      // Only 978/979 are valid GS1 ISBN-13 namespaces.
      const text = 'fake 9803161484100 invalid\n';
      final r = extractIsbn13FromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('too short (12 digits) is NOT a match', () {
      const text = 'short 978316148410 only\n';
      final r = extractIsbn13FromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('ISBN-10 form (10 digits, no `978`) is NOT matched', () {
      // Out of scope for the ISBN-13 regex. See the ISBN-10
      // extractor (which lives next to ISBN-13 in the same
      // bibliographic sub-file) for that surface.
      const text = 'legacy 0306406152 inline\n';
      final r = extractIsbn13FromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('multiple ISBN-13s on one line each extract', () {
      const text = 'pair 9783161484100 and 9781234567897 listed\n';
      final r = extractIsbn13FromLinesIn(text, 0, text.length);
      expect(r.text, '9783161484100\n9781234567897\n');
    });

    test('lines without ISBNs dropped from output', () {
      const text = 'plain prose\ncite 9783161484100\nmore prose\n';
      final r = extractIsbn13FromLinesIn(text, 0, text.length);
      expect(r.text, '9783161484100\n');
    });

    test('empty input stays empty', () {
      expect(extractIsbn13FromLinesIn('', 0, 0).text, '');
    });
  });

  group('extractDoisFromLinesIn', () {
    test('classic Nature DOI extracts', () {
      const text = 'cite 10.1038/nature12373 today\n';
      final r = extractDoisFromLinesIn(text, 0, text.length);
      expect(r.text, '10.1038/nature12373\n');
    });

    test('ACM DOI with dot in suffix extracts', () {
      const text = 'ref 10.1145/3236024.3236084 here\n';
      final r = extractDoisFromLinesIn(text, 0, text.length);
      expect(r.text, '10.1145/3236024.3236084\n');
    });

    test('arXiv DOI extracts', () {
      const text = 'paper 10.48550/arXiv.2305.13245 wrap\n';
      final r = extractDoisFromLinesIn(text, 0, text.length);
      expect(r.text, '10.48550/arXiv.2305.13245\n');
    });

    test('IEEE DOI extracts', () {
      const text = 'see 10.1109/TIT.2006.871582 paper\n';
      final r = extractDoisFromLinesIn(text, 0, text.length);
      expect(r.text, '10.1109/TIT.2006.871582\n');
    });

    test('DOI inside parens captured up to closing paren', () {
      // The suffix excludes `)` so a trailing paren bounds
      // the match cleanly.
      const text = 'cite (10.1145/3236024.3236084) here\n';
      final r = extractDoisFromLinesIn(text, 0, text.length);
      expect(r.text, '10.1145/3236024.3236084\n');
    });

    test('not-a-DOI 11.xxxx rejected', () {
      // Only `10.` namespace is registered.
      const text = 'fake 11.1234/something not real\n';
      final r = extractDoisFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('registrant code too short rejected', () {
      // Need at least 4 digits after `10.`. `10.123/foo` has 3.
      const text = 'short 10.123/foo ignore\n';
      final r = extractDoisFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('missing suffix rejected', () {
      // No `/suffix` means no DOI — `10.1234` alone is not a
      // complete identifier.
      const text = 'incomplete 10.1234 alone\n';
      final r = extractDoisFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('multiple DOIs on one line each extract', () {
      const text = 'cite 10.1038/foo and 10.1145/bar today\n';
      final r = extractDoisFromLinesIn(text, 0, text.length);
      expect(r.text, '10.1038/foo\n10.1145/bar\n');
    });

    test('lines without DOIs dropped from output', () {
      const text = 'plain prose\nref 10.1038/abc\nbye\n';
      final r = extractDoisFromLinesIn(text, 0, text.length);
      expect(r.text, '10.1038/abc\n');
    });

    test('empty input stays empty', () {
      expect(extractDoisFromLinesIn('', 0, 0).text, '');
    });
  });

  group('extractIsbn10FromLinesIn', () {
    test('classic hyphenated ISBN-10 extracts', () {
      const text = 'book 0-306-40615-2 today\n';
      final r = extractIsbn10FromLinesIn(text, 0, text.length);
      expect(r.text, '0-306-40615-2\n');
    });

    test('hyphenated with X check digit extracts', () {
      const text = 'see 7-803-44132-X reference\n';
      final r = extractIsbn10FromLinesIn(text, 0, text.length);
      expect(r.text, '7-803-44132-X\n');
    });

    test('bare 10-char form with X check extracts', () {
      const text = 'index 030640615X library\n';
      final r = extractIsbn10FromLinesIn(text, 0, text.length);
      expect(r.text, '030640615X\n');
    });

    test('bare 10 digits NOT matched (too ambiguous)', () {
      // `0306406152` is a valid ISBN-10 but visually
      // indistinguishable from any 10-digit number.
      const text = 'isbn 0306406152 bare\n';
      final r = extractIsbn10FromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('plain hyphenated 1-2-3-4 NOT matched', () {
      // The post-match digit-count check requires exactly 10
      // digit-equivalents; `1-2-3-4` has only 4.
      const text = 'fake 1-2-3-4 not an ISBN\n';
      final r = extractIsbn10FromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('date 2025-12-01 NOT matched', () {
      // Date format doesn't satisfy 10 digit-equivalents.
      const text = 'on 2025-12-01 today\n';
      final r = extractIsbn10FromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('ISBN-13 form NOT matched here', () {
      // 13-digit form has 13 digit positions, not 10.
      const text = 'iso 978-0-13-468599-1 modern\n';
      final r = extractIsbn10FromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('multiple ISBNs on one line each extract', () {
      const text = 'cite 0-306-40615-2 and 1-56619-909-3 books\n';
      final r = extractIsbn10FromLinesIn(text, 0, text.length);
      expect(r.text, '0-306-40615-2\n1-56619-909-3\n');
    });

    test('lines without ISBNs dropped from output', () {
      const text = 'plain prose\nref 0-306-40615-2 here\nbye\n';
      final r = extractIsbn10FromLinesIn(text, 0, text.length);
      expect(r.text, '0-306-40615-2\n');
    });

    test('empty input stays empty', () {
      expect(extractIsbn10FromLinesIn('', 0, 0).text, '');
    });
  });

  group('extractIssnFromLinesIn', () {
    test('Nature ISSN 0028-0836 extracts', () {
      const text = 'cite 0028-0836 Nature journal\n';
      final r = extractIssnFromLinesIn(text, 0, text.length);
      expect(r.text, '0028-0836\n');
    });

    test('JSC ISSN 1469-5448 extracts', () {
      const text = 'ref 1469-5448 science comm\n';
      final r = extractIssnFromLinesIn(text, 0, text.length);
      expect(r.text, '1469-5448\n');
    });

    test('Library Hi Tech ISSN extracts', () {
      const text = 'see 0024-9319 today\n';
      final r = extractIssnFromLinesIn(text, 0, text.length);
      expect(r.text, '0024-9319\n');
    });

    test('X check digit ISSN extracts', () {
      const text = 'cite 2049-632X published\n';
      final r = extractIssnFromLinesIn(text, 0, text.length);
      expect(r.text, '2049-632X\n');
    });

    test('wrong shape NNN-NNNNN rejected', () {
      // ISSN is strictly 4-3-1. `123-45678` is 3-5 form.
      const text = 'fake 123-45678 not ISSN\n';
      final r = extractIssnFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('NNNNN-NNN form rejected', () {
      // 5-3 form is not ISSN.
      const text = 'wrong 12345-678 ignored\n';
      final r = extractIssnFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('embedded in longer numeric run rejected', () {
      // The lookbehind `(?<!\d)` prevents matches that
      // would start inside a longer digit run.
      const text = 'long 12345-6789 here\n';
      final r = extractIssnFromLinesIn(text, 0, text.length);
      expect(r.text, '\n');
    });

    test('multiple ISSNs on one line each extract', () {
      const text = 'cite 0028-0836 and 1469-5448 both\n';
      final r = extractIssnFromLinesIn(text, 0, text.length);
      expect(r.text, '0028-0836\n1469-5448\n');
    });

    test('lines without ISSNs dropped from output', () {
      const text = 'plain prose\nref 0024-9319 here\nbye\n';
      final r = extractIssnFromLinesIn(text, 0, text.length);
      expect(r.text, '0024-9319\n');
    });

    test('empty input stays empty', () {
      expect(extractIssnFromLinesIn('', 0, 0).text, '');
    });
  });
}
