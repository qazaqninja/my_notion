// Unit test for SecurityScopedBookmarks (C2 slice 1 of the 1m-loop plan).
//
// Drives the Dart wrapper using `setMockMethodCallHandler` so we can verify
// argument passing + return-value mapping without a real macOS host. The
// live macOS path is covered by manual verification (described in
// docs/platforms.md).

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/core/platform/security_scoped_bookmarks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('quill/bookmarks');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('SecurityScopedBookmarks', () {
    test('save() round-trips the path arg and returns the Base64 string', () async {
      String? receivedPath;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'save');
        final args = call.arguments as Map<dynamic, dynamic>;
        receivedPath = args['path'] as String;
        return 'Zm9vYmFy'; // base64('foobar')
      });

      final bookmarks = SecurityScopedBookmarks(channel: channel);
      final result = await bookmarks.save('/Users/me/MyVault');

      expect(receivedPath, '/Users/me/MyVault');
      expect(result, 'Zm9vYmFy');
    });

    test('resolve() round-trips the bookmark arg and returns the path', () async {
      String? receivedBookmark;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'resolve');
        final args = call.arguments as Map<dynamic, dynamic>;
        receivedBookmark = args['bookmark'] as String;
        return '/Users/me/MyVault';
      });

      final bookmarks = SecurityScopedBookmarks(channel: channel);
      final result = await bookmarks.resolve('Zm9vYmFy');

      expect(receivedBookmark, 'Zm9vYmFy');
      expect(result, '/Users/me/MyVault');
    });

    test('save() returns null on PlatformException (e.g. permission revoked)',
        () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'BOOKMARK_FAIL', message: 'denied');
      });

      final bookmarks = SecurityScopedBookmarks(channel: channel);
      expect(await bookmarks.save('/Users/me/MyVault'), isNull);
    });

    test('resolve() returns null on PlatformException (stale bookmark, etc.)',
        () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'BOOKMARK_FAIL', message: 'stale');
      });

      final bookmarks = SecurityScopedBookmarks(channel: channel);
      expect(await bookmarks.resolve('Zm9vYmFy'), isNull);
    });
  });
}
