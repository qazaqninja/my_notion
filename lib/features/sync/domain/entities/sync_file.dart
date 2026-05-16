import 'package:equatable/equatable.dart';

/// Per-file summary returned by `GET /sync/list` and `PUT /sync/put` on
/// the v2 backend. Mirrors `backend/lib/sync/file_summary.dart`'s shape.
class SyncFileSummary extends Equatable {
  const SyncFileSummary({
    required this.relpath,
    required this.sha256,
    required this.mtime,
  });

  factory SyncFileSummary.fromJson(Map<String, dynamic> json) =>
      SyncFileSummary(
        relpath: json['relpath'] as String,
        sha256: json['sha256'] as String,
        mtime: DateTime.parse(json['mtime'] as String),
      );

  final String relpath;
  final String sha256;
  final DateTime mtime;

  Map<String, dynamic> toJson() => {
        'relpath': relpath,
        'sha256': sha256,
        'mtime': mtime.toIso8601String(),
      };

  @override
  List<Object?> get props => [relpath, sha256, mtime];
}

/// Full file payload returned by `GET /sync/get/[relpath]`. Carries the
/// summary plus the raw markdown body. Mirrors `FileBody` server-side.
class SyncFileBody extends Equatable {
  const SyncFileBody({required this.summary, required this.body});

  factory SyncFileBody.fromJson(Map<String, dynamic> json) => SyncFileBody(
        summary: SyncFileSummary.fromJson(json),
        body: json['body'] as String,
      );

  final SyncFileSummary summary;
  final String body;

  @override
  List<Object?> get props => [summary, body];
}
