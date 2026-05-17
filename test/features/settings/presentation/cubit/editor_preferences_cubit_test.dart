import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/settings/data/editor_preferences_store.dart';
import 'package:my_notion/features/settings/presentation/cubit/editor_preferences_cubit.dart';

void main() {
  group('EditorPreferencesCubit', () {
    group('initial state', () {
      test(
          'useBetaEditor defaults to true before hydrate '
          '(D29 cutover default)', () {
        final store = InMemoryEditorPreferencesStore();
        final cubit = EditorPreferencesCubit(store);
        addTearDown(cubit.close);
        expect(cubit.state.useBetaEditor, isTrue);
      });
    });

    group('hydrate', () {
      blocTest<EditorPreferencesCubit, EditorPreferencesState>(
        'emits the persisted false (pre-D29 opt-out preserved)',
        build: () => EditorPreferencesCubit(
          InMemoryEditorPreferencesStore(initial: false),
        ),
        act: (cubit) => cubit.hydrate(),
        expect: () => [const EditorPreferencesState(useBetaEditor: false)],
      );

      blocTest<EditorPreferencesCubit, EditorPreferencesState>(
        'no-op when store is empty (default matches absent key)',
        build: () =>
            EditorPreferencesCubit(InMemoryEditorPreferencesStore()),
        act: (cubit) => cubit.hydrate(),
        expect: () => const <EditorPreferencesState>[],
      );

      blocTest<EditorPreferencesCubit, EditorPreferencesState>(
        'no-op when persisted value matches D29 default',
        build: () => EditorPreferencesCubit(
          InMemoryEditorPreferencesStore(initial: true),
        ),
        act: (cubit) => cubit.hydrate(),
        expect: () => const <EditorPreferencesState>[],
      );

      blocTest<EditorPreferencesCubit, EditorPreferencesState>(
        'idempotent — second call does nothing',
        build: () => EditorPreferencesCubit(
          InMemoryEditorPreferencesStore(initial: false),
        ),
        act: (cubit) async {
          await cubit.hydrate(); // emits false
          await cubit.hydrate(); // idempotent no-op
        },
        expect: () => [const EditorPreferencesState(useBetaEditor: false)],
      );
    });

    group('setUseBetaEditor', () {
      blocTest<EditorPreferencesCubit, EditorPreferencesState>(
        'emits useBetaEditor=false when user opts out from D29 default',
        build: () =>
            EditorPreferencesCubit(InMemoryEditorPreferencesStore()),
        act: (cubit) => cubit.setUseBetaEditor(useBeta: false),
        expect: () => [const EditorPreferencesState(useBetaEditor: false)],
      );

      blocTest<EditorPreferencesCubit, EditorPreferencesState>(
        'persists the toggle value to the store',
        build: () =>
            EditorPreferencesCubit(InMemoryEditorPreferencesStore()),
        act: (cubit) => cubit.setUseBetaEditor(useBeta: false),
        verify: (cubit) async {
          // The store is reachable via a closure over the test-scoped
          // instance; build a parallel store + cubit to verify
          // round-trip semantics via the public API instead.
          final store = InMemoryEditorPreferencesStore();
          final c2 = EditorPreferencesCubit(store);
          addTearDown(c2.close);
          await c2.setUseBetaEditor(useBeta: false);
          expect(await store.readUseBetaEditor(), isFalse);
        },
      );

      blocTest<EditorPreferencesCubit, EditorPreferencesState>(
        'emits useBetaEditor=true when toggled back on after opt-out',
        build: () => EditorPreferencesCubit(
          InMemoryEditorPreferencesStore(initial: false),
        ),
        act: (cubit) async {
          await cubit.hydrate(); // sync to persisted false
          await cubit.setUseBetaEditor(useBeta: true);
        },
        expect: () => [
          const EditorPreferencesState(useBetaEditor: false),
          const EditorPreferencesState(useBetaEditor: true),
        ],
      );

      blocTest<EditorPreferencesCubit, EditorPreferencesState>(
        'does not re-emit when value is unchanged (BL-12-aware)',
        // Default-true matches the no-op write; exercises the
        // early-return guard at the top of setUseBetaEditor.
        build: () =>
            EditorPreferencesCubit(InMemoryEditorPreferencesStore()),
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
