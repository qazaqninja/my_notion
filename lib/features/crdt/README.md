# `crdt/` — Phase H multiplayer seam

> H1 (M1371) ships the Clean-Architecture seam, not the production
> implementation. Today this feature is a thin pass-through over
> raw markdown; future slices (H2+) swap the storage for
> `y_crdt`'s WASM-backed Y.Text core.

## What's here

```
domain/
  entities/
    quill_crdt_doc.dart           # Yjs-shaped wrapper
  usecases/
    markdown_crdt_serializer.dart # markdown ↔ QuillCrdtDoc
```

## Why a PoC first

`y_crdt: ^0.0.1` on pub.dev is a WASM-backed port (pulls in
`wasm_run` + `wasm_wit_component`). Adding it pre-emptively
would balloon binary size before we have a use case to test
against. Shipping the abstraction lets us:

1. Code SyncBloc + push-pull handlers against the public
   surface (`QuillCrdtDoc.apply(QuillCrdtSetBody…)`).
2. Write round-trip tests that survive the eventual swap.
3. Defer the WASM cost decision to when multiplayer actually
   ships.

## Migration plan (H2+)

1. Add `y_crdt: ^0.0.1` (or whichever version is current) to
   `pubspec.yaml`.
2. Replace `QuillCrdtDoc`'s internal `body` field with a real
   `YDoc` + `Y.Text` pair.
3. `MarkdownCrdtSerializer.fromMarkdown` becomes a CommonMark
   walk that inserts each block as a Y.Text segment.
4. `apply` switches from the sealed `QuillCrdtUpdate` to Yjs's
   binary update format (`Uint8List`).
5. The WebSocket sub endpoint (queued as H2) carries those
   binary updates between peers + the backend `vault_files`
   table.

The 7 H1 round-trip tests in
`test/features/crdt/quill_crdt_doc_test.dart` stay green
throughout the migration because they exercise the public
surface, not the storage shape.
