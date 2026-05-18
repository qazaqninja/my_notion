import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/editor/domain/copy_labels.dart';

void main() {
  group('copiedCharsLabel', () {
    test('1 char uses singular "char"', () {
      expect(copiedCharsLabel(1), 'Copied 1 char to clipboard');
    });

    test('2+ chars uses plural "chars"', () {
      expect(copiedCharsLabel(2), 'Copied 2 chars to clipboard');
      expect(copiedCharsLabel(42), 'Copied 42 chars to clipboard');
    });

    test('0 chars uses plural "chars"', () {
      // Matches the legacy editor's behaviour — "0 char" reads as a
      // typo, so "0 chars" is the safer copy.
      expect(copiedCharsLabel(0), 'Copied 0 chars to clipboard');
    });

    test('preserves the integer formatting (no thousands separator)', () {
      // Just confirms the string template doesn't pull a NumberFormat.
      expect(copiedCharsLabel(12345), 'Copied 12345 chars to clipboard');
    });
  });
}
