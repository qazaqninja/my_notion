import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // M1769: FEATURES.md status counter + WYSIWYG section were stale by
  // the same M1693→M1765 gap as CLAUDE.md was (refreshed at M1767).
  // Mirrors that pattern — five string-grep asserts against the
  // most-likely-to-rot phrases. After M1755 (D-fp arc) + M1765 (D30d)
  // the WYSIWYG editor is fully shipped, not "🚧 partial".
  // M1770 fix-forward: TS-04 sub-grouping per stale-axis (the
  // flat single-group structure surfaced as a WARN in M1769's
  // orchestrator audit). Three sub-groups mirror the three axes
  // documented in M1769's commit message: status counter,
  // block-editor paragraph, WYSIWYG pick-next item #2.
  group('FEATURES.md freshness', () {
    final source = File('docs/FEATURES.md').readAsStringSync();

    group('status counter', () {
      test('is not M1690+ or M1186+', () {
        expect(
          source.contains('M0–M1690+)'),
          isFalse,
          reason: 'M1769: counter advanced to M1766+ after D30 arc closed',
        );
        expect(
          source.contains('M0–M1186+'),
          isFalse,
          reason:
              'M1769: the 1,186 baseline is from M1248-era counter advance',
        );
      });

      test('is not still M1766+ after post-D30d arcs landed', () {
        expect(
          source.contains('M0–M1766+'),
          isFalse,
          reason:
              'M1792: bumped to M1790+ after post-D30d archaeology arc + '
              'TS-01 stub + CLAUDE.md refresh',
        );
        expect(
          source.contains('1,766+ milestones'),
          isFalse,
          reason: 'M1792: also bumped the prose counter on line 12',
        );
      });

      test('is not still M1790+ after CA-04 ExportRepository arc landed', () {
        expect(
          source.contains('M0–M1790+'),
          isFalse,
          reason:
              'M1798: bumped to M1796+ after CA-04 ExportRepository arc '
              'closure (M1794 Html + M1796 Pdf)',
        );
        expect(
          source.contains('1,790+ milestones'),
          isFalse,
          reason: 'M1798: also bumped the prose counter on line 12',
        );
      });

      test('is not still M1796+ after CA-04 Indexer boundary survey landed',
          () {
        expect(
          source.contains('M0–M1796+'),
          isFalse,
          reason:
              'M1802: bumped to M1800+ after CA-04 Indexer boundary '
              'survey (M1800)',
        );
        expect(
          source.contains('1,796+ milestones'),
          isFalse,
          reason: 'M1802: also bumped the prose counter on line 12',
        );
      });

      test('is not still M1801+ after shared provider harness arc landed',
          () {
        expect(
          source.contains('M0–M1801+'),
          isFalse,
          reason:
              'M1815: bumped to M1813+ after shared provider harness '
              'arc closure (M1804/M1806/M1809/M1811/M1813)',
        );
        expect(
          source.contains('1,801+ milestones'),
          isFalse,
          reason: 'M1815: also bumped the prose counter on line 12',
        );
      });

      test('is not still M1813+ after D-fp per-handler smoke arc landed',
          () {
        expect(
          source.contains('M0–M1813+'),
          isFalse,
          reason:
              'M1892: bumped to M1891+ after the D-fp per-handler smoke '
              'arc reached 25/26 coverage (M1817 spike → M1888 _onFindInPage '
              '→ M1890 _onViewFormSubmissions) with all deterministic '
              'widget-only handlers smoked',
        );
        expect(
          source.contains('1,813+ milestones'),
          isFalse,
          reason: 'M1892: also bumped the prose counter on line 12',
        );
      });
    });

    group('block-editor paragraph', () {
      test('legacy editor description is gone', () {
        expect(
          source.contains('The legacy per-block source-mode editor stays '
              'reachable through the opt-out toggle (Settings → Advanced) '
              'until D30 cutover deletes it'),
          isFalse,
          reason:
              'M1761 (Settings toggle) + M1765 (legacy EditorPage) deleted',
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

    group('WYSIWYG pick-next item #2', () {
      test('does not say super_editor is "future work"', () {
        expect(
          source.contains(
            'True `super_editor` integration with a markdown serializer '
            'remains future work',
          ),
          isFalse,
          reason:
              'M1755 (D-fp arc) + M1765 (D30d): WYSIWYG fully shipped — '
              'flip 🚧 → ✅',
        );
      });
    });
  });
}
