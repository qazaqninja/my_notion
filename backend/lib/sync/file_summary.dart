import 'package:meta/meta.dart';

/// Per-file summary returned by `GET /sync/list`. The body itself is NOT
/// included — clients fetch bodies on demand via `GET /sync/get/<relpath>`
/// (slice E10), or push their own via `PUT /sync/put/<relpath>` (slice E9).
@immutable
class FileSummary {
  /// Construct a summary row hydrated from `vault_files`.
  const FileSummary({
    required this.relpath,
    required this.sha256,
    required this.mtime,
  });

  /// Vault-relative path, forward-slash separated. Per-user namespaced.
  final String relpath;

  /// SHA-256 of the raw markdown body — used as the optimistic-
  /// concurrency token in `PUT /sync/put/<relpath>` (E11).
  final String sha256;

  /// Server-side last-modified timestamp (UTC, set by Postgres `now()`).
  final DateTime mtime;

  /// Serialize to the wire shape returned by `GET /sync/list`.
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
@immutable
class FileBody {
  /// Construct a full payload (summary metadata + raw markdown body).
  const FileBody({
    required this.summary,
    required this.body,
  });

  /// Per-file summary metadata: relpath, sha256, mtime.
  final FileSummary summary;

  /// Raw markdown source as stored in `vault_files.body`.
  final String body;

  /// Serialize to the wire shape returned by `GET /sync/get/<relpath>`
  /// — summary fields inlined alongside the body.
  Map<String, dynamic> toJson() => {
        ...summary.toJson(),
        'body': body,
      };

  @override
  bool operator ==(Object other) =>
      other is FileBody && other.summary == summary && other.body == body;

  @override
  int get hashCode => Object.hash(summary, body);
}
