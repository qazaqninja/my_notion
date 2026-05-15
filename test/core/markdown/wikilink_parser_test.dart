import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/core/markdown/wikilink_parser.dart';

void main() {
  group('WikilinkParser.find', () {
    test('finds a single link', () {
      const body = 'See [[01HX0VEY5T6K7R9X4Y8Z0A3D4G]] for details.';
      final links = WikilinkParser.find(body);
      expect(links, hasLength(1));
      expect(links.first.ulid, '01HX0VEY5T6K7R9X4Y8Z0A3D4G');
      expect(links.first.start, 4);
      expect(links.first.end, 34);
    });

    test('finds multiple links', () {
      const body = 'A [[01HX0VEY5T6K7R9X4Y8Z0A3D4G]] and B [[01HX0VH3AW0N0V5C8C4F6H8K9L]] etc.';
      final links = WikilinkParser.find(body);
      expect(links.map((l) => l.ulid), [
        '01HX0VEY5T6K7R9X4Y8Z0A3D4G',
        '01HX0VH3AW0N0V5C8C4F6H8K9L',
      ]);
    });

    test('rejects bracketed non-ULID strings', () {
      const body = 'See [[not-a-ulid]] or [[CASE-4421]].';
      expect(WikilinkParser.find(body), isEmpty);
    });

    test('handles links across lines', () {
      const body = '''
Line one [[01HX0VEY5T6K7R9X4Y8Z0A3D4G]].
Line two [[01HX0VH3AW0N0V5C8C4F6H8K9L]].
''';
      expect(WikilinkParser.find(body), hasLength(2));
    });

    test('empty body returns empty list', () {
      expect(WikilinkParser.find(''), isEmpty);
    });

    test('rejects lowercase ULID strings', () {
      const body = '[[01hx0v9r5n6e8l3p7q8s9u2x4b]]';
      expect(WikilinkParser.find(body), isEmpty);
    });

    test('rejects 25-char strings inside [[ ]]', () {
      const body = '[[01HX0V9R5N6E8L3P7Q8S9U2X4]]';
      expect(WikilinkParser.find(body), isEmpty);
    });

    test('captures #anchor suffix without polluting the ulid (M778)', () {
      const body = 'See [[01HX0VEY5T6K7R9X4Y8Z0A3D4G#install]] for setup.';
      final links = WikilinkParser.find(body);
      expect(links, hasLength(1));
      expect(links.first.ulid, equals('01HX0VEY5T6K7R9X4Y8Z0A3D4G'),
          reason: 'ULID is the bare 26 chars, anchor stripped off');
      expect(links.first.anchor, equals('install'));
    });

    test('rejects ULID#ANCHOR in uppercase (anchors are slugified) (M778)',
        () {
      // The renderer slugifies anchors lowercase + `[a-z0-9\-]`, so
      // mixed-case anchors don't match. Without this guard the indexer
      // would over-recognise; the relation table would still resolve
      // (anchor is stripped) but cosmetically odd.
      const body = '[[01HX0VEY5T6K7R9X4Y8Z0A3D4G#Install]]';
      expect(WikilinkParser.find(body), isEmpty);
    });

    test('null anchor when no suffix present (M778)', () {
      const body = '[[01HX0VEY5T6K7R9X4Y8Z0A3D4G]]';
      final links = WikilinkParser.find(body);
      expect(links.first.anchor, isNull);
    });
  });
}
