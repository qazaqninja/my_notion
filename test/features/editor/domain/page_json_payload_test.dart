import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/editor/domain/page_json_payload.dart';

void main() {
  group('pageAsJsonPayload', () {
    test('serialises ulid + relativePath + frontmatter + body as JSON', () {
      final payload = pageAsJsonPayload(
        ulid: '01HX0VEY5T6K7R9X4Y8Z0A3D4G',
        relativePath: 'notes/today.md',
        frontmatter: {'title': 'Today', 'public': true},
        body: 'hello world',
      );
      final decoded = jsonDecode(payload) as Map<String, Object?>;
      expect(decoded['ulid'], '01HX0VEY5T6K7R9X4Y8Z0A3D4G');
      expect(decoded['relativePath'], 'notes/today.md');
      expect(decoded['body'], 'hello world');
      final fm = decoded['frontmatter']! as Map<String, Object?>;
      expect(fm['title'], 'Today');
      expect(fm['public'], true);
    });

    test('preserves the key order used by the legacy editor', () {
      // The legacy editor at editor_page.dart:555 writes
      // { ulid, relativePath, frontmatter, body } in that order. Any
      // tooling that diffs the payload across editors expects the
      // same ordering, so the helper should not silently re-sort.
      final payload = pageAsJsonPayload(
        ulid: 'U',
        relativePath: 'R',
        frontmatter: {'a': 1},
        body: 'B',
      );
      final ulidAt = payload.indexOf('"ulid"');
      final relAt = payload.indexOf('"relativePath"');
      final fmAt = payload.indexOf('"frontmatter"');
      final bodyAt = payload.indexOf('"body"');
      expect(ulidAt, lessThan(relAt));
      expect(relAt, lessThan(fmAt));
      expect(fmAt, lessThan(bodyAt));
    });

    test('emits empty objects for empty frontmatter', () {
      final payload = pageAsJsonPayload(
        ulid: 'U',
        relativePath: 'R',
        frontmatter: const {},
        body: '',
      );
      final decoded = jsonDecode(payload) as Map<String, Object?>;
      expect(decoded['frontmatter'], isA<Map<String, Object?>>());
      expect((decoded['frontmatter']! as Map).isEmpty, isTrue);
      expect(decoded['body'], '');
    });

    test('round-trips non-ASCII content unchanged', () {
      // jsonEncode escapes non-ASCII by default; the legacy editor
      // didn't tune that flag, so neither do we.
      final payload = pageAsJsonPayload(
        ulid: 'U',
        relativePath: 'R',
        frontmatter: const {},
        body: 'héllo • 中文',
      );
      final decoded = jsonDecode(payload) as Map<String, Object?>;
      expect(decoded['body'], 'héllo • 中文');
    });
  });
}
