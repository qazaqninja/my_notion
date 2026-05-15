import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'accent.dart';
import 'app_theme_mode.dart';

class ThemeState extends Equatable {
  const ThemeState({
    required this.mode,
    required this.accent,
    this.compact = false,
  });

  /// Plain-Dart [AppThemeMode] keeps the cubit layer Flutter-free (CA-01).
  /// The widget layer maps to Flutter's `ThemeMode` at the boundary.
  final AppThemeMode mode;
  final AccentKey accent;

  /// When true, the global text scale is shrunk to ~0.92× so the UI fits
  /// more content per viewport. Matches Notion's "small text" toggle.
  final bool compact;

  ThemeState copyWith({AppThemeMode? mode, AccentKey? accent, bool? compact}) {
    return ThemeState(
      mode: mode ?? this.mode,
      accent: accent ?? this.accent,
      compact: compact ?? this.compact,
    );
  }

  @override
  List<Object?> get props => [mode, accent, compact];
}

class ThemeCubit extends Cubit<ThemeState> {
  ThemeCubit() : super(const ThemeState(mode: AppThemeMode.system, accent: AccentKey.sage));

  static const _modeKey = 'theme.mode';
  static const _accentKey = 'theme.accent';
  static const _compactKey = 'theme.compact';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final modeName = prefs.getString(_modeKey);
    final accentName = prefs.getString(_accentKey);
    final compact = prefs.getBool(_compactKey) ?? false;
    emit(ThemeState(
      mode: AppThemeMode.values.firstWhere(
        (m) => m.name == modeName,
        orElse: () => AppThemeMode.system,
      ),
      accent: AccentKey.values.firstWhere(
        (a) => a.name == accentName,
        orElse: () => AccentKey.sage,
      ),
      compact: compact,
    ));
  }

  Future<void> setMode(AppThemeMode mode) async {
    emit(state.copyWith(mode: mode));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, mode.name);
  }

  Future<void> setAccent(AccentKey accent) async {
    emit(state.copyWith(accent: accent));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accentKey, accent.name);
  }

  Future<void> setCompact({required bool value}) async {
    emit(state.copyWith(compact: value));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_compactKey, value);
  }

  Future<void> toggleCompact() => setCompact(value: !state.compact);

  Future<void> toggleAccent() {
    final next = state.accent == AccentKey.sage ? AccentKey.terracotta : AccentKey.sage;
    return setAccent(next);
  }

  Future<void> cycleMode() {
    final next = switch (state.mode) {
      AppThemeMode.light => AppThemeMode.dark,
      AppThemeMode.dark => AppThemeMode.system,
      AppThemeMode.system => AppThemeMode.light,
    };
    return setMode(next);
  }
}
