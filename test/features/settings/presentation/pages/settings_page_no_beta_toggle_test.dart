import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // D30c-c (M1761): the "Use beta WYSIWYG editor" toggle row has been
  // removed from Settings → Advanced. EditorBetaPage is now the only
  // editor (since D30b collapsed the GoRoute fork at M1757), so the
  // user-facing opt-out has nothing to do. The Cubit, Store, and root
  // BlocProvider follow in D30c-b/c.
  group('settings_page.dart D30c-c lean', () {
    final file =
        File('lib/features/settings/presentation/pages/settings_page.dart');

    test('does not import EditorPreferencesCubit', () {
      final source = file.readAsStringSync();
      expect(
        source.contains("import '../cubit/editor_preferences_cubit.dart'"),
        isFalse,
        reason: 'D30c-c: import removed with the toggle row',
      );
    });

    test('does not render the "Use beta WYSIWYG editor" toggle label', () {
      final source = file.readAsStringSync();
      expect(
        source.contains('Use beta WYSIWYG editor'),
        isFalse,
        reason: 'D30c-c: toggle deleted (EditorBetaPage is the only editor)',
      );
    });

    test('does not reference EditorPreferencesCubit/State in build code', () {
      final source = file.readAsStringSync();
      expect(
        source.contains('EditorPreferencesCubit'),
        isFalse,
        reason: 'D30c-c: no remaining bloc references',
      );
      expect(
        source.contains('EditorPreferencesState'),
        isFalse,
        reason: 'D30c-c: no remaining state references',
      );
    });
  });

  group('app.dart D30c-c lean', () {
    final file = File('lib/app.dart');

    test('does not register the EditorPreferencesCubit BlocProvider', () {
      final source = file.readAsStringSync();
      expect(
        source.contains('BlocProvider.value(value: _editorPreferencesCubit)'),
        isFalse,
        reason: 'D30c-c: orphan root provider removed; no consumers remain',
      );
    });
  });
}
