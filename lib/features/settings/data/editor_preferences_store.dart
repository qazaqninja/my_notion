import 'package:shared_preferences/shared_preferences.dart';

/// Backend-agnostic persistence interface for [EditorPreferencesCubit]'s
/// `useBetaEditor` opt-in flag.
///
/// **Motivation (BL-01, M1662 audit deferred → M1675 landed):** the
/// cubit previously held a concrete `SharedPreferences` handle, which
/// coupled it to one platform-channel backend. If the persistence
/// target ever needs to migrate (e.g., to `SecureStorage` for D30,
/// or to a serverside Postgres row for multi-device sync), every
/// call site of the cubit would otherwise have to follow.
///
/// This interface accepts that one indirection so the cubit can stay
/// agnostic. Production wires
/// [SharedPreferencesEditorPreferencesStore]; tests use the in-memory
/// [InMemoryEditorPreferencesStore] to sidestep `setMockInitialValues`
/// ceremony.
///
/// Slice 1 (M1675): introduce the interface + two implementations + a
/// test suite. Slice 2 (queued) migrates the cubit constructor to
/// take a store instead of a `SharedPreferences` directly.
abstract class EditorPreferencesStore {
  /// Read the persisted `useBetaEditor` value. Returns `null` when
  /// the key has never been written — callers should fall back to a
  /// default (today: `true`, the D29 cutover default).
  Future<bool?> readUseBetaEditor();

  /// Persist a new `useBetaEditor` value, overwriting any prior one.
  Future<void> writeUseBetaEditor({required bool useBeta});
}

/// Production implementation backed by Flutter's
/// [SharedPreferences] platform channel. Stores the bool under
/// [useBetaPrefKey] (kept as a public static const for cross-package
/// visibility — tests + future migrations may reference the key
/// directly).
class SharedPreferencesEditorPreferencesStore
    implements EditorPreferencesStore {
  /// Construct a store wrapping the supplied [SharedPreferences]
  /// handle. The composition root resolves
  /// `SharedPreferences.getInstance()` once and passes it here.
  const SharedPreferencesEditorPreferencesStore(this._prefs);

  /// SharedPreferences key used for the `useBetaEditor` bool.
  /// Mirrors `EditorPreferencesCubit.useBetaPrefKey` (kept in sync
  /// by hand for now; D-cutover-30 may unify these once the legacy
  /// `EditorPage` is deleted).
  static const useBetaPrefKey = 'editor.useBeta';

  final SharedPreferences _prefs;

  @override
  Future<bool?> readUseBetaEditor() async => _prefs.getBool(useBetaPrefKey);

  @override
  Future<void> writeUseBetaEditor({required bool useBeta}) =>
      _prefs.setBool(useBetaPrefKey, useBeta);
}

/// Production implementation that wraps a `Future<SharedPreferences>`
/// so callers can construct the store synchronously while the
/// platform-channel handle resolves in the background. Each read/
/// write awaits the future (which caches its result after the first
/// resolution) and delegates to a [SharedPreferencesEditorPreferencesStore].
///
/// The app composition root (`lib/app.dart`) constructs one of these
/// at boot via `LazySharedPreferencesEditorPreferencesStore(
/// SharedPreferences.getInstance())` and passes it to
/// `EditorPreferencesCubit`. The cubit's default `useBetaEditor:
/// true` is in effect during the first ~few-ms window before the
/// future resolves; `cubit.hydrate()` runs in the background and
/// emits the persisted value if it differs.
class LazySharedPreferencesEditorPreferencesStore
    implements EditorPreferencesStore {
  /// Wrap an unresolved [Future] handle. The future is awaited once
  /// per read/write call (`Future` itself caches its single
  /// resolution after the first await).
  LazySharedPreferencesEditorPreferencesStore(this._prefs);

  final Future<SharedPreferences> _prefs;

  @override
  Future<bool?> readUseBetaEditor() async {
    final prefs = await _prefs;
    return prefs.getBool(SharedPreferencesEditorPreferencesStore.useBetaPrefKey);
  }

  @override
  Future<void> writeUseBetaEditor({required bool useBeta}) async {
    final prefs = await _prefs;
    await prefs.setBool(
      SharedPreferencesEditorPreferencesStore.useBetaPrefKey,
      useBeta,
    );
  }
}

/// Volatile in-memory implementation for tests. Sidesteps the
/// `SharedPreferences.setMockInitialValues({...})` ceremony — pass
/// the desired initial value to the constructor and write/read
/// directly.
class InMemoryEditorPreferencesStore implements EditorPreferencesStore {
  /// Construct a fake store optionally pre-seeded with [initial].
  InMemoryEditorPreferencesStore({bool? initial}) : _value = initial;

  bool? _value;

  @override
  Future<bool?> readUseBetaEditor() async => _value;

  @override
  Future<void> writeUseBetaEditor({required bool useBeta}) async {
    _value = useBeta;
  }
}
