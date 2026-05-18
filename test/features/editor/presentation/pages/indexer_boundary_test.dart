import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // M1800: CA-04 boundary guard for the `vault/data/indexer.dart`
  // import in editor_beta_page.dart. Unlike the export adapters
  // (M1794 HtmlExportRepository + M1796 PdfExportRepository), the
  // editor widget reads `context.read<Indexer>()` purely as type-
  // erased plumbing — it forwards the value to EditorBloc's
  // constructor and never invokes a method on it. The data-layer
  // coupling lives in EditorBloc (data layer), not in the widget.
  //
  // This guard enforces that intent: the only acceptable mention of
  // `Indexer` in this file is the `context.read<Indexer>()` site that
  // hands the type to EditorBloc. If a future edit calls a method
  // on the read value (e.g., `context.read<Indexer>().reindex(...)`),
  // the assertion below fires and the slice must either:
  //   (a) route the call through EditorBloc instead, or
  //   (b) trigger the project-wide RP-01 IndexerRepository extraction
  //       that was deferred at M1800.
  group('editor_beta_page Indexer boundary', () {
    final source = File(
      'lib/features/editor/presentation/pages/editor_beta_page.dart',
    ).readAsStringSync();

    group('CA-04 carry-forward', () {
      test('Indexer is read at most once (the EditorBloc handoff)', () {
        final matches = RegExp(r'context\.read<Indexer>\(\)')
            .allMatches(source)
            .length;
        expect(
          matches,
          1,
          reason:
              'M1800: Indexer is intentionally read once to hand to '
              'EditorBloc.  Additional reads would mean the widget '
              'started calling Indexer methods directly — at that '
              'point promote IndexerRepository per CA-04 / RP-01.',
        );
      });

      test('no `.reindex(`, `.wipeCache(`, etc. method calls on Indexer',
          () {
        // Sniff for any method invocation form that follows
        // `context.read<Indexer>()` chained directly. The widget
        // should only forward the value, never invoke methods.
        final invocations = RegExp(
          r'context\.read<Indexer>\(\)\.\w+\(',
        ).allMatches(source).length;
        expect(
          invocations,
          0,
          reason:
              'M1800: widget must not call methods on Indexer. Route '
              'through EditorBloc events or extract IndexerRepository.',
        );
      });
    });
  });
}
