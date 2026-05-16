import 'package:equatable/equatable.dart';

/// H1 — minimal Yjs-shaped CRDT document for Quill's eventual
/// multiplayer surface. Today this is a *thin proof-of-concept*
/// wrapping a single text string; production-bound future slices
/// (H2+) will swap the implementation for `y_crdt` once that
/// package's WASM-backed core is wired through the build.
///
/// Why ship the PoC now: the Clean-Arch seam matters more than
/// the implementation. Routes/repos/widgets that consume CRDT
/// updates code against this interface; swapping the
/// implementation later is a contained data-layer refactor.
class QuillCrdtDoc extends Equatable {
  const QuillCrdtDoc({
    required this.body,
    required this.clock,
  });

  /// Empty doc — useful as an initial state before any updates land.
  factory QuillCrdtDoc.empty() => const QuillCrdtDoc(body: '', clock: 0);

  /// Construct from a raw markdown body. Each line is treated as a
  /// CRDT-text segment; the segment count seeds the clock so a
  /// freshly-parsed doc has a deterministic version.
  factory QuillCrdtDoc.fromMarkdown(String markdown) {
    return QuillCrdtDoc(
      body: markdown,
      clock: _linesOf(markdown).length,
    );
  }

  /// The full markdown body. In a real CRDT this would be
  /// reconstructed from a sequence of insert/delete operations;
  /// the PoC short-circuits to a flat string so the rest of the
  /// stack has a real interface to code against.
  final String body;

  /// Monotonic version counter incremented on every apply().
  /// Production y_crdt uses a vector clock per peer; this PoC
  /// collapses to a single counter for simplicity.
  final int clock;

  /// Apply a [QuillCrdtUpdate] to produce a new doc. Pure function
  /// — no in-place mutation, just like a real CRDT's `transact`.
  QuillCrdtDoc apply(QuillCrdtUpdate update) {
    switch (update) {
      case QuillCrdtSetBody(:final body):
        return QuillCrdtDoc(body: body, clock: clock + 1);
    }
  }

  /// Round-trip back to markdown. Currently a no-op identity since
  /// the PoC stores raw markdown, but the indirection keeps callers
  /// from grabbing `.body` directly — when the y_crdt swap lands,
  /// this is where the Y.Text → CommonMark walk happens.
  String toMarkdown() => body;

  @override
  List<Object?> get props => [body, clock];
}

/// Sealed update hierarchy. Today there's one variant
/// (`SetBody` — replace the whole body); future slices add
/// `Insert(offset, text)` and `Delete(offset, length)` once the
/// editor speaks CRDT-shaped operations.
sealed class QuillCrdtUpdate extends Equatable {
  const QuillCrdtUpdate();
}

class QuillCrdtSetBody extends QuillCrdtUpdate {
  const QuillCrdtSetBody(this.body);
  final String body;
  @override
  List<Object?> get props => [body];
}

/// Split [src] into lines without losing the trailing-newline
/// distinction (matters for the `body.endsWith('\n')` invariant
/// the frontmatter parser depends on). PoC-only — y_crdt's Y.Text
/// has its own newline-aware iterator.
List<String> _linesOf(String src) {
  if (src.isEmpty) return const [];
  return src.split('\n');
}
