import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/settings/presentation/cubit/editor_preferences_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('EditorPreferencesCubit', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    group('initial state', () {
      test('useBetaEditor defaults to false when prefs are empty', () {
        final cubit = EditorPreferencesCubit.fromPrefs(prefs);
        addTearDown(cubit.close);
        expect(cubit.state.useBetaEditor, isFalse);
      });

      test('useBetaEditor reads stored true value', () async {
        SharedPreferences.setMockInitialValues({'editor.useBeta': true});
        prefs = await SharedPreferences.getInstance();
        final cubit = EditorPreferencesCubit.fromPrefs(prefs);
        addTearDown(cubit.close);
        expect(cubit.state.useBetaEditor, isTrue);
      });
    });

    group('setUseBetaEditor', () {
      blocTest<EditorPreferencesCubit, EditorPreferencesState>(
        'emits useBetaEditor=true when toggled on from default',
        build: () => EditorPreferencesCubit.fromPrefs(prefs),
        act: (cubit) => cubit.setUseBetaEditor(useBeta: true),
        expect: () => [const EditorPreferencesState(useBetaEditor: true)],
      );

      blocTest<EditorPreferencesCubit, EditorPreferencesState>(
        'persists the toggle value to SharedPreferences',
        build: () => EditorPreferencesCubit.fromPrefs(prefs),
        act: (cubit) => cubit.setUseBetaEditor(useBeta: true),
        verify: (_) => expect(prefs.getBool('editor.useBeta'), isTrue),
      );

      blocTest<EditorPreferencesCubit, EditorPreferencesState>(
        'emits useBetaEditor=false when toggled off',
        setUp: () async {
          SharedPreferences.setMockInitialValues({'editor.useBeta': true});
          prefs = await SharedPreferences.getInstance();
        },
        build: () => EditorPreferencesCubit.fromPrefs(prefs),
        act: (cubit) => cubit.setUseBetaEditor(useBeta: false),
        expect: () => [const EditorPreferencesState(useBetaEditor: false)],
        verify: (_) => expect(prefs.getBool('editor.useBeta'), isFalse),
      );

      blocTest<EditorPreferencesCubit, EditorPreferencesState>(
        'does not re-emit when value is unchanged (BL-12-aware)',
        setUp: () async {
          SharedPreferences.setMockInitialValues({'editor.useBeta': true});
          prefs = await SharedPreferences.getInstance();
        },
        build: () => EditorPreferencesCubit.fromPrefs(prefs),
        act: (cubit) => cubit.setUseBetaEditor(useBeta: true), // same value
        expect: () => const <EditorPreferencesState>[],
      );
    });

    group('equality', () {
      test('EditorPreferencesState equality is value-based', () {
        const a = EditorPreferencesState(useBetaEditor: true);
        const b = EditorPreferencesState(useBetaEditor: true);
        const c = EditorPreferencesState(useBetaEditor: false);
        expect(a, b);
        expect(a, isNot(c));
      });
    });
  });
}
