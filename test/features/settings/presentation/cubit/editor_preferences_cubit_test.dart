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
      test(
          'useBetaEditor defaults to true when prefs are empty '
          '(D29 cutover default)', () {
        final cubit = EditorPreferencesCubit.fromPrefs(prefs);
        addTearDown(cubit.close);
        expect(cubit.state.useBetaEditor, isTrue);
      });

      test(
          'useBetaEditor reads stored false value '
          '(pre-D29 user who opted out keeps the opt-out)', () async {
        SharedPreferences.setMockInitialValues({'editor.useBeta': false});
        prefs = await SharedPreferences.getInstance();
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
        'emits useBetaEditor=false when user opts out from D29 default',
        build: () => EditorPreferencesCubit.fromPrefs(prefs),
        act: (cubit) => cubit.setUseBetaEditor(useBeta: false),
        expect: () => [const EditorPreferencesState(useBetaEditor: false)],
      );

      blocTest<EditorPreferencesCubit, EditorPreferencesState>(
        'persists the toggle value to SharedPreferences',
        build: () => EditorPreferencesCubit.fromPrefs(prefs),
        act: (cubit) => cubit.setUseBetaEditor(useBeta: false),
        verify: (_) => expect(prefs.getBool('editor.useBeta'), isFalse),
      );

      blocTest<EditorPreferencesCubit, EditorPreferencesState>(
        'emits useBetaEditor=true when toggled back on after opt-out',
        setUp: () async {
          SharedPreferences.setMockInitialValues({'editor.useBeta': false});
          prefs = await SharedPreferences.getInstance();
        },
        build: () => EditorPreferencesCubit.fromPrefs(prefs),
        act: (cubit) => cubit.setUseBetaEditor(useBeta: true),
        expect: () => [const EditorPreferencesState(useBetaEditor: true)],
        verify: (_) => expect(prefs.getBool('editor.useBeta'), isTrue),
      );

      blocTest<EditorPreferencesCubit, EditorPreferencesState>(
        'does not re-emit when value is unchanged (BL-12-aware)',
        // Default-true matches the no-op write; tests the early-return
        // guard at the top of setUseBetaEditor.
        build: () => EditorPreferencesCubit.fromPrefs(prefs),
        act: (cubit) => cubit.setUseBetaEditor(useBeta: true), // same value
        expect: () => const <EditorPreferencesState>[],
      );
    });

    group('hydrate (lazy load)', () {
      blocTest<EditorPreferencesCubit, EditorPreferencesState>(
        'no-arg constructor starts at D29 default true then hydrates '
            'persisted false (opt-out)',
        setUp: () =>
            SharedPreferences.setMockInitialValues({'editor.useBeta': false}),
        build: EditorPreferencesCubit.new,
        act: (cubit) => cubit.hydrate(),
        expect: () => [const EditorPreferencesState(useBetaEditor: false)],
      );

      blocTest<EditorPreferencesCubit, EditorPreferencesState>(
        'hydrate is a no-op when persisted value matches D29 default',
        setUp: () => SharedPreferences.setMockInitialValues({}),
        build: EditorPreferencesCubit.new,
        act: (cubit) => cubit.hydrate(),
        expect: () => const <EditorPreferencesState>[],
      );

      blocTest<EditorPreferencesCubit, EditorPreferencesState>(
        'hydrate is idempotent — second call does nothing',
        setUp: () =>
            SharedPreferences.setMockInitialValues({'editor.useBeta': false}),
        build: EditorPreferencesCubit.new,
        act: (cubit) async {
          await cubit.hydrate(); // first call: emits false
          await cubit.hydrate(); // second call: idempotent no-op
        },
        expect: () => [const EditorPreferencesState(useBetaEditor: false)],
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
