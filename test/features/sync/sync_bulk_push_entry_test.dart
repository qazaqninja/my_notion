import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/sync/domain/entities/sync_bulk_push_entry.dart';

/// E36 — confirms `SyncBulkPushEntry` has value equality so
/// `SyncPushAllRequested` events compare correctly under Equatable's
/// list-equality semantics. Before the move from
/// presentation/bloc/sync_event.dart this class had identity equality
/// only, which broke `blocTest` `expect` assertions on bulk-push
/// batches.
void main() {
  group('SyncBulkPushEntry', () {
    test('two entries with the same fields compare equal', () {
      const a = SyncBulkPushEntry(
        relpath: 'a.md',
        body: 'x',
        sha256: 'sha-a',
      );
      const b = SyncBulkPushEntry(
        relpath: 'a.md',
        body: 'x',
        sha256: 'sha-a',
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('different sha distinguishes the entry', () {
      const a = SyncBulkPushEntry(
        relpath: 'a.md',
        body: 'x',
        sha256: 'sha-a',
      );
      const b = SyncBulkPushEntry(
        relpath: 'a.md',
        body: 'x',
        sha256: 'sha-b',
      );
      expect(a, isNot(equals(b)));
    });

    test('props covers all three fields', () {
      const e = SyncBulkPushEntry(
        relpath: 'r',
        body: 'b',
        sha256: 's',
      );
      expect(e.props, ['r', 'b', 's']);
    });
  });
}
