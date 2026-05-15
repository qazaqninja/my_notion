import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/core/markdown/frontmatter_icon.dart';

/// Build the structured JSON shape that Indexer._upsertPage writes.
/// Tests previously used `{"icon":"🚀"}` (a flat shape that doesn't
/// exist in production — see M770) which masked the breakage.
String _fm(Map<String, dynamic> entries) {
  final list = [
    for (final e in entries.entries)
      {'key': e.key, 'rawScalar': '${e.value}', 'type': 'text'},
  ];
  return jsonEncode({'entries': list});
}

void main() {
  group('emojiFromFrontmatterJson', () {
    test('returns the emoji when set as `icon:` in frontmatter', () {
      expect(emojiFromFrontmatterJson(_fm({'icon': '🚀'})), '🚀');
    });

    test('returns null when json is empty', () {
      expect(emojiFromFrontmatterJson(''), isNull);
    });

    test('returns null when there is no icon field', () {
      expect(emojiFromFrontmatterJson(_fm({'title': 'X'})), isNull);
    });

    test('returns null for asset / URL icons', () {
      expect(emojiFromFrontmatterJson(_fm({'icon': 'assets/x.png'})),
          isNull);
      expect(
          emojiFromFrontmatterJson(_fm({'icon': 'folder/sub/img.png'})),
          isNull);
      expect(
          emojiFromFrontmatterJson(
              _fm({'icon': 'https://example.com/x.png'})),
          isNull);
      expect(emojiFromFrontmatterJson(_fm({'icon': 'http://x/y.png'})),
          isNull);
    });

    test('returns null for whitespace-only values', () {
      expect(emojiFromFrontmatterJson(_fm({'icon': '   '})), isNull);
    });

    test('returns null for malformed JSON', () {
      expect(emojiFromFrontmatterJson('{not json'), isNull);
    });

    test('returns null for legacy flat shape (regression check, M770)',
        () {
      // Older callers wrote `{"icon": "🚀"}` directly. The current
      // indexer never produces that shape; if we ever see it, the
      // helper should noop rather than appear to work.
      expect(emojiFromFrontmatterJson('{"icon":"🚀"}'), isNull);
    });

    test('trims surrounding whitespace from emoji values', () {
      expect(emojiFromFrontmatterJson(_fm({'icon': ' ☕ '})), '☕');
    });

    test('strips surrounding YAML quotes the parser preserves', () {
      // A user who writes `icon: "🚀"` in YAML has the quotes
      // captured verbatim as the rawScalar — the helper must peel
      // those before returning the bare glyph.
      expect(emojiFromFrontmatterJson(_fm({'icon': '"🚀"'})), '🚀');
    });
  });

  group('rawScalarFromFrontmatterJson', () {
    test('returns the rawScalar of the named entry', () {
      final json = _fm({'reminder': '2026-05-20'});
      expect(rawScalarFromFrontmatterJson(json, 'reminder'),
          equals('2026-05-20'));
    });

    test('returns null when the key is absent', () {
      final json = _fm({'reminder': '2026-05-20'});
      expect(rawScalarFromFrontmatterJson(json, 'missing'), isNull);
    });

    test('returns null on malformed JSON', () {
      expect(rawScalarFromFrontmatterJson('not json', 'k'), isNull);
    });

    test('returns null when json is empty', () {
      expect(rawScalarFromFrontmatterJson('', 'k'), isNull);
    });
  });

  group('listValueFromFrontmatterJson', () {
    test('parses a flow list of bare scalars', () {
      final json = _fm({'tags': '[draft, urgent]'});
      expect(listValueFromFrontmatterJson(json, 'tags'),
          equals(['draft', 'urgent']));
    });

    test('respects quoted commas in flow list items', () {
      final json = _fm({'tags': '[draft, "high, priority"]'});
      expect(listValueFromFrontmatterJson(json, 'tags'),
          equals(['draft', 'high, priority']));
    });

    test('wraps a single-scalar rawScalar as a one-element list', () {
      final json = _fm({'tags': 'urgent'});
      expect(listValueFromFrontmatterJson(json, 'tags'), equals(['urgent']));
    });

    test('strips surrounding quotes on single scalars', () {
      final json = _fm({'tags': '"urgent"'});
      expect(listValueFromFrontmatterJson(json, 'tags'), equals(['urgent']));
    });

    test('returns empty for empty flow list', () {
      final json = _fm({'tags': '[]'});
      expect(listValueFromFrontmatterJson(json, 'tags'), isEmpty);
    });

    test('returns empty when key is missing', () {
      final json = _fm({'title': 'Hello'});
      expect(listValueFromFrontmatterJson(json, 'tags'), isEmpty);
    });
  });

  group('hasNonEmptyFrontmatterValue', () {
    test('true for a present non-empty entry', () {
      expect(
          hasNonEmptyFrontmatterValue(_fm({'title': 'Hello'}), 'title'),
          isTrue);
    });

    test('false for whitespace-only', () {
      expect(
          hasNonEmptyFrontmatterValue(_fm({'title': '   '}), 'title'),
          isFalse);
    });

    test('false for double-quoted empty', () {
      // `title: ""` round-trips with the quotes, but trimmed it is empty.
      expect(hasNonEmptyFrontmatterValue(_fm({'title': '""'}), 'title'),
          isFalse);
    });

    test('false when key is absent', () {
      expect(hasNonEmptyFrontmatterValue(_fm({'id': 'X'}), 'title'),
          isFalse);
    });
  });
}
