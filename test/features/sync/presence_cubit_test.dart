// blocTest `act:` callbacks intentionally use closures that
// capture local fixture values — the lint's tearoff suggestion
// doesn't apply because instance methods of the bloc parameter
// aren't statically resolvable as tearoffs without changing the
// shape of the act signature.
// ignore_for_file: unnecessary_lambdas

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/sync/domain/entities/awareness_message.dart';
import 'package:my_notion/features/sync/presentation/cubit/presence_cubit.dart';

/// H4b — PresenceCubit unit tests. Uses bloc_test for state-
/// transition assertions and `fake_async`-style real Timers
/// (cubit uses dart:async Timer; tests wait small real
/// durations to verify TTL behavior).
void main() {
  group('PresenceCubit (H4b)', () {
    group('initial state', () {
      test('starts with an empty cursors map', () {
        final cubit = PresenceCubit();
        addTearDown(cubit.close);
        expect(cubit.state.cursors, isEmpty);
      });
    });

    group('remoteCursorReceived', () {
      const aliceMsg = AwarenessMessage(
        userId: 'alice',
        pageUlid: 'PAGE1',
        cursorIndex: 10,
        color: '#f00',
      );
      const bobMsg = AwarenessMessage(
        userId: 'bob',
        pageUlid: 'PAGE1',
        cursorIndex: 22,
        color: '#0f0',
      );
      const aliceMoved = AwarenessMessage(
        userId: 'alice',
        pageUlid: 'PAGE1',
        cursorIndex: 50,
        color: '#f00',
      );

      blocTest<PresenceCubit, PresenceState>(
        'upserts the entry for a new user',
        build: () => PresenceCubit(),
        act: (c) => c.remoteCursorReceived(aliceMsg),
        expect: () => [
          const PresenceState(cursors: {'alice': aliceMsg}),
        ],
      );

      blocTest<PresenceCubit, PresenceState>(
        'two distinct users coexist in the map',
        build: () => PresenceCubit(),
        act: (c) {
          c.remoteCursorReceived(aliceMsg);
          c.remoteCursorReceived(bobMsg);
        },
        expect: () => [
          const PresenceState(cursors: {'alice': aliceMsg}),
          const PresenceState(
              cursors: {'alice': aliceMsg, 'bob': bobMsg}),
        ],
      );

      blocTest<PresenceCubit, PresenceState>(
        'a second message from the same user replaces the entry',
        build: () => PresenceCubit(),
        act: (c) {
          c.remoteCursorReceived(aliceMsg);
          c.remoteCursorReceived(aliceMoved);
        },
        expect: () => [
          const PresenceState(cursors: {'alice': aliceMsg}),
          const PresenceState(cursors: {'alice': aliceMoved}),
        ],
      );
    });

    group('TTL expiry', () {
      const msg = AwarenessMessage(
        userId: 'alice',
        pageUlid: 'PAGE1',
        cursorIndex: 10,
        color: '#f00',
      );

      blocTest<PresenceCubit, PresenceState>(
        'entry is dropped after the ttl elapses',
        build: () =>
            PresenceCubit(ttl: const Duration(milliseconds: 50)),
        act: (c) => c.remoteCursorReceived(msg),
        wait: const Duration(milliseconds: 100),
        expect: () => [
          const PresenceState(cursors: {'alice': msg}),
          const PresenceState(),
        ],
      );

      blocTest<PresenceCubit, PresenceState>(
        'a fresh message restarts the TTL clock',
        build: () =>
            PresenceCubit(ttl: const Duration(milliseconds: 100)),
        act: (c) async {
          c.remoteCursorReceived(msg);
          await Future<void>.delayed(const Duration(milliseconds: 70));
          // Re-send before the 100ms ttl elapses; entry should
          // survive past the original 100ms mark.
          c.remoteCursorReceived(msg);
          await Future<void>.delayed(const Duration(milliseconds: 50));
          // We're now at 120ms — past the original ttl but only
          // 50ms past the refresh. Entry must still be present.
        },
        wait: const Duration(milliseconds: 10),
        expect: () => [
          // First emit on receive
          const PresenceState(cursors: {'alice': msg}),
          // No second emit during the refresh because the upsert
          // produces an Equatable-equal state. So the next emit
          // we see is after the FINAL ttl elapses (handled by the
          // separate TTL expiry test above).
        ],
      );
    });

    group('clear', () {
      const msg = AwarenessMessage(
        userId: 'alice',
        pageUlid: 'PAGE1',
        cursorIndex: 10,
        color: '#f00',
      );

      blocTest<PresenceCubit, PresenceState>(
        'empties the cursor map and cancels pending TTL timers',
        build: () =>
            PresenceCubit(ttl: const Duration(milliseconds: 100)),
        act: (c) {
          c.remoteCursorReceived(msg);
          c.clear();
        },
        // Wait past the original ttl to prove the timer was
        // cancelled (no extra emit fires from the now-cleared
        // entry).
        wait: const Duration(milliseconds: 150),
        expect: () => [
          const PresenceState(cursors: {'alice': msg}),
          const PresenceState(),
        ],
      );

      blocTest<PresenceCubit, PresenceState>(
        'clear on an empty cubit is a no-op (no extra emit)',
        build: () => PresenceCubit(),
        act: (c) => c.clear(),
        expect: () => <PresenceState>[],
      );
    });

    group('close', () {
      test(
          'pending TTL timers do not fire emits after close (no late callbacks)',
          () async {
        final cubit =
            PresenceCubit(ttl: const Duration(milliseconds: 50));
        cubit.remoteCursorReceived(const AwarenessMessage(
            userId: 'u',
            pageUlid: 'p',
            cursorIndex: 0,
            color: '#000'));
        await cubit.close();
        // Wait past ttl — if the timer fires after close, the cubit
        // would throw "Cannot emit new states after calling close".
        await Future<void>.delayed(const Duration(milliseconds: 80));
        expect(cubit.isClosed, isTrue);
      });
    });
  });
}
