import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/vault/domain/vault_absolute_path.dart';

void main() {
  group('vaultAbsolutePath', () {
    test('joins non-empty rootPath + relativePath with a single /', () {
      expect(
        vaultAbsolutePath(
          rootPath: '/Users/me/vault',
          relativePath: 'notes/today.md',
        ),
        '/Users/me/vault/notes/today.md',
      );
    });

    test('falls back to relativePath when rootPath is null', () {
      expect(
        vaultAbsolutePath(rootPath: null, relativePath: 'notes/today.md'),
        'notes/today.md',
      );
    });

    test('falls back to relativePath when rootPath is empty', () {
      expect(
        vaultAbsolutePath(rootPath: '', relativePath: 'notes/today.md'),
        'notes/today.md',
      );
    });

    test('does not double the / when rootPath already ends with one', () {
      // Trailing-slash rootPath is uncommon but legal on macOS; the
      // joined output should still have exactly one `/` between the
      // two halves.
      expect(
        vaultAbsolutePath(
          rootPath: '/Users/me/vault/',
          relativePath: 'notes/today.md',
        ),
        '/Users/me/vault/notes/today.md',
      );
    });

    test('returns the rootPath when relativePath is empty', () {
      expect(
        vaultAbsolutePath(rootPath: '/Users/me/vault', relativePath: ''),
        '/Users/me/vault',
      );
    });

    test('returns empty string when both halves are empty', () {
      expect(vaultAbsolutePath(rootPath: '', relativePath: ''), '');
    });
  });
}
