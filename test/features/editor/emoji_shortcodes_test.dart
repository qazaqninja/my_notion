import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/editor/domain/emoji_shortcodes.dart';

void main() {
  group('replaceEmojiShortcodes', () {
    test('replaces a known shortcode', () {
      expect(replaceEmojiShortcodes('hello :tada:'), 'hello 🎉');
    });

    test('replaces multiple shortcodes in the same string', () {
      expect(
        replaceEmojiShortcodes('shipping :rocket: with :fire: tests :100:'),
        'shipping 🚀 with 🔥 tests 💯',
      );
    });

    test('leaves unknown shortcodes unchanged', () {
      expect(
        replaceEmojiShortcodes(':not_an_emoji: stays as text'),
        ':not_an_emoji: stays as text',
      );
    });

    test('leaves YAML-style key:value alone (no `:` pair)', () {
      expect(
        replaceEmojiShortcodes('title: My Page'),
        'title: My Page',
      );
    });

    test('replaces +1 and -1 alias shortcodes', () {
      expect(replaceEmojiShortcodes(':+1: :-1:'), '👍 👎');
    });

    test('empty input is a no-op', () {
      expect(replaceEmojiShortcodes(''), '');
    });

    test('multi-word emoji names work (heart_eyes)', () {
      expect(replaceEmojiShortcodes(':heart_eyes:'), '😍');
    });

    test('mid-line shortcodes are replaced', () {
      expect(
        replaceEmojiShortcodes('Released :sparkles:! Now go ship.'),
        'Released ✨! Now go ship.',
      );
    });

    test('a non-shortcode colon string is preserved', () {
      // The renderer must not eat `[footnote]: https://…` shapes.
      const text = '[ref]: https://example.com';
      expect(replaceEmojiShortcodes(text), text);
    });
  });
}
