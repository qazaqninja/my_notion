import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/editor/domain/safe_export_filename.dart';

void main() {
  group('safeExportFilename', () {
    test('passes a plain title through unchanged', () {
      expect(safeExportFilename('My Notes'), 'My Notes');
    });

    test('replaces every reserved filename char with underscore', () {
      // Reserved set mirrors the legacy editor's
      // RegExp(r'[\\/:*?"<>|]') — backslash, forward slash, colon,
      // star, question mark, double quote, less-than, greater-than,
      // pipe. Each maps 1:1 to a single underscore.
      expect(
        safeExportFilename(r'a\b/c:d*e?f"g<h>i|j'),
        'a_b_c_d_e_f_g_h_i_j',
      );
    });

    test('trims leading and trailing whitespace', () {
      expect(safeExportFilename('  Notes  '), 'Notes');
    });

    test('falls back to "page" when the title is empty', () {
      expect(safeExportFilename(''), 'page');
    });

    test('falls back to "page" when the title is whitespace-only', () {
      // Match the legacy `${safeName.isEmpty ? 'page' : safeName}`
      // contract — after trim, whitespace-only titles count as empty.
      expect(safeExportFilename('   '), 'page');
    });

    test('honours a custom fallback', () {
      // The helper takes an optional `fallback:` so callers can
      // tune the per-export-flavour default (e.g. "untitled-page",
      // "snapshot") without forking the helper.
      expect(safeExportFilename('', fallback: 'untitled'), 'untitled');
    });

    test('non-ASCII characters pass through untouched', () {
      // The reserved set is restricted to the legacy 9-char regex;
      // umlauts, CJK, emoji, etc. are all safe on every platform we
      // ship to (the file picker handles platform-specific encoding).
      expect(safeExportFilename('héllo • 中文'), 'héllo • 中文');
    });
  });
}
