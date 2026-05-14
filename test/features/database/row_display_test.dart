import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/database/domain/repositories/database_repository.dart';
import 'package:my_notion/features/database/domain/row_display.dart';

DatabasePageRow _row({required String title, Map<String, Object?>? cells}) {
  return DatabasePageRow(
    ulid: '01HX0V9R5N6E8L3P7Q8S9U2X4B',
    title: title,
    relativePath: '$title.md',
    cells: cells ?? const {},
  );
}

void main() {
  group('displayTitle', () {
    test('returns bare title when no icon cell', () {
      expect(displayTitle(_row(title: 'Roadmap')), 'Roadmap');
    });

    test('prefixes plain emoji icon onto title', () {
      expect(
        displayTitle(_row(title: 'Roadmap', cells: {'icon': '🗺️'})),
        '🗺️  Roadmap',
      );
    });

    test('ignores asset-path icons (would need async image load)', () {
      expect(
        displayTitle(_row(title: 'Pic', cells: {'icon': 'assets/foo.png'})),
        'Pic',
      );
    });

    test('ignores URL icons', () {
      expect(
        displayTitle(_row(title: 'Web', cells: {'icon': 'https://x/y.png'})),
        'Web',
      );
    });

    test('ignores overly long icon values', () {
      expect(
        displayTitle(_row(title: 'X', cells: {'icon': 'tooooolong'})),
        'X',
      );
    });

    test('ignores whitespace-only icon values', () {
      expect(
        displayTitle(_row(title: 'Y', cells: {'icon': '   '})),
        'Y',
      );
    });
  });
}
