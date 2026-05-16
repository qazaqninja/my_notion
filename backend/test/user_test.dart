import 'package:backend/auth/user.dart';
import 'package:test/test.dart';

void main() {
  group('User entity (E4)', () {
    final now = DateTime.utc(2026, 5, 17, 8, 30);

    test('value equality on id/email/createdAt', () {
      final a = User(id: '01HX', email: 'a@quill', createdAt: now);
      final b = User(id: '01HX', email: 'a@quill', createdAt: now);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('inequality when any field differs', () {
      final base = User(id: '01HX', email: 'a@quill', createdAt: now);
      expect(base, isNot(User(id: '01HY', email: 'a@quill', createdAt: now)));
      expect(base, isNot(User(id: '01HX', email: 'b@quill', createdAt: now)));
      expect(
        base,
        isNot(
          User(
            id: '01HX',
            email: 'a@quill',
            createdAt: now.add(const Duration(seconds: 1)),
          ),
        ),
      );
    });

    test('toString does NOT leak any sensitive material', () {
      // Bcrypt password hash never lives on the entity — toString shouldn't
      // accidentally expose anything we'd regret in logs.
      final u = User(id: '01HX', email: 'a@quill', createdAt: now);
      final s = u.toString();
      expect(s, contains('01HX'));
      expect(s, contains('a@quill'));
      expect(s, isNot(contains('password')));
      expect(s, isNot(contains('hash')));
    });
  });
}
