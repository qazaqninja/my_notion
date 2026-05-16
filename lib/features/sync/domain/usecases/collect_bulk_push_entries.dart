import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../../../vault/domain/entities/vault_tree.dart';
import '../../presentation/bloc/sync_event.dart';

/// E32 — pure function that walks a [VaultTree] under [vaultRoot] and
/// returns one [SyncBulkPushEntry] per markdown file. Reads each file
/// body and computes its sha256 so the SyncBloc handler can skip
/// already-in-sync entries against `knownShas`.
///
/// Errors reading individual files are swallowed (the corresponding
/// entry is omitted) — partial bulk push is better than aborting the
/// whole operation because one file is locked. The caller decides
/// what to do with the result list.
Future<List<SyncBulkPushEntry>> collectBulkPushEntries({
  required VaultTree tree,
  required String vaultRoot,
}) async {
  final out = <SyncBulkPushEntry>[];
  await _walk(tree.topLevel, vaultRoot, out);
  return out;
}

Future<void> _walk(
  List<VaultNode> nodes,
  String vaultRoot,
  List<SyncBulkPushEntry> out,
) async {
  for (final node in nodes) {
    switch (node) {
      case VaultFolder():
        await _walk(node.children, vaultRoot, out);
      case VaultFile():
        try {
          final file = File('$vaultRoot/${node.relativePath}');
          final body = await file.readAsString();
          final sha = sha256.convert(utf8.encode(body)).toString();
          out.add(SyncBulkPushEntry(
            relpath: node.relativePath,
            body: body,
            sha256: sha,
          ));
        } catch (_) {
          // Skip unreadable files; the rest of the vault still pushes.
        }
    }
  }
}
