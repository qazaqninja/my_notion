// Smoke test for bloc_test (RULES.md TS-03).
//
// Verifies that `blocTest<>` from `package:bloc_test/bloc_test.dart` is wired
// correctly and can drive a minimal Cubit through emit/expect assertions.
//
// Once this passes, the architectural prerequisite for porting our existing
// hand-written bloc/cubit tests to the `bloc_test` harness is satisfied.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _CounterCubit extends Cubit<int> {
  _CounterCubit() : super(0);

  void increment() => emit(state + 1);

  void incrementBy(int n) => emit(state + n);
}

void main() {
  group('bloc_test smoke (TS-03)', () {
    blocTest<_CounterCubit, int>(
      'emits [1] when increment is called',
      build: _CounterCubit.new,
      act: (cubit) => cubit.increment(),
      expect: () => [1],
    );

    blocTest<_CounterCubit, int>(
      'emits [5] when incrementBy(5) is called from initial state 0',
      build: _CounterCubit.new,
      act: (cubit) => cubit.incrementBy(5),
      expect: () => [5],
    );

    blocTest<_CounterCubit, int>(
      'emits nothing when no act is invoked',
      build: _CounterCubit.new,
      expect: () => <int>[],
    );
  });
}
