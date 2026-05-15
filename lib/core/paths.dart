/// Pure helpers for path-style strings displayed in the UI.
library;

/// Drop the trailing `.md` extension from a vault-relative path so it
/// reads as a human-friendly title-style label.
/// `Inbox/Foo.md` → `Inbox/Foo`. Anything else passes through unchanged.
String stripMdExtension(String path) {
  if (path.endsWith('.md')) return path.substring(0, path.length - 3);
  return path;
}
