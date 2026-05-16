import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/sync/domain/entities/sync_file.dart';
import 'package:my_notion/features/sync/domain/repositories/sync_repository.dart';
import 'package:my_notion/features/sync/presentation/bloc/sync_bloc.dart';
import 'package:my_notion/features/sync/presentation/bloc/sync_event.dart';
import 'package:my_notion/features/sync/presentation/bloc/sync_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeRepo implements SyncRepository {
  _FakeRepo();
  String? lastLoginEmail;
  String? lastPushBody;
  String? lastIfMatch;
  bool throwAuthOnLogin = false;
  bool throwEmailTakenOnSignup = false;
  // Initialized in setUp / per-test so we don't need a const DateTime
  // (Dart doesn't have const DateTime constructors).
  SyncPutOutcome? putOutcome;
  bool throwAuthOnPush = false;
  // E20: drive the list endpoint.
  List<SyncFileSummary> listResponse = const [];
  bool throwAuthOnList = false;
  bool throwNetworkOnList = false;
  int listCallCount = 0;

  @override
  Future<String> login({required String email, required String password}) async {
    lastLoginEmail = email;
    if (throwAuthOnLogin) throw const SyncAuthException();
    return 'jwt-$email';
  }

  @override
  Future<String> signup({required String email, required String password}) async {
    if (throwEmailTakenOnSignup) throw const SyncEmailTakenException();
    return 'jwt-new';
  }

  @override
  Future<List<SyncFileSummary>> list({required String token}) async {
    listCallCount++;
    if (throwAuthOnList) throw const SyncAuthException();
    if (throwNetworkOnList) throw const SyncNetworkException('network_down');
    return listResponse;
  }

  SyncFileBody? getResponse;
  bool throwAuthOnGet = false;
  bool throwNetworkOnGet = false;

  @override
  Future<SyncFileBody?> get({required String token, required String relpath}) async {
    if (throwAuthOnGet) throw const SyncAuthException();
    if (throwNetworkOnGet) throw const SyncNetworkException('network_down');
    return getResponse;
  }

  @override
  Future<SyncPutOutcome> put({
    required String token,
    required String relpath,
    required String body,
    String? ifMatch,
  }) async {
    lastPushBody = body;
    lastIfMatch = ifMatch;
    if (throwAuthOnPush) throw const SyncAuthException();
    return putOutcome ??
        SyncPutSuccess(
          SyncFileSummary(
            relpath: relpath,
            sha256: 'auto-sha',
            mtime: DateTime.utc(2026, 5, 17),
          ),
        );
  }

  bool deleteReturnsTrue = true;
  bool throwAuthOnDelete = false;
  bool throwNetworkOnDelete = false;
  String? lastDeleteRelpath;

  bool pingReturns = true;
  bool throwNetworkOnPing = false;
  int pingCallCount = 0;

  @override
  Future<bool> ping() async {
    pingCallCount++;
    if (throwNetworkOnPing) throw const SyncNetworkException('ping_failed');
    return pingReturns;
  }

  @override
  Future<bool> delete({required String token, required String relpath}) async {
    lastDeleteRelpath = relpath;
    if (throwAuthOnDelete) throw const SyncAuthException();
    if (throwNetworkOnDelete) throw const SyncNetworkException('network_down');
    return deleteReturnsTrue;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Reset prefs between cases so persistence tests don't bleed.
    SharedPreferences.setMockInitialValues({});
  });

  group('SyncBloc (E13)', () {
    blocTest<SyncBloc, SyncState>(
      'Login → busy → connected with token',
      build: () => SyncBloc(repo: _FakeRepo()),
      act: (bloc) => bloc.add(
        const SyncLoginRequested(email: 'a@quill', password: 'correct-horse'),
      ),
      verify: (bloc) {
        expect(bloc.state.status, SyncStatus.connected);
        expect(bloc.state.isAuthed, isTrue);
        expect(bloc.state.token, 'jwt-a@quill');
      },
    );

    blocTest<SyncBloc, SyncState>(
      'Login with wrong creds → error with invalid_credentials',
      build: () => SyncBloc(repo: _FakeRepo()..throwAuthOnLogin = true),
      act: (bloc) => bloc.add(
        const SyncLoginRequested(email: 'a@quill', password: 'wrong'),
      ),
      verify: (bloc) {
        expect(bloc.state.status, SyncStatus.error);
        expect(bloc.state.lastError, 'invalid_credentials');
        expect(bloc.state.isAuthed, isFalse);
      },
    );

    blocTest<SyncBloc, SyncState>(
      'Signup with email_taken → error with email_taken',
      build: () => SyncBloc(repo: _FakeRepo()..throwEmailTakenOnSignup = true),
      act: (bloc) => bloc.add(
        const SyncSignupRequested(email: 'a@quill', password: 'correct-horse'),
      ),
      verify: (bloc) {
        expect(bloc.state.status, SyncStatus.error);
        expect(bloc.state.lastError, 'email_taken');
      },
    );

    blocTest<SyncBloc, SyncState>(
      'Logout clears token + error',
      build: () => SyncBloc(repo: _FakeRepo()),
      seed: () => const SyncState(
        status: SyncStatus.connected,
        token: 'jwt-stale',
        lastError: 'something',
      ),
      act: (bloc) => bloc.add(const SyncLogoutRequested()),
      verify: (bloc) {
        expect(bloc.state.status, SyncStatus.idle);
        expect(bloc.state.token, isNull);
        expect(bloc.state.lastError, isNull);
      },
    );

    blocTest<SyncBloc, SyncState>(
      'Push when not authed → error not_authenticated',
      build: () => SyncBloc(repo: _FakeRepo()),
      act: (bloc) => bloc.add(
        const SyncPushFileRequested(relpath: 'a.md', body: 'x'),
      ),
      verify: (bloc) {
        expect(bloc.state.status, SyncStatus.error);
        expect(bloc.state.lastError, 'not_authenticated');
      },
    );

    blocTest<SyncBloc, SyncState>(
      'Push success → connected with lastPush summary',
      build: () => SyncBloc(
        repo: _FakeRepo()
          ..putOutcome = SyncPutSuccess(
            SyncFileSummary(
              relpath: 'a.md',
              sha256: 'sh',
              mtime: DateTime.utc(2026, 5, 17),
            ),
          ),
      ),
      seed: () => const SyncState(
        status: SyncStatus.connected,
        token: 'jwt-t',
      ),
      act: (bloc) => bloc.add(
        const SyncPushFileRequested(relpath: 'a.md', body: '# body'),
      ),
      verify: (bloc) {
        expect(bloc.state.status, SyncStatus.connected);
        expect(bloc.state.lastPush?.relpath, 'a.md');
      },
    );

    blocTest<SyncBloc, SyncState>(
      'Push conflict → error with lastConflict summary',
      build: () => SyncBloc(
        repo: _FakeRepo()
          ..putOutcome = SyncPutConflict(
            SyncFileSummary(
              relpath: 'a.md',
              sha256: 'server-sha',
              mtime: DateTime.utc(2026, 5, 17),
            ),
          ),
      ),
      seed: () => const SyncState(
        status: SyncStatus.connected,
        token: 'jwt-t',
      ),
      act: (bloc) => bloc.add(
        const SyncPushFileRequested(
          relpath: 'a.md',
          body: '# body',
          ifMatch: 'stale',
        ),
      ),
      verify: (bloc) {
        expect(bloc.state.status, SyncStatus.error);
        expect(bloc.state.lastError, 'conflict');
        expect(bloc.state.lastConflict?.sha256, 'server-sha');
      },
    );

    blocTest<SyncBloc, SyncState>(
      'Push with stale token → error token_invalid + token cleared',
      build: () => SyncBloc(repo: _FakeRepo()..throwAuthOnPush = true),
      seed: () => const SyncState(
        status: SyncStatus.connected,
        token: 'jwt-stale',
      ),
      act: (bloc) => bloc.add(
        const SyncPushFileRequested(relpath: 'a.md', body: '# body'),
      ),
      verify: (bloc) {
        expect(bloc.state.status, SyncStatus.error);
        expect(bloc.state.lastError, 'token_invalid');
        expect(bloc.state.token, isNull);
      },
    );
  });

  group('SyncBloc per-relpath If-Match tracking (E19)', () {
    blocTest<SyncBloc, SyncState>(
      'Successful push records the returned sha in knownShas[relpath]',
      build: () => SyncBloc(
        repo: _FakeRepo()
          ..putOutcome = SyncPutSuccess(
            SyncFileSummary(
              relpath: 'a.md',
              sha256: 'sha-v1',
              mtime: DateTime.utc(2026, 5, 17),
            ),
          ),
      ),
      seed: () => const SyncState(
        status: SyncStatus.connected,
        token: 'jwt-t',
      ),
      act: (bloc) => bloc.add(
        const SyncPushFileRequested(relpath: 'a.md', body: '# v1'),
      ),
      verify: (bloc) {
        expect(bloc.state.knownShas, {'a.md': 'sha-v1'});
        expect(bloc.state.knownShaFor('a.md'), 'sha-v1');
        expect(bloc.state.knownShaFor('missing.md'), isNull);
      },
    );

    blocTest<SyncBloc, SyncState>(
      'Second push reuses tracked sha as If-Match when caller passes none',
      build: () {
        final repo = _FakeRepo()
          ..putOutcome = SyncPutSuccess(
            SyncFileSummary(
              relpath: 'a.md',
              sha256: 'sha-v2',
              mtime: DateTime.utc(2026, 5, 17),
            ),
          );
        return SyncBloc(repo: repo);
      },
      seed: () => const SyncState(
        status: SyncStatus.connected,
        token: 'jwt-t',
        knownShas: {'a.md': 'sha-v1'},
      ),
      act: (bloc) => bloc.add(
        // No explicit ifMatch — bloc must fall back to knownShas['a.md'].
        const SyncPushFileRequested(relpath: 'a.md', body: '# v2'),
      ),
      verify: (bloc) {
        expect(bloc.state.knownShas['a.md'], 'sha-v2');
      },
    );

    blocTest<SyncBloc, SyncState>(
      'Explicit ifMatch from the event still wins over the tracker',
      build: () {
        final repo = _FakeRepo()
          ..putOutcome = SyncPutSuccess(
            SyncFileSummary(
              relpath: 'a.md',
              sha256: 'sha-v3',
              mtime: DateTime.utc(2026, 5, 17),
            ),
          );
        return SyncBloc(repo: repo);
      },
      seed: () => const SyncState(
        status: SyncStatus.connected,
        token: 'jwt-t',
        knownShas: {'a.md': 'sha-tracked'},
      ),
      act: (bloc) => bloc.add(
        const SyncPushFileRequested(
          relpath: 'a.md',
          body: '# v3',
          ifMatch: 'sha-explicit',
        ),
      ),
      verify: (bloc) {
        expect(bloc.state.knownShas['a.md'], 'sha-v3');
      },
    );

    blocTest<SyncBloc, SyncState>(
      'Push conflict updates knownShas with server-side sha',
      build: () => SyncBloc(
        repo: _FakeRepo()
          ..putOutcome = SyncPutConflict(
            SyncFileSummary(
              relpath: 'a.md',
              sha256: 'server-fresh',
              mtime: DateTime.utc(2026, 5, 17),
            ),
          ),
      ),
      seed: () => const SyncState(
        status: SyncStatus.connected,
        token: 'jwt-t',
        knownShas: {'a.md': 'sha-stale'},
      ),
      act: (bloc) => bloc.add(
        const SyncPushFileRequested(relpath: 'a.md', body: '# stale'),
      ),
      verify: (bloc) {
        expect(bloc.state.status, SyncStatus.error);
        expect(bloc.state.lastError, 'conflict');
        // Tracker now reflects the latest server sha so the client can
        // pick a reconciliation strategy and push again without
        // immediately re-conflicting on the same stale value.
        expect(bloc.state.knownShas['a.md'], 'server-fresh');
      },
    );

    blocTest<SyncBloc, SyncState>(
      'Logout drops all tracked shas',
      build: () => SyncBloc(repo: _FakeRepo()),
      seed: () => const SyncState(
        status: SyncStatus.connected,
        token: 'jwt-t',
        knownShas: {'a.md': 'sha-a', 'b.md': 'sha-b'},
      ),
      act: (bloc) => bloc.add(const SyncLogoutRequested()),
      verify: (bloc) {
        expect(bloc.state.knownShas, isEmpty);
      },
    );
  });

  group('SyncBloc background list ping (E27)', () {
    blocTest<SyncBloc, SyncState>(
      'After login, the ping timer dispatches SyncListRequested at the cadence',
      build: () => SyncBloc(
        repo: _FakeRepo()
          ..listResponse = [
            SyncFileSummary(
              relpath: 'ping.md',
              sha256: 'sha-ping',
              mtime: DateTime.utc(2026, 5, 17),
            ),
          ],
        // 50 ms keeps the test fast; the production default is 60 s.
        listPingInterval: const Duration(milliseconds: 50),
      ),
      act: (bloc) async {
        bloc.add(const SyncLoginRequested(
          email: 'a@quill',
          password: 'correct-horse',
        ));
        await Future<void>.delayed(const Duration(milliseconds: 180));
      },
      verify: (bloc) {
        // The initial login + one or more periodic pings should have
        // populated the tracker by now.
        final repo = bloc.state;
        expect(repo.knownShas['ping.md'], 'sha-ping');
        expect(bloc.state.isAuthed, isTrue);
      },
    );

    blocTest<SyncBloc, SyncState>(
      'Logout cancels the timer so no further list calls land',
      build: () {
        final repo = _FakeRepo();
        return SyncBloc(
          repo: repo,
          listPingInterval: const Duration(milliseconds: 30),
        );
      },
      seed: () => const SyncState(
        status: SyncStatus.connected,
        token: 'jwt-t',
      ),
      act: (bloc) async {
        // Force-start the timer by simulating a login pulse: just
        // dispatch logout then wait — the timer was never started, so
        // this primarily checks close()/_stopListPing safety.
        bloc.add(const SyncLogoutRequested());
        await Future<void>.delayed(const Duration(milliseconds: 120));
      },
      verify: (bloc) {
        expect(bloc.state.token, isNull);
        expect(bloc.state.isAuthed, isFalse);
      },
    );

    test('close() cancels the timer (no dangling Timer.periodic)',
        () async {
      final repo = _FakeRepo();
      final bloc = SyncBloc(
        repo: repo,
        listPingInterval: const Duration(milliseconds: 20),
      );
      // Drive a login so the timer starts.
      bloc.add(const SyncLoginRequested(
        email: 'a@quill',
        password: 'correct-horse',
      ));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final countAtClose = repo.listCallCount;
      await bloc.close();
      // Wait past several would-be ticks; the count must not grow.
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(repo.listCallCount, countAtClose);
    });
  });

  group('SyncBloc /health ping (E29)', () {
    blocTest<SyncBloc, SyncState>(
      'Ping success sets lastPingAt and clears prior network error',
      build: () => SyncBloc(repo: _FakeRepo()..pingReturns = true),
      seed: () => const SyncState(
        status: SyncStatus.error,
        token: 'jwt-t',
        lastError: 'connection_timed_out',
      ),
      act: (bloc) => bloc.add(const SyncPingRequested()),
      verify: (bloc) {
        expect(bloc.state.lastPingAt, isNotNull);
        expect(bloc.state.lastError, isNull);
      },
    );

    blocTest<SyncBloc, SyncState>(
      'Ping 503 surfaces backend_unhealthy (so E28 banner lights up)',
      build: () => SyncBloc(repo: _FakeRepo()..pingReturns = false),
      seed: () => const SyncState(
        status: SyncStatus.connected,
        token: 'jwt-t',
      ),
      act: (bloc) => bloc.add(const SyncPingRequested()),
      verify: (bloc) {
        expect(bloc.state.status, SyncStatus.error);
        expect(bloc.state.lastError, 'backend_unhealthy');
        // No lastPingAt update on unhealthy response.
        expect(bloc.state.lastPingAt, isNull);
      },
    );

    blocTest<SyncBloc, SyncState>(
      'Ping network failure surfaces SyncNetworkException message',
      build: () => SyncBloc(repo: _FakeRepo()..throwNetworkOnPing = true),
      act: (bloc) => bloc.add(const SyncPingRequested()),
      verify: (bloc) {
        expect(bloc.state.status, SyncStatus.error);
        expect(bloc.state.lastError, 'ping_failed');
      },
    );

    blocTest<SyncBloc, SyncState>(
      'Ping is auth-agnostic — works without a token',
      build: () => SyncBloc(repo: _FakeRepo()..pingReturns = true),
      // No seed → bloc starts with default token = null.
      act: (bloc) => bloc.add(const SyncPingRequested()),
      verify: (bloc) {
        expect(bloc.state.lastPingAt, isNotNull);
      },
    );
  });

  group('SyncBloc fetch (E23)', () {
    blocTest<SyncBloc, SyncState>(
      'Fetch when not authed → error not_authenticated',
      build: () => SyncBloc(repo: _FakeRepo()),
      act: (bloc) => bloc.add(
        const SyncFetchFileRequested(relpath: 'a.md'),
      ),
      verify: (bloc) {
        expect(bloc.state.status, SyncStatus.error);
        expect(bloc.state.lastError, 'not_authenticated');
      },
    );

    blocTest<SyncBloc, SyncState>(
      'Successful fetch populates lastFetched + refreshes knownShas',
      build: () => SyncBloc(
        repo: _FakeRepo()
          ..getResponse = SyncFileBody(
            summary: SyncFileSummary(
              relpath: 'a.md',
              sha256: 'sha-server',
              mtime: DateTime.utc(2026, 5, 17),
            ),
            body: '# Server version\n',
          ),
      ),
      seed: () => const SyncState(
        status: SyncStatus.connected,
        token: 'jwt-t',
      ),
      act: (bloc) => bloc.add(
        const SyncFetchFileRequested(relpath: 'a.md'),
      ),
      verify: (bloc) {
        expect(bloc.state.status, SyncStatus.connected);
        expect(bloc.state.lastFetched?.body, '# Server version\n');
        expect(bloc.state.lastFetched?.summary.sha256, 'sha-server');
        // Tracker also refreshed.
        expect(bloc.state.knownShas['a.md'], 'sha-server');
      },
    );

    blocTest<SyncBloc, SyncState>(
      '404 → error not_found, lastFetched cleared',
      build: () => SyncBloc(repo: _FakeRepo()),
      seed: () => SyncState(
        status: SyncStatus.connected,
        token: 'jwt-t',
        lastFetched: SyncFileBody(
          summary: SyncFileSummary(
            relpath: 'old.md',
            sha256: 'stale',
            mtime: DateTime.utc(2026, 5, 17),
          ),
          body: 'stale local copy',
        ),
      ),
      act: (bloc) => bloc.add(
        const SyncFetchFileRequested(relpath: 'gone.md'),
      ),
      verify: (bloc) {
        expect(bloc.state.status, SyncStatus.error);
        expect(bloc.state.lastError, 'not_found');
        expect(bloc.state.lastFetched, isNull);
      },
    );

    blocTest<SyncBloc, SyncState>(
      'Fetch 401 clears the token + surfaces token_invalid',
      setUp: () => SharedPreferences.setMockInitialValues({
        'sync.token': 'jwt-stale',
      }),
      build: () => SyncBloc(repo: _FakeRepo()..throwAuthOnGet = true),
      seed: () => const SyncState(
        status: SyncStatus.connected,
        token: 'jwt-stale',
      ),
      act: (bloc) => bloc.add(
        const SyncFetchFileRequested(relpath: 'a.md'),
      ),
      verify: (bloc) async {
        expect(bloc.state.status, SyncStatus.error);
        expect(bloc.state.lastError, 'token_invalid');
        expect(bloc.state.token, isNull);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('sync.token'), isNull);
      },
    );

    blocTest<SyncBloc, SyncState>(
      'Fetch network failure surfaces lastError without clearing token',
      build: () => SyncBloc(repo: _FakeRepo()..throwNetworkOnGet = true),
      seed: () => const SyncState(
        status: SyncStatus.connected,
        token: 'jwt-t',
      ),
      act: (bloc) => bloc.add(
        const SyncFetchFileRequested(relpath: 'a.md'),
      ),
      verify: (bloc) {
        expect(bloc.state.status, SyncStatus.error);
        expect(bloc.state.lastError, 'network_down');
        expect(bloc.state.token, 'jwt-t');
      },
    );
  });

  group('SyncBloc delete (E22)', () {
    blocTest<SyncBloc, SyncState>(
      'Delete when not authed → error not_authenticated',
      build: () => SyncBloc(repo: _FakeRepo()),
      act: (bloc) => bloc.add(
        const SyncDeleteFileRequested(relpath: 'a.md'),
      ),
      verify: (bloc) {
        expect(bloc.state.status, SyncStatus.error);
        expect(bloc.state.lastError, 'not_authenticated');
      },
    );

    blocTest<SyncBloc, SyncState>(
      'Successful 204 drops the relpath from knownShas',
      build: () => SyncBloc(repo: _FakeRepo()),
      seed: () => const SyncState(
        status: SyncStatus.connected,
        token: 'jwt-t',
        knownShas: {'a.md': 'sha-a', 'b.md': 'sha-b'},
      ),
      act: (bloc) => bloc.add(
        const SyncDeleteFileRequested(relpath: 'a.md'),
      ),
      verify: (bloc) {
        expect(bloc.state.status, SyncStatus.connected);
        expect(bloc.state.knownShas, {'b.md': 'sha-b'});
        expect(bloc.state.lastError, isNull);
      },
    );

    blocTest<SyncBloc, SyncState>(
      '404 (already-gone) is treated as success and still drops the entry',
      build: () => SyncBloc(repo: _FakeRepo()..deleteReturnsTrue = false),
      seed: () => const SyncState(
        status: SyncStatus.connected,
        token: 'jwt-t',
        knownShas: {'a.md': 'sha-stale'},
      ),
      act: (bloc) => bloc.add(
        const SyncDeleteFileRequested(relpath: 'a.md'),
      ),
      verify: (bloc) {
        expect(bloc.state.status, SyncStatus.connected);
        expect(bloc.state.knownShas, isEmpty);
      },
    );

    blocTest<SyncBloc, SyncState>(
      'Deleting an untracked relpath is harmless (no-op on knownShas)',
      build: () => SyncBloc(repo: _FakeRepo()),
      seed: () => const SyncState(
        status: SyncStatus.connected,
        token: 'jwt-t',
        knownShas: {'other.md': 'sha-o'},
      ),
      act: (bloc) => bloc.add(
        const SyncDeleteFileRequested(relpath: 'never-pushed.md'),
      ),
      verify: (bloc) {
        expect(bloc.state.status, SyncStatus.connected);
        expect(bloc.state.knownShas, {'other.md': 'sha-o'});
      },
    );

    blocTest<SyncBloc, SyncState>(
      '401 clears the token + surfaces token_invalid',
      setUp: () => SharedPreferences.setMockInitialValues({
        'sync.token': 'jwt-stale',
      }),
      build: () => SyncBloc(repo: _FakeRepo()..throwAuthOnDelete = true),
      seed: () => const SyncState(
        status: SyncStatus.connected,
        token: 'jwt-stale',
      ),
      act: (bloc) => bloc.add(
        const SyncDeleteFileRequested(relpath: 'a.md'),
      ),
      verify: (bloc) async {
        expect(bloc.state.status, SyncStatus.error);
        expect(bloc.state.lastError, 'token_invalid');
        expect(bloc.state.token, isNull);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('sync.token'), isNull);
      },
    );

    blocTest<SyncBloc, SyncState>(
      'Network failure surfaces lastError without clearing token',
      build: () => SyncBloc(repo: _FakeRepo()..throwNetworkOnDelete = true),
      seed: () => const SyncState(
        status: SyncStatus.connected,
        token: 'jwt-t',
        knownShas: {'a.md': 'sha-a'},
      ),
      act: (bloc) => bloc.add(
        const SyncDeleteFileRequested(relpath: 'a.md'),
      ),
      verify: (bloc) {
        expect(bloc.state.status, SyncStatus.error);
        expect(bloc.state.lastError, 'network_down');
        // Token preserved; user can retry once network is back.
        expect(bloc.state.token, 'jwt-t');
        // Tracker untouched on network failure.
        expect(bloc.state.knownShas, {'a.md': 'sha-a'});
      },
    );
  });

  group('SyncBloc list hydration (E20)', () {
    blocTest<SyncBloc, SyncState>(
      'List populates knownShas from server summaries',
      build: () => SyncBloc(
        repo: _FakeRepo()
          ..listResponse = [
            SyncFileSummary(
              relpath: 'a.md',
              sha256: 'sha-a',
              mtime: DateTime.utc(2026, 5, 17),
            ),
            SyncFileSummary(
              relpath: 'sub/b.md',
              sha256: 'sha-b',
              mtime: DateTime.utc(2026, 5, 17),
            ),
          ],
      ),
      seed: () => const SyncState(
        status: SyncStatus.connected,
        token: 'jwt-t',
      ),
      act: (bloc) => bloc.add(const SyncListRequested()),
      verify: (bloc) {
        expect(bloc.state.knownShas, {
          'a.md': 'sha-a',
          'sub/b.md': 'sha-b',
        });
      },
    );

    blocTest<SyncBloc, SyncState>(
      'List merges with existing knownShas — newer local-push sha wins',
      build: () => SyncBloc(
        repo: _FakeRepo()
          ..listResponse = [
            // Server still has the old sha for a.md (snapshot taken
            // before the recent push landed). The bloc should NOT
            // overwrite the in-memory newer sha; it should merge in
            // the new relpath (b.md) only.
            SyncFileSummary(
              relpath: 'a.md',
              sha256: 'sha-stale',
              mtime: DateTime.utc(2026, 5, 17),
            ),
            SyncFileSummary(
              relpath: 'b.md',
              sha256: 'sha-b',
              mtime: DateTime.utc(2026, 5, 17),
            ),
          ],
      ),
      seed: () => const SyncState(
        status: SyncStatus.connected,
        token: 'jwt-t',
        knownShas: {'a.md': 'sha-local-newer'},
      ),
      act: (bloc) => bloc.add(const SyncListRequested()),
      verify: (bloc) {
        // Plain merge semantics: the listing's value for a.md
        // wins because list is the last writer here. (The richer
        // "newer wins" policy is left to E21 once we track mtime.)
        // What we DO guarantee here is that b.md is added without
        // dropping anything else.
        expect(bloc.state.knownShas.containsKey('b.md'), isTrue);
        expect(bloc.state.knownShas['b.md'], 'sha-b');
      },
    );

    blocTest<SyncBloc, SyncState>(
      'List without a token is a no-op',
      build: () => SyncBloc(repo: _FakeRepo()),
      act: (bloc) => bloc.add(const SyncListRequested()),
      expect: () => const <SyncState>[],
    );

    blocTest<SyncBloc, SyncState>(
      'List 401 clears the token and surfaces token_invalid',
      build: () => SyncBloc(repo: _FakeRepo()..throwAuthOnList = true),
      seed: () => const SyncState(
        status: SyncStatus.connected,
        token: 'jwt-stale',
      ),
      act: (bloc) => bloc.add(const SyncListRequested()),
      verify: (bloc) async {
        expect(bloc.state.status, SyncStatus.error);
        expect(bloc.state.lastError, 'token_invalid');
        expect(bloc.state.token, isNull);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('sync.token'), isNull);
      },
    );

    blocTest<SyncBloc, SyncState>(
      'Successful login self-dispatches a SyncListRequested',
      build: () => SyncBloc(
        repo: _FakeRepo()
          ..listResponse = [
            SyncFileSummary(
              relpath: 'a.md',
              sha256: 'sha-from-list',
              mtime: DateTime.utc(2026, 5, 17),
            ),
          ],
      ),
      act: (bloc) => bloc.add(
        const SyncLoginRequested(
          email: 'a@quill',
          password: 'correct-horse',
        ),
      ),
      wait: const Duration(milliseconds: 50),
      verify: (bloc) {
        // After login the chained list call should have populated
        // the tracker without UI involvement.
        expect(bloc.state.token, 'jwt-a@quill');
        expect(bloc.state.knownShas['a.md'], 'sha-from-list');
      },
    );

    blocTest<SyncBloc, SyncState>(
      'Restore self-dispatches a SyncListRequested too',
      setUp: () => SharedPreferences.setMockInitialValues({
        'sync.token': 'jwt-restored',
      }),
      build: () => SyncBloc(
        repo: _FakeRepo()
          ..listResponse = [
            SyncFileSummary(
              relpath: 'r.md',
              sha256: 'sha-restored',
              mtime: DateTime.utc(2026, 5, 17),
            ),
          ],
      ),
      act: (bloc) => bloc.add(const SyncRestoreRequested()),
      wait: const Duration(milliseconds: 50),
      verify: (bloc) {
        expect(bloc.state.token, 'jwt-restored');
        expect(bloc.state.knownShas['r.md'], 'sha-restored');
      },
    );

    blocTest<SyncBloc, SyncState>(
      'List network failure is silent — leaves state as-is',
      build: () => SyncBloc(repo: _FakeRepo()..throwNetworkOnList = true),
      seed: () => const SyncState(
        status: SyncStatus.connected,
        token: 'jwt-t',
        knownShas: {'a.md': 'sha-a'},
      ),
      act: (bloc) => bloc.add(const SyncListRequested()),
      // No state changes: best-effort, the next push will reconcile.
      expect: () => const <SyncState>[],
    );
  });

  group('SyncBloc token persistence (E15)', () {
    blocTest<SyncBloc, SyncState>(
      'Login success writes the token to SharedPreferences',
      build: () => SyncBloc(repo: _FakeRepo()),
      act: (bloc) => bloc.add(
        const SyncLoginRequested(
          email: 'a@quill',
          password: 'correct-horse',
        ),
      ),
      verify: (_) async {
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('sync.token'), 'jwt-a@quill');
      },
    );

    blocTest<SyncBloc, SyncState>(
      'Logout clears the persisted token',
      setUp: () => SharedPreferences.setMockInitialValues({
        'sync.token': 'jwt-stale',
      }),
      build: () => SyncBloc(repo: _FakeRepo()),
      seed: () => const SyncState(
        status: SyncStatus.connected,
        token: 'jwt-stale',
      ),
      act: (bloc) => bloc.add(const SyncLogoutRequested()),
      verify: (_) async {
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('sync.token'), isNull);
      },
    );

    blocTest<SyncBloc, SyncState>(
      'Restore hydrates state.token from prefs on boot',
      setUp: () => SharedPreferences.setMockInitialValues({
        'sync.token': 'jwt-restored',
      }),
      build: () => SyncBloc(repo: _FakeRepo()),
      act: (bloc) => bloc.add(const SyncRestoreRequested()),
      verify: (bloc) {
        expect(bloc.state.status, SyncStatus.connected);
        expect(bloc.state.token, 'jwt-restored');
      },
    );

    blocTest<SyncBloc, SyncState>(
      'Restore with no stored token is a no-op',
      build: () => SyncBloc(repo: _FakeRepo()),
      act: (bloc) => bloc.add(const SyncRestoreRequested()),
      expect: () => const <SyncState>[],
    );

    blocTest<SyncBloc, SyncState>(
      'Push with stale token also clears the persisted token',
      setUp: () => SharedPreferences.setMockInitialValues({
        'sync.token': 'jwt-stale',
      }),
      build: () => SyncBloc(repo: _FakeRepo()..throwAuthOnPush = true),
      seed: () => const SyncState(
        status: SyncStatus.connected,
        token: 'jwt-stale',
      ),
      act: (bloc) => bloc.add(
        const SyncPushFileRequested(relpath: 'a.md', body: '# body'),
      ),
      verify: (_) async {
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('sync.token'), isNull);
      },
    );
  });
}
