import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // D30c-b (M1763): the EditorPreferencesCubit + EditorPreferencesState +
  // EditorPreferencesStore + LazySharedPreferencesEditorPreferencesStore +
  // InMemoryEditorPreferencesStore + SharedPreferencesEditorPreferencesStore
  // family is removed. After M1759 (D30c-a) collapsed the GoRoute fork
  // helper, M1761 (D30c-c) dropped the Settings → Advanced toggle row +
  // the root BlocProvider, leaving the field/construction/hydrate/dispose
  // in app.dart as the only orphan. This slice removes those + the
  // source files + the dedicated tests entirely.
  group('D30c-b deletion-guard', () {
    test('Cubit source file is removed', () {
      final file = File(
        'lib/features/settings/presentation/cubit/editor_preferences_cubit.dart',
      );
      expect(
        file.existsSync(),
        isFalse,
        reason: 'D30c-b: cubit + state deleted (no consumers remain)',
      );
    });

    test('Store source file is removed', () {
      final file =
          File('lib/features/settings/data/editor_preferences_store.dart');
      expect(
        file.existsSync(),
        isFalse,
        reason: 'D30c-b: store interface + impls deleted (no consumers remain)',
      );
    });

    test('app.dart has no EditorPreferencesCubit / Store references', () {
      final source = File('lib/app.dart').readAsStringSync();
      expect(
        source.contains('EditorPreferencesCubit'),
        isFalse,
        reason: 'D30c-b: field + construction + dispose + import removed',
      );
      expect(
        source.contains('EditorPreferencesStore'),
        isFalse,
        reason: 'D30c-b: store import removed',
      );
      expect(
        source.contains('LazySharedPreferencesEditorPreferencesStore'),
        isFalse,
        reason: 'D30c-b: store construction removed',
      );
      expect(
        source.contains('_editorPreferencesCubit'),
        isFalse,
        reason: 'D30c-b: field + hydrate + close removed',
      );
    });

    test('app.dart no longer imports editor_preferences_*.dart', () {
      final source = File('lib/app.dart').readAsStringSync();
      expect(
        source.contains('editor_preferences_cubit.dart'),
        isFalse,
      );
      expect(
        source.contains('editor_preferences_store.dart'),
        isFalse,
      );
    });
  });
}
