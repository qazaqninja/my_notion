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

  test('rejects non-http(s) schemes (M717)', () async {
    // file:// — would silently render as no bookmark card and could
    // expose local paths; reject.
    await expectLater(
      () => UrlBookmark.capture('file:///etc/passwd', vault),
      throwsA(isA<FormatException>()),
    );
    // javascript: — Uri.tryParse accepts it with a host-shaped tail;
    // M717 rejects to prevent auto-launching JS via url_launcher.
    await expectLater(
      () => UrlBookmark.capture('javascript://example.com/alert(1)', vault),
      throwsA(isA<FormatException>()),
    );
    // mailto: — different shape (no host) is already rejected by the
    // host check, but include for documentation completeness.
    await expectLater(
      () => UrlBookmark.capture('mailto:nobody@example.com', vault),
      throwsA(isA<FormatException>()),
    );
  });

  test('accepts both http and https (M717)', () async {
    final http = await UrlBookmark.capture('http://example.com', vault);
    expect(http.relativePath, startsWith('Bookmarks/'));
    final https = await UrlBookmark.capture('https://example.com', vault);
    expect(https.relativePath, startsWith('Bookmarks/'));
  });

  test('disambiguates colliding filenames instead of overwriting (M773)',
      () async {
    // First capture lands at Bookmarks/example.com.md.
    final first =
        await UrlBookmark.capture('https://example.com', vault);
    expect(first.relativePath, equals('Bookmarks/example.com.md'));

    // Second capture of the same URL would clobber the first via a
    // direct File.writeAsString. The disambiguator must redirect.
    final second =
        await UrlBookmark.capture('https://example.com', vault);
    expect(second.relativePath, equals('Bookmarks/example.com (2).md'));

    // Verify both pages survive on disk.
    expect(await File(p.join(vault.path, first.relativePath)).exists(),
        isTrue);
    expect(await File(p.join(vault.path, second.relativePath)).exists(),
        isTrue);
    expect(first.ulid, isNot(equals(second.ulid)));

    // Third lands at (3).
    final third = await UrlBookmark.capture('https://example.com', vault);
    expect(third.relativePath, equals('Bookmarks/example.com (3).md'));
  });
}
