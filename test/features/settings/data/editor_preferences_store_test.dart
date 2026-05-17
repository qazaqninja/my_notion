import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/settings/data/editor_preferences_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SharedPreferencesEditorPreferencesStore', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    group('read', () {
      test('returns null when the key is absent', () async {
        final prefs = await SharedPreferences.getInstance();
        final store = SharedPreferencesEditorPreferencesStore(prefs);
        expect(await store.readUseBetaEditor(), isNull);
      });

      test('returns the stored true value', () async {
        SharedPreferences.setMockInitialValues({'editor.useBeta': true});
        final prefs = await SharedPreferences.getInstance();
        final store = SharedPreferencesEditorPreferencesStore(prefs);
        expect(await store.readUseBetaEditor(), isTrue);
      });

      test('returns the stored false value', () async {
        SharedPreferences.setMockInitialValues({'editor.useBeta': false});
        final prefs = await SharedPreferences.getInstance();
        final store = SharedPreferencesEditorPreferencesStore(prefs);
        expect(await store.readUseBetaEditor(), isFalse);
      });
    });

    group('write', () {
      test('persists true to SharedPreferences', () async {
        final prefs = await SharedPreferences.getInstance();
        final store = SharedPreferencesEditorPreferencesStore(prefs);
        await store.writeUseBetaEditor(useBeta: true);
        expect(prefs.getBool('editor.useBeta'), isTrue);
      });

      test('persists false to SharedPreferences', () async {
        final prefs = await SharedPreferences.getInstance();
        final store = SharedPreferencesEditorPreferencesStore(prefs);
        await store.writeUseBetaEditor(useBeta: false);
        expect(prefs.getBool('editor.useBeta'), isFalse);
      });

      test('overwrites a previously stored value', () async {
        SharedPreferences.setMockInitialValues({'editor.useBeta': true});
        final prefs = await SharedPreferences.getInstance();
        final store = SharedPreferencesEditorPreferencesStore(prefs);
        await store.writeUseBetaEditor(useBeta: false);
        expect(prefs.getBool('editor.useBeta'), isFalse);
      });
    });

    group('round-trip', () {
      test('read after write returns the written value', () async {
        final prefs = await SharedPreferences.getInstance();
        final store = SharedPreferencesEditorPreferencesStore(prefs);
        await store.writeUseBetaEditor(useBeta: true);
        expect(await store.readUseBetaEditor(), isTrue);
        await store.writeUseBetaEditor(useBeta: false);
        expect(await store.readUseBetaEditor(), isFalse);
      });
    });
  });

  group('LazySharedPreferencesEditorPreferencesStore', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('read awaits the future and returns the stored value', () async {
      SharedPreferences.setMockInitialValues({'editor.useBeta': true});
      final lazy = LazySharedPreferencesEditorPreferencesStore(
        SharedPreferences.getInstance(),
      );
      expect(await lazy.readUseBetaEditor(), isTrue);
    });

    test('read returns null when the future-resolved store is empty',
        () async {
      final lazy = LazySharedPreferencesEditorPreferencesStore(
        SharedPreferences.getInstance(),
      );
      expect(await lazy.readUseBetaEditor(), isNull);
    });

    test('write awaits the future and persists', () async {
      final lazy = LazySharedPreferencesEditorPreferencesStore(
        SharedPreferences.getInstance(),
      );
      await lazy.writeUseBetaEditor(useBeta: true);
      // Round-trip via a fresh read off the same in-memory mock.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('editor.useBeta'), isTrue);
    });

    test('round-trip read after write returns the written value', () async {
      final lazy = LazySharedPreferencesEditorPreferencesStore(
        SharedPreferences.getInstance(),
      );
      await lazy.writeUseBetaEditor(useBeta: true);
      expect(await lazy.readUseBetaEditor(), isTrue);
      await lazy.writeUseBetaEditor(useBeta: false);
      expect(await lazy.readUseBetaEditor(), isFalse);
    });
  });

  group('InMemoryEditorPreferencesStore', () {
    test('starts with null when no initial value is supplied', () async {
      final store = InMemoryEditorPreferencesStore();
      expect(await store.readUseBetaEditor(), isNull);
    });

    test('respects the initial value', () async {
      final store = InMemoryEditorPreferencesStore(initial: true);
      expect(await store.readUseBetaEditor(), isTrue);
    });

    test('write persists the value in-memory', () async {
      final store = InMemoryEditorPreferencesStore();
      await store.writeUseBetaEditor(useBeta: true);
      expect(await store.readUseBetaEditor(), isTrue);
      await store.writeUseBetaEditor(useBeta: false);
      expect(await store.readUseBetaEditor(), isFalse);
    });
  });
}
