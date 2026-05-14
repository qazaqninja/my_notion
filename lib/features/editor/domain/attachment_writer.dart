import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/ulid/ulid_generator.dart';

/// Copies an image into the vault's `attachments/` folder, returning a
/// vault-relative path suitable for splicing into markdown:
///
///     ![<alt>](attachments/<ULID>.<ext>)
///
/// The filename is `<ULID>.<original-extension-lowercased>` so two pastes
/// of "screenshot.png" don't collide and we never leak the user's original
/// filename into the vault.
class AttachmentWriter {
  const AttachmentWriter({this.ulids = const UlidGenerator()});

  final UlidGenerator ulids;

  /// Copies [source] into `<vaultRoot>/attachments/<ULID>.<ext>` and
  /// returns the vault-relative path (`attachments/<ULID>.<ext>`).
  Future<String> copy({
    required File source,
    required Directory vaultRoot,
  }) async {
    final ext = p.extension(source.path).toLowerCase();
    final ulid = ulids.generate();
    final relative = p.join('attachments', '$ulid$ext');
    final target = File(p.join(vaultRoot.path, relative));
    await target.parent.create(recursive: true);
    await source.copy(target.path);
    return relative;
  }
}
