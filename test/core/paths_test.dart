import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/core/paths.dart';

void main() {
  group('stripMdExtension', () {
    test('drops trailing .md', () {
      expect(stripMdExtension('Inbox/Foo.md'), 'Inbox/Foo');
      expect(stripMdExtension('a.md'), 'a');
    });

    test('leaves non-md paths unchanged', () {
      expect(stripMdExtension('Inbox/Foo'), 'Inbox/Foo');
      expect(stripMdExtension('a.txt'), 'a.txt');
      expect(stripMdExtension(''), '');
    });

    test('only strips a single trailing .md, not embedded', () {
      expect(stripMdExtension('foo.md/bar.md'), 'foo.md/bar');
    });
  });
}
