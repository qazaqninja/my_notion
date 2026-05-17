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

    test('exposes the static `lab` path', () {
      expect(Routes.lab, '/lab');
    });
  });

  group('Routes.editor', () {
    test('builds `/editor/<ulid>` without anchor', () {
      expect(Routes.editor('01HX'), '/editor/01HX');
    });

    test('omits anchor when null', () {
      expect(Routes.editor('01HX', anchor: null), '/editor/01HX');
    });

    test('omits anchor when empty string', () {
      expect(Routes.editor('01HX', anchor: ''), '/editor/01HX');
    });

    test('appends `?anchor=` when provided', () {
      expect(
        Routes.editor('01HX', anchor: 'section-1'),
        '/editor/01HX?anchor=section-1',
      );
    });
  });

  group('Routes.editorBeta', () {
    test('builds `/editor-beta/<ulid>`', () {
      expect(Routes.editorBeta('01HX'), '/editor-beta/01HX');
    });
  });

  group('Routes.db', () {
    test('builds `/db/<dbId>` without viewId', () {
      expect(Routes.db('abc'), '/db/abc');
    });

    test('omits viewId when null', () {
      expect(Routes.db('abc', viewId: null), '/db/abc');
    });

    test('omits viewId when empty', () {
      expect(Routes.db('abc', viewId: ''), '/db/abc');
    });

    test('appends viewId when provided', () {
      expect(Routes.db('abc', viewId: 'gallery'), '/db/abc/gallery');
    });
  });

  group('Routes.settingsSection', () {
    test('builds `/settings/<section>`', () {
      expect(Routes.settingsSection('forms'), '/settings/forms');
    });
  });
}
