import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/vault/data/roam_to_markdown.dart';

void main() {
  group('RoamToMarkdown.convert', () {
    test('single page with flat children → H1 + bullets', () {
      const json = '''[
  {"title": "Notes", "children": [
    {"string": "first"},
    {"string": "second"}
  ]}
]''';
      final pages = RoamToMarkdown.convert(json);
      expect(pages, hasLength(1));
      expect(pages.first.title, 'Notes');
      expect(pages.first.body, contains('# Notes'));
      expect(pages.first.body, contains('- first'));
      expect(pages.first.body, contains('- second'));
    });

    test('nested children → two-space indent per level', () {
      const json = '''[
  {"title": "Plan", "children": [
    {"string": "parent", "children": [
      {"string": "child", "children": [
        {"string": "grandchild"}
      ]}
    ]}
  ]}
]''';
      final pages = RoamToMarkdown.convert(json);
      final body = pages.single.body;
      expect(body, contains('- parent'));
      expect(body, contains('  - child'));
      expect(body, contains('    - grandchild'));
    });

    test('create-time → createdAtMs', () {
      const json =
          '[{"title":"X","create-time": 1700000000000,"children":[]}]';
      final p = RoamToMarkdown.convert(json).single;
      expect(p.createdAtMs, 1700000000000);
    });

    test('multiple top-level pages → multiple summaries', () {
      const json = '''[
  {"title": "A", "children": [{"string":"a"}]},
  {"title": "B", "children": [{"string":"b"}]}
]''';
      expect(RoamToMarkdown.convert(json).map((p) => p.title), ['A', 'B']);
    });

    test('empty bullet strings are skipped', () {
      const json = '''[
  {"title": "X", "children": [
    {"string": ""},
    {"string": "kept"},
    {"string": "   "}
  ]}
]''';
      final body = RoamToMarkdown.convert(json).single.body;
      expect(body, contains('- kept'));
      // Only one bullet should be present.
      expect('-'.allMatches(body).length, 1);
    });

    test('malformed JSON → empty list', () {
      expect(RoamToMarkdown.convert('not json'), isEmpty);
      expect(RoamToMarkdown.convert(''), isEmpty);
    });

    test('top-level non-list → empty', () {
      expect(RoamToMarkdown.convert('{"title": "X"}'), isEmpty);
    });

    test('pages without title are skipped', () {
      const json = '[{"children": [{"string": "x"}]}, {"title": "real"}]';
      final out = RoamToMarkdown.convert(json);
      expect(out.map((p) => p.title), ['real']);
    });
  });
}
