import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/settings/presentation/cubit/editor_preferences_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('EditorPreferencesCubit', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    group('initial state', () {
      test('useBetaEditor defaults to false when prefs are empty', () async {
        final prefs = await SharedPreferences.getInstance();
        final cubit = EditorPreferencesCubit.fromPrefs(prefs);
        addTearDown(cubit.close);
        expect(cubit.state.useBetaEditor, isFalse);
      });

      test('useBetaEditor reads stored true value', () async {
        SharedPreferences.setMockInitialValues({
          'editor.useBeta': true,
        });
        final prefs = await SharedPreferences.getInstance();
        final cubit = EditorPreferencesCubit.fromPrefs(prefs);
        addTearDown(cubit.close);
        expect(cubit.state.useBetaEditor, isTrue);
      });
    });

    group('setUseBetaEditor', () {
      test('emits useBetaEditor=true when toggled on from default',
          () async {
        final prefs = await SharedPreferences.getInstance();
        final cubit = EditorPreferencesCubit.fromPrefs(prefs);
        addTearDown(cubit.close);
        final emitted = expectLater(
          cubit.stream,
          emitsInOrder(<EditorPreferencesState>[
            const EditorPreferencesState(useBetaEditor: true),
          ]),
        );
        await cubit.setUseBetaEditor(useBeta: true);
        await cubit.close();
        await emitted;
      });

      test('persists the toggle value to SharedPreferences', () async {
        final prefs = await SharedPreferences.getInstance();
        final cubit = EditorPreferencesCubit.fromPrefs(prefs);
        addTearDown(cubit.close);
        await cubit.setUseBetaEditor(useBeta: true);
        expect(prefs.getBool('editor.useBeta'), isTrue);
      });

      test('emits useBetaEditor=false when toggled off', () async {
        SharedPreferences.setMockInitialValues({
          'editor.useBeta': true,
        });
        final prefs = await SharedPreferences.getInstance();
        final cubit = EditorPreferencesCubit.fromPrefs(prefs);
        addTearDown(cubit.close);
        await cubit.setUseBetaEditor(useBeta: false);
        expect(cubit.state.useBetaEditor, isFalse);
        expect(prefs.getBool('editor.useBeta'), isFalse);
      });

      test('does not re-emit when value is unchanged (BL-12-aware)',
          () async {
        SharedPreferences.setMockInitialValues({'editor.useBeta': true});
        final prefs = await SharedPreferences.getInstance();
        final cubit = EditorPreferencesCubit.fromPrefs(prefs);
        addTearDown(cubit.close);
        final emissions = <EditorPreferencesState>[];
        final sub = cubit.stream.listen(emissions.add);
        addTearDown(sub.cancel);
        await cubit.setUseBetaEditor(useBeta: true); // same as current
        expect(emissions, isEmpty);
      });
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
