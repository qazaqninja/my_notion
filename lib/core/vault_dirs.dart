/// Directory names that vault walkers should skip recursing into.
///
/// Every walker in the codebase (VaultFsDatasource.scan, Indexer.
/// _walkAll, VaultExporter._walk, HtmlExporter._walk, PdfExporter._walk,
/// VaultWatcher._isRelevant) consults this same set. Keeping it in
/// one place means a divergence — like the build/ omissions M719/M720/
/// M721/M722 each had to patch — becomes impossible.
///
/// Rationale per entry:
///   .git           — git metadata
///   .obsidian      — Obsidian sidecar (vault shared with Obsidian)
///   node_modules   — JS package soup
///   _meta          — Quill's internal staging (reserved)
///   .dart_tool     — Dart tooling output
///   .idea          — JetBrains IDE settings
///   build          — Flutter / generic build output
///   .trash         — Quill's local trash bucket
library;

const Set<String> kIgnoredVaultDirs = {
  '.git',
  '.obsidian',
  'node_modules',
  '_meta',
  '.dart_tool',
  '.idea',
  'build',
  '.trash',
};
