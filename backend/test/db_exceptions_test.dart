import 'package:backend/db/exceptions.dart';
import 'package:test/test.dart';

void main() {
  group('runDb (F6)', () {
    test('Wraps a raw exception as DbUnavailableException', () async {
      Future<int> bad() => throw const FormatException('disk on fire');
      try {
        await runDb<int>(bad, op: 'select-x');
        fail('expected throw');
      } on DbUnavailableException catch (e) {
        expect(e.message, contains('select-x'));
        expect(e.message, contains('disk on fire'));
        expect(e.cause, isA<FormatException>());
      }
    });

    test('Caller-thrown DbException passes through untouched', () async {
      Future<int> alreadyTyped() =>
          throw const DbException('email_taken');
      try {
        await runDb<int>(alreadyTyped);
        fail('expected throw');
      } on DbException catch (e) {
        // Should be the original, not a DbUnavailableException.
        expect(e, isNot(isA<DbUnavailableException>()));
        expect(e.message, 'email_taken');
      }
    });

    test('Successful body returns the value', () async {
      final v = await runDb<int>(() async => 42);
      expect(v, 42);
    });
  });
}
