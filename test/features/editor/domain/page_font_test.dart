import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/editor/domain/page_font.dart';

void main() {
  group('pageFontLabel', () {
    test('sans → "sans-serif (default)"', () {
      expect(pageFontLabel('sans'), 'sans-serif (default)');
    });

    test('serif → "serif"', () {
      expect(pageFontLabel('serif'), 'serif');
    });

    test('mono → "monospace"', () {
      expect(pageFontLabel('mono'), 'monospace');
    });

    test('unknown value falls through to itself', () {
      expect(pageFontLabel('roboto-mono'), 'roboto-mono');
    });
  });

  group('pageFontActionFor', () {
    test('sans + no existing entry = noop (already default)', () {
      expect(
        pageFontActionFor(picked: 'sans', existing: null),
        PageFontAction.noop,
      );
    });

    test('sans + existing entry = remove (strip back to default)', () {
      expect(
        pageFontActionFor(picked: 'sans', existing: 'serif'),
        PageFontAction.remove,
      );
    });

    test('serif + no existing entry = add', () {
      expect(
        pageFontActionFor(picked: 'serif', existing: null),
        PageFontAction.add,
      );
    });

    test('serif + existing different entry = edit', () {
      expect(
        pageFontActionFor(picked: 'serif', existing: 'mono'),
        PageFontAction.edit,
      );
    });

    test('mono + existing matching entry = noop', () {
      expect(
        pageFontActionFor(picked: 'mono', existing: 'mono'),
        PageFontAction.noop,
      );
    });

    test('noop also when existing carries whitespace around the value', () {
      // The legacy handler trims rawScalar before comparing; the
      // planner does the same so a leading space in frontmatter
      // doesn't cause spurious edits.
      expect(
        pageFontActionFor(picked: 'serif', existing: '  serif  '),
        PageFontAction.noop,
      );
    });
  });
}
