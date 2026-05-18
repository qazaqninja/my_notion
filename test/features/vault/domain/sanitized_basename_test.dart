import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/vault/domain/sanitized_basename.dart';

void main() {
  group('sanitizedBasename', () {
    test('passes a clean name through unchanged', () {
      expect(sanitizedBasename('my-note'), 'my-note');
    });

    test('strips a trailing .md (case-insensitive)', () {
      expect(sanitizedBasename('my-note.md'), 'my-note');
      expect(sanitizedBasename('Notes.MD'), 'Notes');
    });

    test('replaces filesystem-illegal chars with -', () {
      // \\ / < > : " | ? * are all stripped to a single `-` run.
      expect(sanitizedBasename('foo/bar:baz*?qux'), 'foo-bar-baz-qux');
    });

    test('collapses runs of whitespace to a single space', () {
      expect(
        sanitizedBasename('   hello     world   '),
        'hello world',
      );
    });

    test('returns "Untitled" when the result would be empty', () {
      expect(sanitizedBasename(''), 'Untitled');
      expect(sanitizedBasename('   '), 'Untitled');
      expect(sanitizedBasename('.md'), 'Untitled');
      expect(sanitizedBasename('///'), 'Untitled');
    });

    test('trims leading + trailing whitespace after sanitization', () {
      expect(sanitizedBasename('  hello  '), 'hello');
    });
  });
}
