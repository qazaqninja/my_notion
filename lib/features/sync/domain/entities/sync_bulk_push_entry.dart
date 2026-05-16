import 'package:equatable/equatable.dart';

/// One entry in a `SyncPushAllRequested` batch: the local body the
/// caller wants the server to mirror, plus the local sha256 so the
/// bloc can skip relpaths whose `knownShas` already matches.
///
/// Lives in the domain layer (E36 / orchestrator finding CA-07): the
/// `collect_bulk_push_entries` usecase produces values of this type,
/// so co-locating it with `SyncBulkPushRequested` in the presentation/
/// bloc layer would invert the Clean-Architecture dependency direction
/// (domain → presentation). Presentation re-exports the type for
/// convenience.
class SyncBulkPushEntry extends Equatable {
  const SyncBulkPushEntry({
    required this.relpath,
    required this.body,
    required this.sha256,
  });
  final String relpath;
  final String body;
  final String sha256;

  @override
  List<Object?> get props => [relpath, body, sha256];
}
