import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/vault/data/opml_to_markdown.dart';

void main() {
  group('OpmlToMarkdown.convert', () {
    test('flat outlines become bulleted list', () {
      const opml = '''
<opml><body>
  <outline text="one"/>
  <outline text="two"/>
  <outline text="three"/>
</body></opml>
''';
      final out = OpmlToMarkdown.convert(opml);
      expect(out, '- one\n- two\n- three');
    });

    test('nesting → two-space indent per level', () {
      const opml = '''
<opml><body>
  <outline text="parent">
    <outline text="child">
      <outline text="grandchild"/>
    </outline>
    <outline text="sibling"/>
  </outline>
</body></opml>
''';
      final out = OpmlToMarkdown.convert(opml);
      expect(
        out,
        '- parent\n  - child\n    - grandchild\n  - sibling',
      );
    });

    test('_note attribute lands on the next line indented', () {
      const opml = '''
<opml><body>
  <outline text="parent" _note="extra context"/>
</body></opml>
''';
      final out = OpmlToMarkdown.convert(opml);
      // Note aligns under the bullet text (2 spaces past the `-`).
      expect(out, '- parent\n  extra context');
    });

    test('entity decoding', () {
      const opml = '''
<opml><body>
  <outline text="a &amp; b &lt; c"/>
</body></opml>
''';
      expect(OpmlToMarkdown.convert(opml), '- a & b < c');
    });

    test('missing body returns empty', () {
      expect(OpmlToMarkdown.convert('<opml></opml>'), '');
    });

    test('single quotes on attributes', () {
      const opml = "<opml><body><outline text='hi'/></body></opml>";
      expect(OpmlToMarkdown.convert(opml), '- hi');
    });
  });

  group('OpmlToMarkdown.extractTitle', () {
    test('reads head title', () {
      const opml = '''
<opml><head><title>My Outline</title></head><body><outline text="x"/></body></opml>
''';
      expect(OpmlToMarkdown.extractTitle(opml), 'My Outline');
    });

    test('returns null when missing', () {
      expect(
        OpmlToMarkdown.extractTitle(
            '<opml><body><outline text="x"/></body></opml>'),
        isNull,
      );
    });
  });
}
