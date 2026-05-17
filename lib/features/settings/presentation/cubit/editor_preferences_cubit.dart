import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/editor_preferences_store.dart';

/// Persistent settings for the editor surface. Currently surfaces a
/// single bool — whether to open `.md` files via the new beta WYSIWYG
/// editor (`EditorBetaPage`) or the legacy source/rendered split
/// (`EditorPage`).
///
/// Persistence: backed by an [EditorPreferencesStore] under the key
/// `'editor.useBeta'`. Production wires
/// [SharedPreferencesEditorPreferencesStore]; tests use
/// [InMemoryEditorPreferencesStore].
///
/// **D29 cutover (M1670):** the unset-key default flipped from
/// `false` → `true`. Users who never touched the toggle now see the
/// beta WYSIWYG editor on next launch. Anyone who explicitly turned
/// the toggle off pre-D29 keeps `useBetaEditor: false` because the
/// stored value still wins over the default. The single-click
/// Settings → Advanced toggle remains the escape hatch. D30 deletes
/// the legacy `EditorPage` + this cubit once dogfooding proves the
/// flip safe.
///
/// **BL-01 slice 2 (M1677):** dropped the direct `SharedPreferences`
/// dependency in favour of [EditorPreferencesStore]. The interface +
/// two implementations live at
/// `lib/features/settings/data/editor_preferences_store.dart`
/// (introduced at M1675).
class EditorPreferencesState extends Equatable {
  /// Construct an immutable preferences snapshot.
  const EditorPreferencesState({required this.useBetaEditor});

  /// True when the user is on the beta WYSIWYG editor. Default at
  /// first run is `true` after the D29 cutover — see
  /// [EditorPreferencesCubit.defaultUseBetaEditor].
  final bool useBetaEditor;

  /// Copy with a new [useBetaEditor] value.
  EditorPreferencesState copyWith({bool? useBetaEditor}) {
    return EditorPreferencesState(
      useBetaEditor: useBetaEditor ?? this.useBetaEditor,
    );
  }

  @override
  List<Object?> get props => [useBetaEditor];
}

/// Cubit owning the editor preferences. Loaded once at app boot via
/// [hydrate]; thereafter all writes flush back to the [store].
class EditorPreferencesCubit extends Cubit<EditorPreferencesState> {
  /// Construct a cubit wrapping the supplied [store]. Pair with
  /// `..hydrate()` so the persisted value loads asynchronously after
  /// the cubit is provided to the widget tree. The cubit starts at
  /// [defaultUseBetaEditor] and emits the persisted value (if any)
  /// once [store.readUseBetaEditor] resolves.
  EditorPreferencesCubit(EditorPreferencesStore store)
      : _store = store,
        super(
          const EditorPreferencesState(useBetaEditor: defaultUseBetaEditor),
        );

  /// D29 cutover (M1670): default value when the key is absent. The
  /// new beta WYSIWYG editor is now the default; users who
  /// explicitly turned the toggle off pre-D29 keep their stored
  /// `false` value (persisted-wins-over-default semantics). The
  /// Settings → Advanced toggle remains the single-click escape
  /// hatch.
  static const defaultUseBetaEditor = true;

  final EditorPreferencesStore _store;
  bool _hydrated = false;

  /// Idempotent: reads the persisted value from [_store] and emits a
  /// new state when it differs from the current default. No-op once
  /// hydrated.
  ///
  /// Safe to call from `BlocProvider.create` — the cubit is usable
  /// before hydration with the default `useBetaEditor: true`.
  Future<void> hydrate() async {
    if (_hydrated) return;
    _hydrated = true;
    final stored = await _store.readUseBetaEditor() ?? defaultUseBetaEditor;
    if (stored != state.useBetaEditor) {
      emit(state.copyWith(useBetaEditor: stored));
    }
  }

  /// Toggle the beta-editor opt-in. Explicit no-op when [useBeta]
  /// equals the current state — skips the store write and the emit.
  /// (Note: flutter_bloc's Equatable-aware emit-dedup only kicks in
  /// AFTER the first real emit, so the first redundant write would
  /// otherwise still go through; this early-return belt-and-braces
  /// the no-op semantics for the first-emit case.)
  Future<void> setUseBetaEditor({required bool useBeta}) async {
    if (state.useBetaEditor == useBeta) return;
    await _store.writeUseBetaEditor(useBeta: useBeta);
    emit(state.copyWith(useBetaEditor: useBeta));
  }
}
