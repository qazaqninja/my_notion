import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/commands/domain/command_filter.dart';

void main() {
  group('CommandFilter.parse', () {
    test('empty → none / empty term', () {
      final f = CommandFilter.parse('');
      expect(f.scope, CommandFilterScope.none);
      expect(f.term, '');
    });

    test('plain text → none / passes through trimmed', () {
      final f = CommandFilter.parse('  hello world  ');
      expect(f.scope, CommandFilterScope.none);
      expect(f.term, 'hello world');
    });

    test('db:foo → db scope', () {
      final f = CommandFilter.parse('db:Customers');
      expect(f.scope, CommandFilterScope.db);
      expect(f.term, 'Customers');
    });

    test('@db:foo → db scope (leading @ is sugar)', () {
      final f = CommandFilter.parse('@db:Customers');
      expect(f.scope, CommandFilterScope.db);
      expect(f.term, 'Customers');
    });

    test('database:foo → db scope (long alias)', () {
      final f = CommandFilter.parse('database:Projects');
      expect(f.scope, CommandFilterScope.db);
      expect(f.term, 'Projects');
    });

    test('tag:foo → tag scope', () {
      final f = CommandFilter.parse('tag:urgent');
      expect(f.scope, CommandFilterScope.tag);
      expect(f.term, 'urgent');
    });

    test('@tag:foo → tag scope', () {
      final f = CommandFilter.parse('@tag:urgent');
      expect(f.scope, CommandFilterScope.tag);
      expect(f.term, 'urgent');
    });

    test('in:Inbox → path scope', () {
      final f = CommandFilter.parse('in:Inbox');
      expect(f.scope, CommandFilterScope.path);
      expect(f.term, 'Inbox');
    });

    test('path:Inbox/ → path scope', () {
      final f = CommandFilter.parse('path:Inbox/');
      expect(f.scope, CommandFilterScope.path);
      expect(f.term, 'Inbox/');
    });

    test('folder:Operations → path scope (alias)', () {
      final f = CommandFilter.parse('folder:Operations');
      expect(f.scope, CommandFilterScope.path);
      expect(f.term, 'Operations');
    });

    test('empty term after prefix is allowed', () {
      final f = CommandFilter.parse('tag:');
      expect(f.scope, CommandFilterScope.tag);
      expect(f.term, '');
    });

    test('unknown prefix → none / passes through original', () {
      final f = CommandFilter.parse('zzz:foo');
      expect(f.scope, CommandFilterScope.none);
      expect(f.term, 'zzz:foo');
    });

    test('colon at index 0 → none', () {
      final f = CommandFilter.parse(':foo');
      expect(f.scope, CommandFilterScope.none);
      expect(f.term, ':foo');
    });
  });
}
