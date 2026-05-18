import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // M1769: FEATURES.md status counter + WYSIWYG section were stale by
  // the same M1693→M1765 gap as CLAUDE.md was (refreshed at M1767).
  // Mirrors that pattern — five string-grep asserts against the
  // most-likely-to-rot phrases. After M1755 (D-fp arc) + M1765 (D30d)
  // the WYSIWYG editor is fully shipped, not "🚧 partial".
  group('FEATURES.md freshness', () {
    final source = File('docs/FEATURES.md').readAsStringSync();

    test('status counter is not M1690+ or M1186+', () {
      expect(
        source.contains('M0–M1690+)'),
        isFalse,
        reason: 'M1769: counter advanced to M1766+ after D30 arc closed',
      );
      expect(
        source.contains('M0–M1186+'),
        isFalse,
        reason: 'M1769: the 1,186 baseline is from M1248-era counter advance',
      );
    });

    test('WYSIWYG #2 backlog does not say super_editor is "future work"', () {
      expect(
        source.contains(
          'True `super_editor` integration with a markdown serializer remains future work',
        ),
        isFalse,
        reason:
            'M1755 (D-fp arc) + M1765 (D30d): WYSIWYG fully shipped — flip 🚧 → ✅',
      );
    });

    test('legacy editor description is gone', () {
      expect(
        source.contains('The legacy per-block source-mode editor stays '
            'reachable through the opt-out toggle (Settings → Advanced) '
            'until D30 cutover deletes it'),
        isFalse,
        reason:
            'M1761 (Settings toggle deleted) + M1765 (legacy EditorPage deleted)',
      );
    });

    test('no remaining "D30 cutover deletes it" phrasing', () {
      expect(
        source.contains('until D30 cutover deletes it'),
        isFalse,
        reason: 'D30 cutover arc fully closed at M1765',
      );
    });
  });
}
