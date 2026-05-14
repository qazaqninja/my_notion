import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/core/ulid/ulid_generator.dart';
import 'package:my_notion/features/editor/domain/attachment_writer.dart';
import 'package:path/path.dart' as p;

void main() {
  test('AttachmentWriter copies file to attachments/<ULID>.<ext>', () async {
    final vault = await Directory.systemTemp.createTemp('quill_atch_vault_');
    final srcDir = await Directory.systemTemp.createTemp('quill_atch_src_');
    final src = File(p.join(srcDir.path, 'photo.PNG'));
    await src.writeAsString('fake png bytes');

    final writer = AttachmentWriter(ulids: const UlidGenerator());
    final rel = await writer.copy(source: src, vaultRoot: vault);

    expect(rel, startsWith('attachments/'));
    expect(rel, endsWith('.png')); // extension lowercased
    final basename = p.basenameWithoutExtension(rel);
    expect(basename, hasLength(26)); // ULID

    final target = File(p.join(vault.path, rel));
    expect(await target.exists(), isTrue);
    expect(await target.readAsString(), equals('fake png bytes'));

    await vault.delete(recursive: true);
    await srcDir.delete(recursive: true);
  });

  test('AttachmentWriter does not collide on duplicate writes', () async {
    final vault = await Directory.systemTemp.createTemp('quill_atch_dup_');
    final srcDir = await Directory.systemTemp.createTemp('quill_atch_dup_src_');
    final src = File(p.join(srcDir.path, 'photo.jpg'));
    await src.writeAsString('x');

    final writer = AttachmentWriter(ulids: const UlidGenerator());
    final a = await writer.copy(source: src, vaultRoot: vault);
    final b = await writer.copy(source: src, vaultRoot: vault);
    expect(a, isNot(equals(b)));

    await vault.delete(recursive: true);
    await srcDir.delete(recursive: true);
  });
}
