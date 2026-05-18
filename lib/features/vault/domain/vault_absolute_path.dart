/// Join a vault `rootPath` with a page `relativePath` to produce the
/// absolute filesystem path the OS share-sheet / Reveal-in-Finder /
/// Copy-path actions need.
///
/// Behaviour:
/// - both non-empty → `'$rootPath/$relativePath'` (single `/`, even
///   when `rootPath` ends with one).
/// - `rootPath` null or empty → falls back to `relativePath` as-is
///   (the legacy editor's copy-path behaviour when VaultBloc hasn't
///   loaded yet — degrades gracefully instead of producing a leading-
///   slash phantom path).
/// - `relativePath` empty → returns `rootPath`.
///
/// Centralised so future tweaks (e.g. URL-encoding, Windows path
/// separator handling) live in one place — multiple D-fp ports in
/// [editor_beta_page.dart] (`_onSharePage`, `_onCopyPath`) already
/// need this join.
String vaultAbsolutePath({required String? rootPath, required String relativePath}) {
  if (rootPath == null || rootPath.isEmpty) return relativePath;
  if (relativePath.isEmpty) return rootPath;
  final root = rootPath.endsWith('/')
      ? rootPath.substring(0, rootPath.length - 1)
      : rootPath;
  return '$root/$relativePath';
}
