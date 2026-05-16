// Smoke test for AudioInlinePlayer (B2 of the 1m-loop plan).
//
// Verifies the widget renders the controls scaffold (play button + position
// label) without actually starting playback. Audio I/O is platform-dependent
// and out of scope for unit tests.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/shared/widgets/audio_inline_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AudioInlinePlayer (B2)', () {
    testWidgets('renders a play icon + position label by default',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AudioInlinePlayer(
              filePath: '/tmp/does-not-exist.mp3',
            ),
          ),
        ),
      );

      expect(find.byType(AudioInlinePlayer), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      // Default position label "00:00 / --:--" (or similar) is rendered.
      expect(find.textContaining('00:00'), findsOneWidget);
    });

    testWidgets('exposes the filePath via the widget API', (tester) async {
      const widget = AudioInlinePlayer(filePath: '/foo.mp3');
      expect(widget.filePath, '/foo.mp3');
    });
  });
}
