import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:my_notion/features/settings/presentation/widgets/workspace_controls.dart';
import 'package:my_notion/features/vault/data/workspace_config.dart';
import 'package:my_notion/features/vault/domain/entities/vault_tree.dart';
import 'package:my_notion/features/vault/presentation/bloc/vault_bloc.dart';
import 'package:my_notion/features/vault/presentation/bloc/vault_event.dart';
import 'package:my_notion/features/vault/presentation/bloc/vault_state.dart';
import 'package:my_notion/shared/theme/accent.dart';
import 'package:my_notion/shared/theme/tokens.dart';
import 'package:my_notion/shared/widgets/quill_toast.dart';

class _MockVaultBloc extends MockBloc<VaultEvent, VaultState>
    implements VaultBloc {}

/// TS-01 sweep slice 3 — widget tests for the two workspace controls
/// extracted to `lib/features/settings/presentation/widgets/
/// workspace_controls.dart` in M1428 (FS-04 slice 4). Unlike slices
/// 1-2, these widgets consume VaultBloc and dispatch RefreshFromDisk
/// after writing `.quill.yaml` to disk — tests need a mocktail
/// VaultBloc + a real tempdir to host the file write.
void main() {
  setUpAll(() {
    registerFallbackValue(const RefreshFromDisk());
  });

  late Directory tempVault;

  setUp(() {
    tempVault = Directory.systemTemp.createTempSync('quill_ws_test_');
  });

  tearDown(() {
    if (tempVault.existsSync()) {
      tempVault.deleteSync(recursive: true);
    }
  });

  VaultLoaded loaded({String? name, String? icon}) {
    return VaultLoaded(
      rootPath: tempVault.path,
      tree: VaultTree.empty,
      expandedFolders: const <String>{},
      pageCount: 0,
      workspace: WorkspaceConfig(name: name, icon: icon),
    );
  }

  Widget pump(Widget child, VaultBloc bloc) {
    return MaterialApp(
      theme: makeTheme(Brightness.light, AccentKey.sage),
      home: QuillToastHost(
        child: Scaffold(
          body: BlocProvider<VaultBloc>.value(
            value: bloc,
            // Center keeps loose constraints so the 32-px button and
            // 300-px field can honour their own widths.
            child: Center(child: child),
          ),
        ),
      ),
    );
  }

  group('WorkspaceIconButton', () {
    testWidgets('renders the emoji string when icon is non-empty',
        (tester) async {
      final bloc = _MockVaultBloc();
      when(() => bloc.state).thenReturn(loaded(icon: '🪶'));
      await tester.pumpWidget(pump(
        WorkspaceIconButton(state: loaded(icon: '🪶')),
        bloc,
      ));
      expect(find.text('🪶'), findsOneWidget);
    });

    testWidgets('renders the placeholder face icon when icon is empty',
        (tester) async {
      final bloc = _MockVaultBloc();
      when(() => bloc.state).thenReturn(loaded());
      await tester.pumpWidget(pump(
        WorkspaceIconButton(state: loaded()),
        bloc,
      ));
      // The placeholder Icon is Icons.tag_faces_outlined per the source.
      expect(find.byIcon(Icons.tag_faces_outlined), findsOneWidget);
    });

    testWidgets("GestureDetector is wired (tap doesn't throw)",
        (tester) async {
      final bloc = _MockVaultBloc();
      when(() => bloc.state).thenReturn(loaded(icon: '🪶'));
      await tester.pumpWidget(pump(
        WorkspaceIconButton(state: loaded(icon: '🪶')),
        bloc,
      ));
      // The emoji-picker dialog (pickEmoji) is the outer collaborator
      // and isn't testable here without stubbing the picker. Smoke
      // that the tap is registered — failures would throw.
      await tester.tap(find.text('🪶'));
      await tester.pump();
    });
  });

  group('WorkspaceNameField', () {
    testWidgets('pre-fills with workspace.name', (tester) async {
      final bloc = _MockVaultBloc();
      when(() => bloc.state).thenReturn(loaded(name: 'Daily Notes'));
      await tester.pumpWidget(pump(
        WorkspaceNameField(state: loaded(name: 'Daily Notes')),
        bloc,
      ));
      expect(find.text('Daily Notes'), findsOneWidget);
    });

    testWidgets('Enter dispatches RefreshFromDisk after writing .quill.yaml',
        (tester) async {
      final bloc = _MockVaultBloc();
      when(() => bloc.state).thenReturn(loaded(name: ''));
      await tester.pumpWidget(pump(
        WorkspaceNameField(state: loaded(name: '')),
        bloc,
      ));
      await tester.enterText(find.byType(TextField), 'New Vault');
      // tester.runAsync lets the real async I/O (next.save → file
      // write) settle. pumpAndSettle alone doesn't drain the
      // microtask queue created by `await next.save(...)`.
      await tester.runAsync(() async {
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
      // Pressing Enter on the TextField fires _commit twice in the
      // current source — once via onSubmitted, once via the focus
      // listener since done dismisses focus. Either fires the
      // intended dispatch; the test asserts behavior, not count.
      verify(() => bloc.add(const RefreshFromDisk()));
      final cfg = File('${tempVault.path}/.quill.yaml');
      expect(cfg.existsSync(), isTrue);
      expect(cfg.readAsStringSync(), contains('name: New Vault'));
    });

    testWidgets('committing unchanged text is a no-op (no dispatch)',
        (tester) async {
      final bloc = _MockVaultBloc();
      when(() => bloc.state).thenReturn(loaded(name: 'Quill'));
      await tester.pumpWidget(pump(
        WorkspaceNameField(state: loaded(name: 'Quill')),
        bloc,
      ));
      // Submit without changing the text. Same runAsync drain
      // pattern in case _commit's I/O were to be reached.
      await tester.runAsync(() async {
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
      verifyNever(() => bloc.add(const RefreshFromDisk()));
    });

    testWidgets('hintText falls back to the folder basename when name is null',
        (tester) async {
      final bloc = _MockVaultBloc();
      when(() => bloc.state).thenReturn(loaded());
      await tester.pumpWidget(pump(
        WorkspaceNameField(state: loaded()),
        bloc,
      ));
      // The hint comes from `state.rootPath.split('/').last.replaceAll('_', ' ')`.
      final expectedHint = tempVault.path
          .split(Platform.pathSeparator)
          .last
          .replaceAll('_', ' ');
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.decoration?.hintText, expectedHint);
    });
  });
}
