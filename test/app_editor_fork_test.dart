import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/app.dart';
import 'package:my_notion/features/editor/presentation/pages/editor_beta_page.dart';
import 'package:my_notion/features/editor/presentation/pages/editor_page.dart';

void main() {
  group('buildEditorPageForFork', () {
    group('useBetaEditor = true', () {
      test('returns EditorBetaPage', () {
        final widget = buildEditorPageForFork(
          useBetaEditor: true,
          ulid: '01HX',
          anchor: null,
        );
        expect(widget, isA<EditorBetaPage>());
      });

      test('passes the ulid through to EditorBetaPage', () {
        final widget = buildEditorPageForFork(
          useBetaEditor: true,
          ulid: '01HX',
          anchor: null,
        ) as EditorBetaPage;
        expect(widget.ulid, '01HX');
      });

      test('keys the EditorBetaPage with a beta-prefixed ValueKey', () {
        final widget = buildEditorPageForFork(
          useBetaEditor: true,
          ulid: '01HX',
          anchor: null,
        );
        expect(widget.key, const ValueKey('beta-fork-01HX'));
      });

      test('ignores the anchor query param (beta has no #-jump support)',
          () {
        final withAnchor = buildEditorPageForFork(
          useBetaEditor: true,
          ulid: '01HX',
          anchor: 'section-1',
        );
        final withoutAnchor = buildEditorPageForFork(
          useBetaEditor: true,
          ulid: '01HX',
          anchor: null,
        );
        // Both produce EditorBetaPage with the same ulid + key — the
        // anchor is dropped on the beta branch (no in-page-jump
        // support yet in EditorBetaPage).
        expect(withAnchor.key, equals(withoutAnchor.key));
        expect((withAnchor as EditorBetaPage).ulid,
            equals((withoutAnchor as EditorBetaPage).ulid));
      });
    });

    group('useBetaEditor = false', () {
      test('returns EditorPage', () {
        final widget = buildEditorPageForFork(
          useBetaEditor: false,
          ulid: '01HX',
          anchor: null,
        );
        expect(widget, isA<EditorPage>());
      });

      test('passes the ulid + null anchor through to EditorPage', () {
        final widget = buildEditorPageForFork(
          useBetaEditor: false,
          ulid: '01HX',
          anchor: null,
        ) as EditorPage;
        expect(widget.ulid, '01HX');
        expect(widget.anchor, isNull);
      });

      test('passes the ulid + anchor through to EditorPage', () {
        final widget = buildEditorPageForFork(
          useBetaEditor: false,
          ulid: '01HX',
          anchor: 'section-1',
        ) as EditorPage;
        expect(widget.ulid, '01HX');
        expect(widget.anchor, 'section-1');
      });

      test(
          'keys EditorPage with `ulid#anchor` (or `ulid#` when '
          'anchor is null)', () {
        final withAnchor = buildEditorPageForFork(
          useBetaEditor: false,
          ulid: '01HX',
          anchor: 'section-1',
        );
        final withoutAnchor = buildEditorPageForFork(
          useBetaEditor: false,
          ulid: '01HX',
          anchor: null,
        );
        expect(withAnchor.key, const ValueKey('01HX#section-1'));
        expect(withoutAnchor.key, const ValueKey('01HX#'));
      });
    });
  });
}
