import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/core/routing/routes.dart';

void main() {
  group('Routes', () {
    test('exposes the static `home` path', () {
      expect(Routes.home, '/home');
    });

    test('exposes the static `picker` path', () {
      expect(Routes.picker, '/');
    });

    test('exposes the static `vault` path', () {
      expect(Routes.vault, '/vault');
    });

    test('exposes the static `databases` path', () {
      expect(Routes.databases, '/databases');
    });

    test('exposes the static `tags` path', () {
      expect(Routes.tags, '/tags');
    });

    test('exposes the static `settings` path', () {
      expect(Routes.settings, '/settings');
    });
  });
}
