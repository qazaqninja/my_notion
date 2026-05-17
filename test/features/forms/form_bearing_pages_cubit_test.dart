import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:my_notion/features/forms/domain/entities/form_bearing_page.dart';
import 'package:my_notion/features/forms/domain/repositories/form_bearing_pages_repository.dart';
import 'package:my_notion/features/forms/presentation/cubit/form_bearing_pages_cubit.dart';

class _MockRepo extends Mock implements FormBearingPagesRepository {}

void main() {
  group('FormBearingPagesCubit', () {
    late FormBearingPagesRepository repo;

    setUp(() {
      repo = _MockRepo();
    });

    group('initial state', () {
      test('is FormBearingPagesState.initial()', () {
        final cubit = FormBearingPagesCubit(repo: repo);
        expect(cubit.state.status, FormBearingPagesStatus.initial);
        expect(cubit.state.pages, isEmpty);
        expect(cubit.state.lastError, isNull);
        cubit.close();
      });
    });

    group('load()', () {
      const pageA = FormBearingPage(
        ulid: '01HX0V0000000000000000000A',
        title: 'Alpha',
        relativePath: 'A.md',
        formsRef: 'true',
      );
      const pageB = FormBearingPage(
        ulid: '01HX0V0000000000000000000B',
        title: 'Beta',
        relativePath: 'B.md',
        formsRef: 'Bugs.yaml',
      );

      blocTest<FormBearingPagesCubit, FormBearingPagesState>(
        'emits [loading, success(pages)] on a successful load',
        build: () {
          when(repo.loadAll).thenAnswer((_) async => const [pageA, pageB]);
          return FormBearingPagesCubit(repo: repo);
        },
        act: (cubit) => cubit.load(),
        expect: () => [
          const FormBearingPagesState(
            status: FormBearingPagesStatus.loading,
          ),
          const FormBearingPagesState(
            status: FormBearingPagesStatus.success,
            pages: [pageA, pageB],
          ),
        ],
        verify: (_) => verify(repo.loadAll).called(1),
      );

      blocTest<FormBearingPagesCubit, FormBearingPagesState>(
        'success → empty list when the vault has no form-bearing pages',
        build: () {
          when(repo.loadAll).thenAnswer((_) async => const []);
          return FormBearingPagesCubit(repo: repo);
        },
        act: (cubit) => cubit.load(),
        expect: () => [
          const FormBearingPagesState(
            status: FormBearingPagesStatus.loading,
          ),
          const FormBearingPagesState(
            status: FormBearingPagesStatus.success,
          ),
        ],
      );

      blocTest<FormBearingPagesCubit, FormBearingPagesState>(
        'emits [loading, failure(message)] when the repo throws',
        build: () {
          when(repo.loadAll).thenThrow(
            const FormBearingPagesLoadException('disk read failed'),
          );
          return FormBearingPagesCubit(repo: repo);
        },
        act: (cubit) => cubit.load(),
        expect: () => [
          const FormBearingPagesState(
            status: FormBearingPagesStatus.loading,
          ),
          const FormBearingPagesState(
            status: FormBearingPagesStatus.failure,
            lastError: 'disk read failed',
          ),
        ],
      );

      blocTest<FormBearingPagesCubit, FormBearingPagesState>(
        'a fresh load after a failure clears lastError on the way through',
        build: () {
          var firstCall = true;
          when(repo.loadAll).thenAnswer((_) async {
            if (firstCall) {
              firstCall = false;
              throw const FormBearingPagesLoadException('boom');
            }
            return const [pageA];
          });
          return FormBearingPagesCubit(repo: repo);
        },
        act: (cubit) async {
          await cubit.load();
          await cubit.load();
        },
        // Sequence: loading → failure → loading (lastError cleared) →
        // success.
        expect: () => [
          const FormBearingPagesState(
            status: FormBearingPagesStatus.loading,
          ),
          const FormBearingPagesState(
            status: FormBearingPagesStatus.failure,
            lastError: 'boom',
          ),
          const FormBearingPagesState(
            status: FormBearingPagesStatus.loading,
          ),
          const FormBearingPagesState(
            status: FormBearingPagesStatus.success,
            pages: [pageA],
          ),
        ],
      );

      blocTest<FormBearingPagesCubit, FormBearingPagesState>(
        'double-fire while a load is in flight is dropped (BL-10 guard)',
        build: () {
          // Slow repo: completes only after both load() calls have been
          // dispatched. The second call must early-return without
          // emitting a second loading state OR calling the repo twice.
          when(repo.loadAll).thenAnswer(
            (_) => Future<List<FormBearingPage>>.delayed(
              const Duration(milliseconds: 10),
              () => const [pageA],
            ),
          );
          return FormBearingPagesCubit(repo: repo);
        },
        act: (cubit) {
          // ignore: unawaited_futures — intentional fire-and-forget so
          // the second load() races the first.
          cubit.load();
          return cubit.load();
        },
        // Wait past the 10 ms repo delay so the success emit lands
        // before blocTest snapshots the stream.
        wait: const Duration(milliseconds: 50),
        expect: () => [
          const FormBearingPagesState(
            status: FormBearingPagesStatus.loading,
          ),
          const FormBearingPagesState(
            status: FormBearingPagesStatus.success,
            pages: [pageA],
          ),
        ],
        verify: (_) => verify(repo.loadAll).called(1),
      );

      blocTest<FormBearingPagesCubit, FormBearingPagesState>(
        'a generic non-typed throw still surfaces as failure(message)',
        build: () {
          when(repo.loadAll).thenThrow(StateError('unexpected'));
          return FormBearingPagesCubit(repo: repo);
        },
        act: (cubit) => cubit.load(),
        expect: () => [
          const FormBearingPagesState(
            status: FormBearingPagesStatus.loading,
          ),
          isA<FormBearingPagesState>()
              .having((s) => s.status, 'status',
                  FormBearingPagesStatus.failure)
              .having((s) => s.lastError, 'lastError contains the message',
                  contains('unexpected')),
        ],
      );
    });
  });
}
