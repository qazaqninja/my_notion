/// Per-file summary returned by `GET /sync/list`. The body itself is NOT
/// included — clients fetch bodies on demand via `GET /sync/get/<relpath>`
/// (slice E10), or push their own via `PUT /sync/put/<relpath>` (slice E9).
class FileSummary {
  const FileSummary({
    required this.relpath,
    required this.sha256,
    required this.mtime,
  });

  final String relpath;
  final String sha256;
  final DateTime mtime;

  Map<String, dynamic> toJson() => {
        'relpath': relpath,
        'sha256': sha256,
        'mtime': mtime.toIso8601String(),
      };

  @override
  bool operator ==(Object other) =>
      other is FileSummary &&
      other.relpath == relpath &&
      other.sha256 == sha256 &&
      other.mtime == mtime;

  @override
  int get hashCode => Object.hash(relpath, sha256, mtime);
}

/// Full file payload returned by `GET /sync/get/[relpath]` — the summary
/// plus the raw markdown body. Kept separate from FileSummary so listings
/// stay cheap.
class FileBody {
  const FileBody({
    required this.summary,
    required this.body,
  });

  final FileSummary summary;
  final String body;

  Map<String, dynamic> toJson() => {
        ...summary.toJson(),
        'body': body,
      };
}
