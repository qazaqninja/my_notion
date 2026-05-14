import 'dart:io';

/// Cross-platform "reveal in OS file browser" helper.
///
/// Opens [path] in the platform's native file browser (Finder, Files, Explorer).
/// If [path] is a file, the parent folder is opened and (where supported)
/// the file is highlighted.
///
/// Returns true on success, false if the platform isn't supported or the
/// process exits non-zero.
class Reveal {
  const Reveal._();

  static Future<bool> show(String path) async {
    if (path.isEmpty) return false;
    try {
      if (Platform.isMacOS) {
        // `open -R` reveals (highlights) a file/folder in Finder.
        final r = await Process.run('open', ['-R', path]);
        return r.exitCode == 0;
      }
      if (Platform.isLinux) {
        final target = await FileSystemEntity.isFile(path)
            ? File(path).parent.path
            : path;
        final r = await Process.run('xdg-open', [target]);
        return r.exitCode == 0;
      }
      if (Platform.isWindows) {
        final isFile = await FileSystemEntity.isFile(path);
        final r = isFile
            ? await Process.run('explorer.exe', ['/select,', path])
            : await Process.run('explorer.exe', [path]);
        // explorer.exe returns 1 even on success; treat any launch as ok.
        return r.exitCode == 0 || r.exitCode == 1;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Open a URL (or any URI handler the OS knows) in the user's default app.
  /// Used by button blocks and bookmark cards. Mirrors [show] but doesn't
  /// pass `-R` since there's nothing to highlight.
  static Future<bool> openUrl(String url) async {
    if (url.isEmpty) return false;
    try {
      if (Platform.isMacOS) {
        final r = await Process.run('open', [url]);
        return r.exitCode == 0;
      }
      if (Platform.isLinux) {
        final r = await Process.run('xdg-open', [url]);
        return r.exitCode == 0;
      }
      if (Platform.isWindows) {
        final r =
            await Process.run('cmd.exe', ['/c', 'start', '', url]);
        return r.exitCode == 0 || r.exitCode == 1;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
