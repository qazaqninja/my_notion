import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/core/markdown/frontmatter_parser.dart';

void main() {
  group('FrontmatterParser', () {
    test('round-trips Northwind fixture byte-identical', () {
      final raw = File('fixtures/northwind.md').readAsStringSync();
      final parsed = FrontmatterParser.parse(raw);
      final serialised = FrontmatterParser.serialise(parsed);
      expect(serialised, equals(raw));
    });

    test('reads frontmatter values in declared order', () {
      final raw = File('fixtures/northwind.md').readAsStringSync();
      final parsed = FrontmatterParser.parse(raw);
      expect(
        parsed.frontmatter.entries.map((e) => e.key).toList(),
        equals(['id', 'title', 'stage', 'arr', 'owner', 'health', 'tags', 'updated']),
      );
    });

    test('preserves body verbatim', () {
      final raw = File('fixtures/northwind.md').readAsStringSync();
      final parsed = FrontmatterParser.parse(raw);
      expect(parsed.body, contains('# Northwind'));
      expect(parsed.body, contains('```bash'));
      expect(parsed.body, contains('\$ ops report --account northwind'));
    });

    test('returns empty frontmatter for files without a YAML block', () {
      const raw = '# Just a title\n\nSome body.\n';
      final parsed = FrontmatterParser.parse(raw);
      expect(parsed.frontmatter.entries, isEmpty);
      expect(parsed.body, equals(raw));
    });

    test('serialise without YAML block emits body only', () {
      const raw = '# Just a title\n\nSome body.\n';
      final parsed = FrontmatterParser.parse(raw);
      expect(FrontmatterParser.serialise(parsed), equals(raw));
    });

    test('extracts id (ULID) as the page identifier when present', () {
      final raw = File('fixtures/northwind.md').readAsStringSync();
      final parsed = FrontmatterParser.parse(raw);
      expect(parsed.frontmatter.id, equals('01HX0V9R5N6E8L3P7Q8S9U2X4B'));
    });

    test('extracts title from frontmatter', () {
      final raw = File('fixtures/northwind.md').readAsStringSync();
      final parsed = FrontmatterParser.parse(raw);
      expect(parsed.frontmatter.title, equals('Northwind'));
    });
  });
}
