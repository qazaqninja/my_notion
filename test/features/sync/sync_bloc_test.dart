import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/sync/domain/entities/sync_file.dart';
import 'package:my_notion/features/sync/domain/repositories/sync_repository.dart';
import 'package:my_notion/features/sync/presentation/bloc/sync_bloc.dart';
import 'package:my_notion/features/sync/presentation/bloc/sync_event.dart';
import 'package:my_notion/features/sync/presentation/bloc/sync_state.dart';

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
  Future<List<SyncFileSummary>> list({required String token}) async => const [];

  @override
  Future<SyncFileBody?> get({required String token, required String relpath}) async => null;

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

  @override
  Future<bool> delete({required String token, required String relpath}) async => true;
}

void main() {
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
}
