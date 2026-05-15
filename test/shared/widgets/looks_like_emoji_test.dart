import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/shared/widgets/emoji_picker.dart';

void main() {
  group('looksLikeEmoji', () {
    test('plain BMP emojis', () {
      expect(looksLikeEmoji('📊'), isTrue);
      expect(looksLikeEmoji('🚀'), isTrue);
      expect(looksLikeEmoji('☕'), isTrue);
      expect(looksLikeEmoji('🙂'), isTrue);
    });

    test('ZWJ sequences (composite emojis)', () {
      expect(looksLikeEmoji('👨‍💻'), isTrue);
      expect(looksLikeEmoji('🏳️‍🌈'), isTrue);
    });

    test('rejects empty string', () {
      expect(looksLikeEmoji(''), isFalse);
    });

    test('rejects ASCII text', () {
      expect(looksLikeEmoji('D'), isFalse);
      expect(looksLikeEmoji('foo'), isFalse);
      expect(looksLikeEmoji('123'), isFalse);
      expect(looksLikeEmoji(' '), isFalse);
    });

    test('rejects very long inputs', () {
      expect(
          looksLikeEmoji(
              '\u{1F600}\u{1F601}\u{1F602}\u{1F603}\u{1F604}\u{1F605}\u{1F606}\u{1F607}\u{1F608}'),
          isFalse);
    });
  });
}
