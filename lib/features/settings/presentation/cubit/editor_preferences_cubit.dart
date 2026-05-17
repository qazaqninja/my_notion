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
/// D28 cutover slice 1 (M1662) of the WYSIWYG migration: this is the
/// gateway the `/editor/:ulid` GoRoute will fork on. D29 will default
/// the key to `true`; D30 deletes the legacy `EditorPage` + this
/// cubit.
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
  /// Construct a cubit from a pre-fetched [SharedPreferences] handle.
  /// Use [EditorPreferencesCubit.fromPrefs] from the app
  /// composition root after the async [SharedPreferences.getInstance]
  /// has resolved.
  EditorPreferencesCubit.fromPrefs(this._prefs)
      : super(
          EditorPreferencesState(
            useBetaEditor: _prefs.getBool(useBetaPrefKey) ?? false,
          ),
        );

  /// SharedPreferences key used for [EditorPreferencesState.useBetaEditor].
  static const useBetaPrefKey = 'editor.useBeta';

  final SharedPreferences _prefs;

  /// Toggle the beta-editor opt-in. Explicit no-op when [useBeta]
  /// equals the current state — skips the prefs write and the emit.
  /// (Note: flutter_bloc's Equatable-aware emit-dedup only kicks in
  /// AFTER the first real emit, so the first redundant write would
  /// otherwise still go through; this early-return belt-and-braces
  /// the no-op semantics for the first-emit case.)
  Future<void> setUseBetaEditor({required bool useBeta}) async {
    if (state.useBetaEditor == useBeta) return;
    await _prefs.setBool(useBetaPrefKey, useBeta);
    emit(state.copyWith(useBetaEditor: useBeta));
  }
}
