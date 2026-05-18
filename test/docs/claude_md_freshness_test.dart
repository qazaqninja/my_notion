import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // M1767: CLAUDE.md status block was ~70 commits stale (claimed
  // "Latest commit on `main` is M1693", actual is now M1765+). It
  // also described EditorPreferencesCubit + the Settings → Advanced
  // toggle as live — but the M1761-M1765 deletions removed both,
  // along with the legacy EditorPage source. This guard catches the
  // most-likely-to-rot phrases so the next sweep is forced if any
  // of them silently re-creep.
  group('CLAUDE.md freshness', () {
    final source = File('CLAUDE.md').readAsStringSync();

    test('does not claim "Latest commit on `main` is M1693"', () {
      expect(
        source.contains('Latest commit on `main` is M1693'),
        isFalse,
        reason: 'M1767: stale M1693 reference — D30 arc closed at M1765',
      );
    });

    test('does not still claim "Latest commit on `main` is M1766"', () {
      expect(
        source.contains('Latest commit on `main` is M1766'),
        isFalse,
        reason:
            'M1790: bumped to M1789+ after archaeology arc + TS-01 stub '
            'closures',
      );
    });

    test('does not still claim "Latest commit on `main` is M1789"', () {
      expect(
        source.contains('Latest commit on `main` is M1789'),
        isFalse,
        reason:
            'M1798: bumped to M1796+ after CA-04 ExportRepository arc '
            'closure (M1794 HtmlExportRepository + M1796 PdfExportRepository)',
      );
    });

    test('does not still claim "Latest commit on `main` is M1796"', () {
      expect(
        source.contains('Latest commit on `main` is M1796'),
        isFalse,
        reason:
            'M1802: bumped to M1800+ after CA-04 Indexer boundary '
            'survey (M1800)',
      );
    });

    test('does not still claim "Latest commit on `main` is M1801"', () {
      expect(
        source.contains('Latest commit on `main` is M1801'),
        isFalse,
        reason:
            'M1815: bumped to M1813+ after shared provider harness '
            'arc closure (M1804/M1806/M1809/M1811/M1813)',
      );
    });

    test('does not still claim "Latest commit on `main` is M1813"', () {
      expect(
        source.contains('Latest commit on `main` is M1813'),
        isFalse,
        reason:
            'M1894: bumped to M1893+ after the D-fp per-handler smoke '
            'arc reached 25/26 coverage (effective closure at M1890 '
            '_onViewFormSubmissions) + M1892 FEATURES.md sibling counter '
            'refresh',
      );
    });

    test('does not list EditorPreferencesStore as a live abstraction', () {
      expect(
        source.contains('`EditorPreferencesStore` BL-01 abstraction'),
        isFalse,
        reason: 'M1763 (D30c-b) deleted EditorPreferencesStore + the cubit',
      );
    });

    test('does not call /editor/:ulid the "legacy" route', () {
      expect(
        source.contains('on the legacy `/editor/:ulid` route'),
        isFalse,
        reason:
            'M1757 + M1765: legacy EditorPage gone; both routes serve EditorBetaPage',
      );
    });

    test('does not say "D28-D30 cutover ... remains the last v1.x lift"', () {
      expect(
        source.contains(
          'D28-D30 cutover (flip /editor-beta to default /editor) remains',
        ),
        isFalse,
        reason: 'D30 arc CLOSED at M1765 (D30a→D30b→D30c-a→D30c-c→D30c-b→D30d)',
      );
    });

    test('does not list D30b/c as pending', () {
      expect(
        source.contains('Still pending:** D30b/c'),
        isFalse,
        reason: 'D30b shipped M1757; D30c-a M1759; D30c-c M1761; D30c-b M1763',
      );
    });
  });
}
