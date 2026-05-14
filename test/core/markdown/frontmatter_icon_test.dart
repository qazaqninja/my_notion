import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/core/markdown/frontmatter_icon.dart';

void main() {
  group('emojiFromFrontmatterJson', () {
    test('returns the emoji when set as `icon:` in frontmatter', () {
      expect(emojiFromFrontmatterJson('{"icon":"🚀"}'), '🚀');
    });

    test('returns null when json is empty', () {
      expect(emojiFromFrontmatterJson(''), isNull);
    });

    test('returns null when there is no icon field', () {
      expect(emojiFromFrontmatterJson('{"title":"X"}'), isNull);
    });

    test('returns null for asset / URL icons', () {
      expect(emojiFromFrontmatterJson('{"icon":"assets/x.png"}'), isNull);
      expect(emojiFromFrontmatterJson('{"icon":"folder/sub/img.png"}'),
          isNull);
      expect(
          emojiFromFrontmatterJson('{"icon":"https://example.com/x.png"}'),
          isNull);
      expect(emojiFromFrontmatterJson('{"icon":"http://x/y.png"}'), isNull);
    });

    test('returns null for whitespace-only values', () {
      expect(emojiFromFrontmatterJson('{"icon":"   "}'), isNull);
    });

    test('returns null for malformed JSON', () {
      expect(emojiFromFrontmatterJson('{not json'), isNull);
    });

    test('returns null when icon is not a string', () {
      expect(emojiFromFrontmatterJson('{"icon": 42}'), isNull);
      expect(emojiFromFrontmatterJson('{"icon": null}'), isNull);
    });

    test('trims surrounding whitespace from emoji values', () {
      expect(emojiFromFrontmatterJson('{"icon":" ☕ "}'), '☕');
    });
  });
}
