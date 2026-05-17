import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/editor/presentation/widgets/properties_panel.dart';

void main() {
  group('properties panel touch-tuning (M1682)', () {
    group('propertiesRowPaddingFor', () {
      test('mobile returns ≥14 vertical padding for ≥44pt touch target',
          () {
        final pad = propertiesRowPaddingFor(isMobile: true);
        // 14v on each side + ~16 content row = 44pt.
        expect(pad.vertical, greaterThanOrEqualTo(28));
      });

      test('desktop returns the current dense 4-vertical', () {
        final pad = propertiesRowPaddingFor(isMobile: false);
        expect(pad.vertical, 8);
      });
    });

    group('propertiesRowIconSizeFor', () {
      test('mobile returns a larger icon than desktop', () {
        expect(
          propertiesRowIconSizeFor(isMobile: true),
          greaterThan(propertiesRowIconSizeFor(isMobile: false)),
        );
      });

      test('desktop keeps the current 12', () {
        expect(propertiesRowIconSizeFor(isMobile: false), 12);
      });
    });

    group('propertiesRowKeyFontSizeFor', () {
      test('mobile returns a larger key font than desktop', () {
        expect(
          propertiesRowKeyFontSizeFor(isMobile: true),
          greaterThan(propertiesRowKeyFontSizeFor(isMobile: false)),
        );
      });

      test('desktop keeps the current 12', () {
        expect(propertiesRowKeyFontSizeFor(isMobile: false), 12);
      });
    });
  });
}
