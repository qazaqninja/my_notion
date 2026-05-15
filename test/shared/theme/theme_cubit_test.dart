import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/shared/theme/accent.dart';
import 'package:my_notion/shared/theme/app_theme_mode.dart';
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
      expect(cubit.state.mode, AppThemeMode.system);
      expect(cubit.state.accent, AccentKey.sage);
      expect(cubit.state.compact, isFalse);
      unawaited(cubit.close());
    });

    test('load() hydrates from SharedPreferences when set', () async {
      SharedPreferences.setMockInitialValues({
        'theme.mode': 'dark',
        'theme.accent': 'terracotta',
        'theme.compact': true,
      });
      final cubit = ThemeCubit();
      await cubit.load();
      expect(cubit.state.mode, AppThemeMode.dark);
      expect(cubit.state.accent, AccentKey.terracotta);
      expect(cubit.state.compact, isTrue);
      unawaited(cubit.close());
    });

    test('load() falls back to defaults on unknown values', () async {
      SharedPreferences.setMockInitialValues({
        'theme.mode': 'wat',
        'theme.accent': 'not-a-real-accent',
      });
      final cubit = ThemeCubit();
      await cubit.load();
      expect(cubit.state.mode, AppThemeMode.system);
      expect(cubit.state.accent, AccentKey.sage);
      unawaited(cubit.close());
    });

    test('setMode emits new state and persists to prefs', () async {
      final cubit = ThemeCubit();
      await cubit.setMode(AppThemeMode.dark);
      expect(cubit.state.mode, AppThemeMode.dark);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme.mode'), 'dark');
      unawaited(cubit.close());
    });

    test('setAccent emits new state and persists to prefs', () async {
      final cubit = ThemeCubit();
      await cubit.setAccent(AccentKey.terracotta);
      expect(cubit.state.accent, AccentKey.terracotta);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme.accent'), 'terracotta');
      unawaited(cubit.close());
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
      unawaited(cubit.close());
    });

    test('cycleMode walks light → dark → system → light', () async {
      final cubit = ThemeCubit();
      await cubit.setMode(AppThemeMode.light);
      await cubit.cycleMode();
      expect(cubit.state.mode, AppThemeMode.dark);
      await cubit.cycleMode();
      expect(cubit.state.mode, AppThemeMode.system);
      await cubit.cycleMode();
      expect(cubit.state.mode, AppThemeMode.light);
      unawaited(cubit.close());
    });

    test('toggleAccent alternates sage ↔ terracotta', () async {
      final cubit = ThemeCubit();
      expect(cubit.state.accent, AccentKey.sage);
      await cubit.toggleAccent();
      expect(cubit.state.accent, AccentKey.terracotta);
      await cubit.toggleAccent();
      expect(cubit.state.accent, AccentKey.sage);
      unawaited(cubit.close());
    });
  });
}
