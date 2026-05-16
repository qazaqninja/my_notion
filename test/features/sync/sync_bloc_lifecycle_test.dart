import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/sync/domain/entities/sync_file.dart';
import 'package:my_notion/features/sync/domain/repositories/sync_repository.dart';
import 'package:my_notion/features/sync/presentation/bloc/sync_bloc.dart';
import 'package:my_notion/features/sync/presentation/bloc/sync_event.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// E33 — end-to-end sanity checks on the SyncBloc lifecycle.
///
/// Covers token rotation (logout → re-login with a different user
/// resets every per-account field) and the close() teardown promise
/// (no dangling timers, prefs are clean).
class _LifeRepo implements SyncRepository {
  String? expectedEmail;
  String? expectedToken;
  bool pingReturns = true;
  SyncPutOutcome? putOutcome;
  List<SyncFileSummary> listResponse = const [];

  @override
  Future<String> login({required String email, required String password}) async {
    expectedEmail = email;
    return expectedToken = 'jwt-$email';
  }

  @override
  Future<String> signup({required String email, required String password}) async {
    expectedEmail = email;
    return expectedToken = 'jwt-new-$email';
  }

  @override
  Future<List<SyncFileSummary>> list({required String token}) async {
    return listResponse;
  }

  @override
  Future<SyncFileBody?> get({required String token, required String relpath}) async =>
      null;

  @override
  Future<SyncPutOutcome> put({
    required String token,
    required String relpath,
    required String body,
    String? ifMatch,
  }) async {
    return putOutcome ??
        SyncPutSuccess(
          SyncFileSummary(
            relpath: relpath,
            sha256: 'sha-after-$relpath',
            mtime: DateTime.utc(2026, 5, 17),
          ),
        );
  }

  @override
  Future<bool> delete({required String token, required String relpath}) async => true;

  @override
  Future<bool> ping() async => pingReturns;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SyncBloc lifecycle (E33)', () {
    test('Logout → Login(other email) fully resets per-account state',
        () async {
      final repo = _LifeRepo();
      final bloc = SyncBloc(
        repo: repo,
        // 1 h interval keeps the periodic timer from firing during the
        // test window.
        listPingInterval: const Duration(hours: 1),
      );

      // ── User A logs in, pushes a file, accumulates known-shas.
      bloc.add(const SyncLoginRequested(
        email: 'alice@quill',
        password: 'hunter2',
      ));
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(bloc.state.isAuthed, isTrue);
      expect(bloc.state.token, 'jwt-alice@quill');

      bloc.add(const SyncPushFileRequested(
        relpath: 'a.md',
        body: 'alice-content',
      ));
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(bloc.state.lastPush?.relpath, 'a.md');
      expect(bloc.state.knownShas['a.md'], 'sha-after-a.md');
      expect(bloc.state.pendingPushes, 0);

      // ── Logout snaps the bloc back to default state (E27 +
      // E30 + E20 promises overlap here).
      bloc.add(const SyncLogoutRequested());
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(bloc.state.isAuthed, isFalse);
      expect(bloc.state.token, isNull);
      expect(bloc.state.knownShas, isEmpty);
      expect(bloc.state.lastPush, isNull);
      expect(bloc.state.lastConflict, isNull);
      expect(bloc.state.pendingPushes, 0);

      // ── User B logs in. Old state must NOT leak.
      bloc.add(const SyncLoginRequested(
        email: 'bob@quill',
        password: 'correct-horse',
      ));
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(bloc.state.isAuthed, isTrue);
      expect(bloc.state.token, 'jwt-bob@quill');
      // Alice's knownShas must NOT persist into Bob's session even
      // though no list event has fired yet.
      expect(bloc.state.knownShas['a.md'], isNull);

      await bloc.close();
    });

    test('close() leaves SharedPreferences token intact', () async {
      // Persistence and close() are orthogonal — closing the bloc
      // mid-session shouldn't wipe a logged-in user's saved token.
      SharedPreferences.setMockInitialValues({
        'sync.token': 'jwt-pre-existing',
      });
      final repo = _LifeRepo();
      final bloc = SyncBloc(
        repo: repo,
        listPingInterval: const Duration(hours: 1),
      );
      bloc.add(const SyncRestoreRequested());
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(bloc.state.token, 'jwt-pre-existing');

      await bloc.close();
      final prefs = await SharedPreferences.getInstance();
      // Token survives close() — only an explicit logout clears it.
      expect(prefs.getString('sync.token'), 'jwt-pre-existing');
    });

    test('Token rotation drops the periodic timer and re-arms after re-login',
        () async {
      final repo = _LifeRepo()
        ..listResponse = [
          SyncFileSummary(
            relpath: 'alice.md',
            sha256: 'alice-sha',
            mtime: DateTime.utc(2026, 5, 17),
          ),
        ];
      final bloc = SyncBloc(
        repo: repo,
        // Short interval so we can observe two ticks within the test
        // window without sleeping for minutes.
        listPingInterval: const Duration(milliseconds: 40),
      );

      bloc.add(const SyncLoginRequested(
        email: 'alice@quill',
        password: 'x',
      ));
      await Future<void>.delayed(const Duration(milliseconds: 120));
      // At least one tick should have fired — alice's relpath landed
      // in knownShas via the listing.
      expect(bloc.state.knownShas['alice.md'], 'alice-sha');

      bloc.add(const SyncLogoutRequested());
      await Future<void>.delayed(const Duration(milliseconds: 80));
      // Post-logout: tracker empty, no more lists firing.
      expect(bloc.state.knownShas, isEmpty);

      // Re-login as Bob with a different listing — Alice's relpath
      // must NOT linger, and Bob's must populate.
      repo.listResponse = [
        SyncFileSummary(
          relpath: 'bob.md',
          sha256: 'bob-sha',
          mtime: DateTime.utc(2026, 5, 17),
        ),
      ];
      bloc.add(const SyncLoginRequested(
        email: 'bob@quill',
        password: 'y',
      ));
      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(bloc.state.token, 'jwt-bob@quill');
      expect(bloc.state.knownShas['alice.md'], isNull);
      expect(bloc.state.knownShas['bob.md'], 'bob-sha');

      await bloc.close();
    });
  });
}
