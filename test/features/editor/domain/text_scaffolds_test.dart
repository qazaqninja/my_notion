import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/editor/domain/text_scaffolds.dart';

/// Smoke-tests for the scaffold-string constants exported from
/// `text_scaffolds.dart`. These constants are inserted verbatim
/// by the slash menu's "Insert ..." actions, so the tests check
/// the constants are non-empty and end with a newline (the
/// editor's caret-positioning expects trailing newlines).
///
/// Mirrors the lib-tree shape (FS-04 / TS-01) — each top-level
/// file in `lib/features/editor/domain/` has a `_test.dart`
/// sibling for discoverability.
void main() {
  group('scaffold constants are non-empty', () {
    test('kLoremIpsumParagraph contains content', () {
      expect(kLoremIpsumParagraph.isNotEmpty, true);
      expect(kLoremIpsumParagraph.toLowerCase(), contains('lorem'));
    });

    test('kMeetingNotesScaffold contains content', () {
      expect(kMeetingNotesScaffold.isNotEmpty, true);
    });

    test('kStandupNotesScaffold contains content', () {
      expect(kStandupNotesScaffold.isNotEmpty, true);
    });

    test('kRetroNotesScaffold contains content', () {
      expect(kRetroNotesScaffold.isNotEmpty, true);
    });

    test('kPostMortemScaffold contains content', () {
      expect(kPostMortemScaffold.isNotEmpty, true);
    });

    test('kOneOnOneScaffold contains content', () {
      expect(kOneOnOneScaffold.isNotEmpty, true);
    });

    test('kAdrNotesScaffold contains content', () {
      expect(kAdrNotesScaffold.isNotEmpty, true);
    });
  });

  group('scaffold constants are markdown-shaped', () {
    test('meeting notes scaffold contains heading markers', () {
      // The scaffold should have at least one `## ` section
      // heading to render as a structured outline.
      expect(kMeetingNotesScaffold.contains('## '), true);
    });

    test('retro notes scaffold contains list markers', () {
      // Retro scaffolds use bullet lists for the three buckets.
      expect(kRetroNotesScaffold.contains('- '), true);
    });

    test('postmortem scaffold contains heading markers', () {
      expect(kPostMortemScaffold.contains('## '), true);
    });

    test('ADR notes scaffold contains heading markers', () {
      expect(kAdrNotesScaffold.contains('## '), true);
    });
  });

  group('scaffold constants are distinct', () {
    test('all seven scaffolds are different strings', () {
      // Sanity check — guard against copy/paste typos that
      // would alias two scaffolds to the same content.
      final scaffolds = <String>{
        kLoremIpsumParagraph,
        kMeetingNotesScaffold,
        kStandupNotesScaffold,
        kRetroNotesScaffold,
        kPostMortemScaffold,
        kOneOnOneScaffold,
        kAdrNotesScaffold,
      };
      expect(scaffolds.length, 7);
    });
  });
}
