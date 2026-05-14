import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'accent.dart';

class ThemeState extends Equatable {
  const ThemeState({required this.mode, required this.accent});

  final ThemeMode mode;
  final AccentKey accent;

  ThemeState copyWith({ThemeMode? mode, AccentKey? accent}) {
    return ThemeState(mode: mode ?? this.mode, accent: accent ?? this.accent);
  }

  @override
  List<Object?> get props => [mode, accent];
}

class ThemeCubit extends Cubit<ThemeState> {
  ThemeCubit() : super(const ThemeState(mode: ThemeMode.system, accent: AccentKey.sage));

  static const _modeKey = 'theme.mode';
  static const _accentKey = 'theme.accent';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final modeName = prefs.getString(_modeKey);
    final accentName = prefs.getString(_accentKey);
    emit(ThemeState(
      mode: ThemeMode.values.firstWhere(
        (m) => m.name == modeName,
        orElse: () => ThemeMode.system,
      ),
      accent: AccentKey.values.firstWhere(
        (a) => a.name == accentName,
        orElse: () => AccentKey.sage,
      ),
    ));
  }

  Future<void> setMode(ThemeMode mode) async {
    emit(state.copyWith(mode: mode));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, mode.name);
  }

  Future<void> setAccent(AccentKey accent) async {
    emit(state.copyWith(accent: accent));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accentKey, accent.name);
  }

  Future<void> toggleAccent() {
    final next = state.accent == AccentKey.sage ? AccentKey.terracotta : AccentKey.sage;
    return setAccent(next);
  }

  Future<void> cycleMode() {
    final next = switch (state.mode) {
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
      ThemeMode.system => ThemeMode.light,
    };
    return setMode(next);
  }
}
