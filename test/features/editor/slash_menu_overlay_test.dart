import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/editor/presentation/widgets/slash_menu_overlay.dart';

void main() {
  group('slash menu touch-tuning (M1680)', () {
    group('slashRowPaddingFor', () {
      test('mobile returns ≥12 vertical padding for ≥44pt touch target', () {
        final pad = slashRowPaddingFor(isMobile: true);
        expect(pad.vertical, greaterThanOrEqualTo(24));
        // 24 vertical + ~20 content (icon + text line height) ≥ 44.
        expect(pad.horizontal, greaterThanOrEqualTo(24));
      });

      test('desktop returns the current dense 7-vertical / 12-horizontal',
          () {
        final pad = slashRowPaddingFor(isMobile: false);
        expect(pad.vertical, 14);
        expect(pad.horizontal, 24);
      });
    });

    group('slashRowIconSizeFor', () {
      test('mobile returns a larger icon than desktop', () {
        expect(
          slashRowIconSizeFor(isMobile: true),
          greaterThan(slashRowIconSizeFor(isMobile: false)),
        );
      });

      test('desktop keeps the current 13', () {
        expect(slashRowIconSizeFor(isMobile: false), 13);
      });
    });

    group('slashRowLabelFontSizeFor', () {
      test('mobile returns a larger label font than desktop', () {
        expect(
          slashRowLabelFontSizeFor(isMobile: true),
          greaterThan(slashRowLabelFontSizeFor(isMobile: false)),
        );
      });

      test('desktop keeps the current 13', () {
        expect(slashRowLabelFontSizeFor(isMobile: false), 13);
      });
    });

    group('slashRowShowsKeyboardHint', () {
      test('false on mobile (no physical keyboard)', () {
        expect(slashRowShowsKeyboardHint(isMobile: true), isFalse);
      });

      test('true on desktop', () {
        expect(slashRowShowsKeyboardHint(isMobile: false), isTrue);
      });
    });
  });
}
