import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistent settings for the editor surface. Currently surfaces a
/// single bool — whether to open `.md` files via the new beta WYSIWYG
/// editor (`EditorBetaPage`) or the legacy source/rendered split
/// (`EditorPage`).
///
/// Persistence: backed by [SharedPreferences] under the
/// [EditorPreferencesCubit.useBetaPrefKey] key.
///
/// **D29 cutover (M1670):** the unset-key default flipped from
/// `false` → `true`. Users who never touched the toggle now see the
/// beta WYSIWYG editor on next launch. Anyone who explicitly turned
/// the toggle off pre-D29 keeps `useBetaEditor: false` because the
/// stored value still wins over the default. The single-click
/// Settings → Advanced toggle remains the escape hatch. D30 deletes
/// the legacy `EditorPage` + this cubit once dogfooding proves the
/// flip safe.
class EditorPreferencesState extends Equatable {
  /// Construct an immutable preferences snapshot.
  const EditorPreferencesState({required this.useBetaEditor});

  /// True when the user has opted in to the beta WYSIWYG editor.
  /// Default at first run is `false`.
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

/// Cubit owning the editor preferences. Loaded once at app boot from
/// [SharedPreferences]; thereafter all writes flush back to the
/// store.
class EditorPreferencesCubit extends Cubit<EditorPreferencesState> {
  /// Default unhydrated constructor used at the app composition root.
  /// Pair with `..hydrate()` so the persisted value loads
  /// asynchronously after the bloc is provided to the widget tree.
  /// The cubit starts at [defaultUseBetaEditor] and emits the
  /// persisted value (if any) once [SharedPreferences.getInstance]
  /// resolves.
  EditorPreferencesCubit()
      : _prefs = null,
        super(
          const EditorPreferencesState(useBetaEditor: defaultUseBetaEditor),
        );

  /// Construct a cubit from a pre-fetched [SharedPreferences] handle.
  /// Preferred by tests since it sidesteps the async wait — the
  /// initial state reads the persisted value synchronously, falling
  /// back to [defaultUseBetaEditor] when the key is absent.
  EditorPreferencesCubit.fromPrefs(SharedPreferences prefs)
      : _prefs = prefs,
        super(
          EditorPreferencesState(
            useBetaEditor:
                prefs.getBool(useBetaPrefKey) ?? defaultUseBetaEditor,
          ),
        );

  /// SharedPreferences key used for [EditorPreferencesState.useBetaEditor].
  static const useBetaPrefKey = 'editor.useBeta';

  /// D29 cutover (M1670): default value when the key is absent. The
  /// new beta WYSIWYG editor is now the default; users who
  /// explicitly turned the toggle off pre-D29 keep their stored
  /// `false` value (persisted-wins-over-default semantics). The
  /// Settings → Advanced toggle remains the single-click escape
  /// hatch.
  static const defaultUseBetaEditor = true;

  SharedPreferences? _prefs;

  /// Idempotent: resolves [SharedPreferences] and reconciles the
  /// state if the persisted value differs from the current state.
  /// No-op once `_prefs` is set (either via the [fromPrefs]
  /// constructor or a prior [hydrate] call).
  ///
  /// Safe to call from `BlocProvider.create` — the cubit is usable
  /// before hydration with the default `useBetaEditor: false`.
  Future<void> hydrate() async {
    if (_prefs != null) return;
    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;
    final stored = prefs.getBool(useBetaPrefKey) ?? defaultUseBetaEditor;
    if (stored != state.useBetaEditor) {
      emit(state.copyWith(useBetaEditor: stored));
    }
  }

  /// Toggle the beta-editor opt-in. Explicit no-op when [useBeta]
  /// equals the current state — skips the prefs write and the emit.
  /// (Note: flutter_bloc's Equatable-aware emit-dedup only kicks in
  /// AFTER the first real emit, so the first redundant write would
  /// otherwise still go through; this early-return belt-and-braces
  /// the no-op semantics for the first-emit case.)
  ///
  /// Lazily resolves the [SharedPreferences] handle when the cubit
  /// was constructed without one (default constructor + no
  /// [hydrate] yet) — matches the SyncBloc per-handler pattern.
  Future<void> setUseBetaEditor({required bool useBeta}) async {
    if (state.useBetaEditor == useBeta) return;
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setBool(useBetaPrefKey, useBeta);
    emit(state.copyWith(useBetaEditor: useBeta));
  }
}
