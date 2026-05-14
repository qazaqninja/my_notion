/// Round-trip tests for frontmatter mutations performed by the editor.
///
/// The contract: any mutation produces a Frontmatter that
/// `FrontmatterParser.serialise` → `parse` round-trips identically (same
/// key order, same scalar values).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/core/markdown/frontmatter_parser.dart';
import 'package:my_notion/features/vault/domain/entities/frontmatter.dart';
import 'package:my_notion/features/vault/domain/entities/frontmatter_entry.dart';
import 'package:my_notion/features/vault/domain/entities/page.dart';

void main() {
  group('frontmatter edit round-trip', () {
    test('edit a text field — keys stay in original order', () {
      final original = Frontmatter(entries: const [
        FrontmatterEntry(
            key: 'id',
            rawScalar: '01HX0V9R5N6E8L3P7Q8S9U2X4B',
            type: FrontmatterType.ulid,
            value: '01HX0V9R5N6E8L3P7Q8S9U2X4B'),
        FrontmatterEntry(
            key: 'title', rawScalar: 'Old', type: FrontmatterType.text, value: 'Old'),
        FrontmatterEntry(
            key: 'priority',
            rawScalar: 'P1',
            type: FrontmatterType.select,
            value: 'P1'),
      ]);

      final mutated = Frontmatter(entries: [
        for (final e in original.entries)
          if (e.key == 'title')
            e.copyWith(rawScalar: 'New title', value: 'New title')
          else
            e,
      ]);

      final raw = FrontmatterParser.serialise(
        ParsedMarkdown(frontmatter: mutated, body: ''),
      );
      final parsed = FrontmatterParser.parse(raw);
      expect(parsed.frontmatter.keys, equals(['id', 'title', 'priority']));
      expect(parsed.frontmatter.title, equals('New title'));
      expect(parsed.frontmatter.id, equals('01HX0V9R5N6E8L3P7Q8S9U2X4B'));
    });

    test('add a new field — appended last, preserves prior order', () {
      final original = Frontmatter(entries: const [
        FrontmatterEntry(
            key: 'id',
            rawScalar: '01HX0V9R5N6E8L3P7Q8S9U2X4B',
            type: FrontmatterType.ulid,
            value: '01HX0V9R5N6E8L3P7Q8S9U2X4B'),
        FrontmatterEntry(
            key: 'title',
            rawScalar: 'Hello',
            type: FrontmatterType.text,
            value: 'Hello'),
      ]);

      final next = Frontmatter(entries: [
        ...original.entries,
        const FrontmatterEntry(
            key: 'tags',
            rawScalar: '[a, b, c]',
            type: FrontmatterType.multi,
            value: ['a', 'b', 'c']),
      ]);

      final raw = FrontmatterParser.serialise(
        ParsedMarkdown(frontmatter: next, body: 'body\n'),
      );
      final parsed = FrontmatterParser.parse(raw);
      expect(parsed.frontmatter.keys, equals(['id', 'title', 'tags']));
      expect(parsed.frontmatter.get('tags'), equals(['a', 'b', 'c']));
      expect(parsed.body, equals('body\n'));
    });

    test('remove a field — others unchanged', () {
      final original = Frontmatter(entries: const [
        FrontmatterEntry(
            key: 'id',
            rawScalar: '01HX0V9R5N6E8L3P7Q8S9U2X4B',
            type: FrontmatterType.ulid,
            value: '01HX0V9R5N6E8L3P7Q8S9U2X4B'),
        FrontmatterEntry(
            key: 'title',
            rawScalar: 'Keep',
            type: FrontmatterType.text,
            value: 'Keep'),
        FrontmatterEntry(
            key: 'draft',
            rawScalar: 'true',
            type: FrontmatterType.checkbox,
            value: true),
      ]);

      final next = Frontmatter(entries: [
        for (final e in original.entries)
          if (e.key != 'draft') e,
      ]);

      final raw = FrontmatterParser.serialise(
        ParsedMarkdown(frontmatter: next, body: ''),
      );
      final parsed = FrontmatterParser.parse(raw);
      expect(parsed.frontmatter.keys, equals(['id', 'title']));
      expect(parsed.frontmatter.find('draft'), isNull);
    });

    test('checkbox toggle — rawScalar/value stay coherent', () {
      const e = FrontmatterEntry(
          key: 'done',
          rawScalar: 'false',
          type: FrontmatterType.checkbox,
          value: false);
      final flipped = e.copyWith(rawScalar: 'true', value: true);

      final fm = Frontmatter(entries: [flipped]);
      final raw =
          FrontmatterParser.serialise(ParsedMarkdown(frontmatter: fm, body: ''));
      final parsed = FrontmatterParser.parse(raw);
      expect(parsed.frontmatter.get('done'), isTrue);
    });

    test('number field — round-trips numeric type', () {
      final fm = Frontmatter(entries: const [
        FrontmatterEntry(
            key: 'count',
            rawScalar: '42',
            type: FrontmatterType.number,
            value: 42),
      ]);
      final raw =
          FrontmatterParser.serialise(ParsedMarkdown(frontmatter: fm, body: ''));
      final parsed = FrontmatterParser.parse(raw);
      expect(parsed.frontmatter.get('count'), equals(42));
    });
  });
}
