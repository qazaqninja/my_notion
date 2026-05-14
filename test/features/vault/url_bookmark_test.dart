import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/vault/data/url_bookmark.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory vault;
  setUp(() async {
    vault = await Directory.systemTemp.createTemp('quill_bookmark_');
  });
  tearDown(() async {
    try {
      await vault.delete(recursive: true);
    } catch (_) {}
  });

  test('captures a URL with host-derived filename + frontmatter',
      () async {
    final r = await UrlBookmark.capture(
      'https://example.com/blog/post-1',
      vault,
    );
    expect(r.relativePath, startsWith('Bookmarks/'));
    expect(r.relativePath, contains('example.com'));
    expect(r.ulid.length, 26);
    final body =
        await File(p.join(vault.path, r.relativePath)).readAsString();
    expect(body, contains('id: ${r.ulid}'));
    // The URL contains `:` + `/` so the YAML emitter wraps it in
    // double quotes — both forms are valid YAML, just different
    // serialisations.
    expect(body, contains('url: "https://example.com/blog/post-1"'));
    expect(body, contains('tags: [bookmark]'));
    // Body has the URL on its own line so the renderer's bookmark card
    // path picks it up.
    expect(body, contains('https://example.com/blog/post-1'));
  });

  test('empty URL throws FormatException', () async {
    await expectLater(
      () => UrlBookmark.capture('   ', vault),
      throwsA(isA<FormatException>()),
    );
  });

  test('non-URL string throws FormatException', () async {
    await expectLater(
      () => UrlBookmark.capture('not a url', vault),
      throwsA(isA<FormatException>()),
    );
  });

  test('handles bare-host URL (no path)', () async {
    final r = await UrlBookmark.capture('https://example.org', vault);
    expect(r.relativePath, equals('Bookmarks/example.org.md'));
  });
}
