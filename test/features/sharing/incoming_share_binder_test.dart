import 'dart:async';
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:my_notion/features/sharing/domain/incoming_share.dart';
import 'package:my_notion/features/sharing/domain/incoming_share_source.dart';
import 'package:my_notion/features/sharing/presentation/incoming_share_binder.dart';
import 'package:my_notion/features/sharing/presentation/incoming_share_listener.dart';
import 'package:my_notion/features/vault/domain/entities/vault_tree.dart';
import 'package:my_notion/features/vault/presentation/bloc/vault_bloc.dart';
import 'package:my_notion/features/vault/presentation/bloc/vault_event.dart';
import 'package:my_notion/features/vault/presentation/bloc/vault_state.dart';

class _MockVaultBloc extends MockBloc<VaultEvent, VaultState>
    implements VaultBloc {}

class _FakeSource implements IncomingShareSource {
  final _controller = StreamController<List<IncomingShare>>.broadcast();
  bool closed = false;
  int initialCalls = 0;
  int closeCalls = 0;

  @override
  Future<List<IncomingShare>> initial() async {
    initialCalls++;
    return const [];
  }

  @override
  Stream<List<IncomingShare>> get stream => _controller.stream;

  @override
  Future<void> close() async {
    closeCalls++;
    closed = true;
    await _controller.close();
  }
}

VaultLoaded _loaded(String root) {
  // Minimum loaded state — only rootPath is read by the binder.
  return VaultLoaded(
    rootPath: root,
    tree: VaultTree.empty,
    expandedFolders: const <String>{},
    pageCount: 0,
  );
}

void main() {
  // Avoid surface-loaded warnings on unhandled mock streams.
  setUpAll(() {
    registerFallbackValue(const VaultInitial());
  });

  group('IncomingShareBinder (F2)', () {
    test('attach() starts a listener when bloc is already VaultLoaded',
        () async {
      final bloc = _MockVaultBloc();
      when(() => bloc.state).thenReturn(_loaded('/tmp/a'));
      whenListen(bloc, const Stream<VaultState>.empty(),
          initialState: _loaded('/tmp/a'));

      final sources = <_FakeSource>[];
      final binder = IncomingShareBinder(
        vaultBloc: bloc,
        sourceFactory: () {
          final s = _FakeSource();
          sources.add(s);
          return s;
        },
      );
      await binder.attach();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(sources.length, 1);
      expect(sources.single.initialCalls, 1);
      expect(binder.listener, isNotNull);
      expect(binder.listener!.isListening, isTrue);

      await binder.detach();
      expect(sources.single.closed, isTrue);
    });

    test('VaultLoaded transition spins up a fresh listener', () async {
      final bloc = _MockVaultBloc();
      whenListen(
        bloc,
        Stream.fromIterable([
          const VaultInitial(),
          _loaded('/tmp/b'),
        ]),
        initialState: const VaultInitial(),
      );

      final sources = <_FakeSource>[];
      final binder = IncomingShareBinder(
        vaultBloc: bloc,
        sourceFactory: () {
          final s = _FakeSource();
          sources.add(s);
          return s;
        },
      );
      await binder.attach();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(sources.length, 1);
      expect(binder.listener, isNotNull);
      await binder.detach();
    });

    test('Leaving VaultLoaded (VaultPicking) stops + closes the source',
        () async {
      final bloc = _MockVaultBloc();
      whenListen(
        bloc,
        Stream.fromIterable([
          _loaded('/tmp/c'),
          const VaultPicking(),
        ]),
        initialState: _loaded('/tmp/c'),
      );

      final sources = <_FakeSource>[];
      final binder = IncomingShareBinder(
        vaultBloc: bloc,
        sourceFactory: () {
          final s = _FakeSource();
          sources.add(s);
          return s;
        },
      );
      await binder.attach();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Source 0 was opened on the initial state read, then closed
      // when VaultPicking landed.
      expect(sources.length, greaterThanOrEqualTo(1));
      expect(sources.first.closed, isTrue);
      expect(binder.listener, isNull);
      await binder.detach();
    });

    test('Different rootPath swaps the listener', () async {
      final bloc = _MockVaultBloc();
      whenListen(
        bloc,
        Stream.fromIterable([
          _loaded('/tmp/d1'),
          _loaded('/tmp/d2'),
        ]),
        initialState: _loaded('/tmp/d1'),
      );

      final sources = <_FakeSource>[];
      IncomingShareListener? lastListener;
      final binder = IncomingShareBinder(
        vaultBloc: bloc,
        sourceFactory: () {
          final s = _FakeSource();
          sources.add(s);
          return s;
        },
        listenerFactory: ({
          required IncomingShareSource source,
          required Directory vaultRoot,
        }) {
          lastListener = IncomingShareListener(
            source: source,
            vaultRoot: vaultRoot,
            appender: (text, _) async => 'Inbox/Quick capture.md',
          );
          return lastListener!;
        },
      );
      await binder.attach();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // First source closed during the swap; new one is open.
      expect(sources.length, 2);
      expect(sources[0].closed, isTrue);
      expect(sources[1].closed, isFalse);
      expect(binder.listener, isNotNull);
      await binder.detach();
      expect(sources[1].closed, isTrue);
    });

    test('Same rootPath emitted twice does NOT swap', () async {
      final bloc = _MockVaultBloc();
      whenListen(
        bloc,
        Stream.fromIterable([
          _loaded('/tmp/same'),
          _loaded('/tmp/same'),
        ]),
        initialState: _loaded('/tmp/same'),
      );

      final sources = <_FakeSource>[];
      final binder = IncomingShareBinder(
        vaultBloc: bloc,
        sourceFactory: () {
          final s = _FakeSource();
          sources.add(s);
          return s;
        },
      );
      await binder.attach();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Only one source ever — duplicate state didn't trigger a swap.
      expect(sources.length, 1);
      await binder.detach();
    });
  });
}
