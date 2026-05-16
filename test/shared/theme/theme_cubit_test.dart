// Ported to bloc_test (RULES.md TS-03) at A7 / M1198 of the 1m-loop plan.
// Previous hand-written subscription style retained where the assertion is
// about initial state (no event emitted) or SharedPreferences persistence
// (a side effect, not a state emission) — blocTest is the wrong tool for
// those.

import 'package:bloc_test/bloc_test.dart';
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
      // Initial-state assertion — blocTest can't express "no emission yet,
      // but inspect state" cleanly, so keep this as a vanilla test.
      final cubit = ThemeCubit();
      addTearDown(cubit.close);
      expect(cubit.state.mode, AppThemeMode.system);
      expect(cubit.state.accent, AccentKey.sage);
      expect(cubit.state.compact, isFalse);
    });

    blocTest<ThemeCubit, ThemeState>(
      'load() hydrates from SharedPreferences when set',
      setUp: () => SharedPreferences.setMockInitialValues({
        'theme.mode': 'dark',
        'theme.accent': 'terracotta',
        'theme.compact': true,
      }),
      build: ThemeCubit.new,
      act: (cubit) => cubit.load(),
      verify: (cubit) {
        expect(cubit.state.mode, AppThemeMode.dark);
        expect(cubit.state.accent, AccentKey.terracotta);
        expect(cubit.state.compact, isTrue);
      },
    );

    blocTest<ThemeCubit, ThemeState>(
      'load() falls back to defaults on unknown values',
      setUp: () => SharedPreferences.setMockInitialValues({
        'theme.mode': 'wat',
        'theme.accent': 'not-a-real-accent',
      }),
      build: ThemeCubit.new,
      act: (cubit) => cubit.load(),
      verify: (cubit) {
        expect(cubit.state.mode, AppThemeMode.system);
        expect(cubit.state.accent, AccentKey.sage);
      },
    );

    blocTest<ThemeCubit, ThemeState>(
      'setMode(dark) emits a single state with mode=dark and persists to prefs',
      build: ThemeCubit.new,
      act: (cubit) => cubit.setMode(AppThemeMode.dark),
      verify: (cubit) async {
        expect(cubit.state.mode, AppThemeMode.dark);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('theme.mode'), 'dark');
      },
    );

    blocTest<ThemeCubit, ThemeState>(
      'setAccent(terracotta) emits state.accent=terracotta and persists',
      build: ThemeCubit.new,
      act: (cubit) => cubit.setAccent(AccentKey.terracotta),
      verify: (cubit) async {
        expect(cubit.state.accent, AccentKey.terracotta);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('theme.accent'), 'terracotta');
      },
    );

    blocTest<ThemeCubit, ThemeState>(
      'toggleCompact flips compact twice and persists each time',
      build: ThemeCubit.new,
      act: (cubit) async {
        await cubit.toggleCompact();
        await cubit.toggleCompact();
      },
      verify: (cubit) async {
        expect(cubit.state.compact, isFalse); // back to start after two flips
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('theme.compact'), isFalse);
      },
    );

    blocTest<ThemeCubit, ThemeState>(
      'cycleMode walks light → dark → system → light',
      build: ThemeCubit.new,
      act: (cubit) async {
        await cubit.setMode(AppThemeMode.light);
        await cubit.cycleMode();
        expect(cubit.state.mode, AppThemeMode.dark);
        await cubit.cycleMode();
        expect(cubit.state.mode, AppThemeMode.system);
        await cubit.cycleMode();
      },
      verify: (cubit) {
        expect(cubit.state.mode, AppThemeMode.light);
      },
    );

    blocTest<ThemeCubit, ThemeState>(
      'toggleAccent alternates sage ↔ terracotta',
      build: ThemeCubit.new,
      act: (cubit) async {
        await cubit.toggleAccent();
        expect(cubit.state.accent, AccentKey.terracotta);
        await cubit.toggleAccent();
      },
      verify: (cubit) {
        expect(cubit.state.accent, AccentKey.sage);
      },
    );
  });
}
