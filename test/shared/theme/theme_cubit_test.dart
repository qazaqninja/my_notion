import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/shared/theme/accent.dart';
import 'package:my_notion/shared/theme/theme_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ThemeCubit', () {
    test('starts with system theme + sage accent + compact=false', () {
      final cubit = ThemeCubit();
      expect(cubit.state.mode, ThemeMode.system);
      expect(cubit.state.accent, AccentKey.sage);
      expect(cubit.state.compact, isFalse);
      cubit.close();
    });

    test('load() hydrates from SharedPreferences when set', () async {
      SharedPreferences.setMockInitialValues({
        'theme.mode': 'dark',
        'theme.accent': 'terracotta',
        'theme.compact': true,
      });
      final cubit = ThemeCubit();
      await cubit.load();
      expect(cubit.state.mode, ThemeMode.dark);
      expect(cubit.state.accent, AccentKey.terracotta);
      expect(cubit.state.compact, isTrue);
      cubit.close();
    });

    test('load() falls back to defaults on unknown values', () async {
      SharedPreferences.setMockInitialValues({
        'theme.mode': 'wat',
        'theme.accent': 'not-a-real-accent',
      });
      final cubit = ThemeCubit();
      await cubit.load();
      expect(cubit.state.mode, ThemeMode.system);
      expect(cubit.state.accent, AccentKey.sage);
      cubit.close();
    });

    test('setMode emits new state and persists to prefs', () async {
      final cubit = ThemeCubit();
      await cubit.setMode(ThemeMode.dark);
      expect(cubit.state.mode, ThemeMode.dark);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme.mode'), 'dark');
      cubit.close();
    });

    test('setAccent emits new state and persists to prefs', () async {
      final cubit = ThemeCubit();
      await cubit.setAccent(AccentKey.terracotta);
      expect(cubit.state.accent, AccentKey.terracotta);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme.accent'), 'terracotta');
      cubit.close();
    });

    test('toggleCompact flips and persists', () async {
      final cubit = ThemeCubit();
      expect(cubit.state.compact, isFalse);
      await cubit.toggleCompact();
      expect(cubit.state.compact, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('theme.compact'), isTrue);
      await cubit.toggleCompact();
      expect(cubit.state.compact, isFalse);
      cubit.close();
    });

    test('cycleMode walks light → dark → system → light', () async {
      final cubit = ThemeCubit();
      await cubit.setMode(ThemeMode.light);
      await cubit.cycleMode();
      expect(cubit.state.mode, ThemeMode.dark);
      await cubit.cycleMode();
      expect(cubit.state.mode, ThemeMode.system);
      await cubit.cycleMode();
      expect(cubit.state.mode, ThemeMode.light);
      cubit.close();
    });

    test('toggleAccent alternates sage ↔ terracotta', () async {
      final cubit = ThemeCubit();
      expect(cubit.state.accent, AccentKey.sage);
      await cubit.toggleAccent();
      expect(cubit.state.accent, AccentKey.terracotta);
      await cubit.toggleAccent();
      expect(cubit.state.accent, AccentKey.sage);
      cubit.close();
    });
  });
}
