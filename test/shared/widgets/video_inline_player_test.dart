// Smoke test for VideoInlinePlayer (B1 of the 1m-loop plan).
//
// Verifies the widget instantiates with a file path and renders the loading
// scaffolding before the video_player platform channel reports back. Real
// playback is OS-dependent and out of scope for unit tests — we just confirm
// the placeholder + lifecycle shape so the renderer integration in slice 2
// can rely on a stable widget contract.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/shared/widgets/video_inline_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoInlinePlayer (B1)', () {
    testWidgets('renders a loading placeholder before the controller initialises',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VideoInlinePlayer(
              filePath: '/tmp/does-not-exist.mp4',
            ),
          ),
        ),
      );

      // Before the controller initialises, the player shows a fixed-height
      // shimmer-ish placeholder rather than an empty box.
      expect(find.byType(VideoInlinePlayer), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('exposes the filePath via the widget API for golden tests',
        (tester) async {
      const widget = VideoInlinePlayer(filePath: '/foo.mp4');
      expect(widget.filePath, '/foo.mp4');
    });
  });
}
