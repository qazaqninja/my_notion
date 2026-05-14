import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/ulid/ulid_generator.dart';

/// Appends a captured note to `<vault>/Inbox/Quick capture.md`. If the
/// file doesn't exist, creates it with id/title/created_at frontmatter.
/// Each capture is a new bullet line prefixed with the local-time ISO
/// timestamp so the file reads as a chronological log.
class QuickCapture {
  const QuickCapture._();

  static const _ulids = UlidGenerator();

  /// Returns the relative path written to (always "Inbox/Quick capture.md").
  static Future<String> append(
    String text,
    Directory vaultRoot,
  ) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('empty capture');
    }
    final folder = Directory(p.join(vaultRoot.path, 'Inbox'));
    await folder.create(recursive: true);
    final relativePath = 'Inbox/Quick capture.md';
    final file = File(p.join(vaultRoot.path, relativePath));
    final exists = await file.exists();
    if (!exists) {
      final ulid = _ulids.generate();
      final now = DateTime.now().toIso8601String().substring(0, 10);
      final buf = StringBuffer('---\n')
        ..writeln('id: $ulid')
        ..writeln('title: Quick capture')
        ..writeln('created_at: $now')
        ..writeln('---')
        ..writeln()
        ..writeln('Append-only log. New captures land at the top.')
        ..writeln();
      await file.writeAsString(buf.toString());
    }
    // Read, locate the body (after closing `---`), prepend new entry at
    // the top of the body so newest reads first.
    final raw = await file.readAsString();
    final delim = '\n---\n';
    final endOfFm = raw.indexOf(delim);
    if (endOfFm < 0) {
      throw const FormatException('quick capture missing frontmatter');
    }
    final headerEnd = endOfFm + delim.length;
    final body = raw.substring(headerEnd);
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll('T', ' ')
        .substring(0, 19);
    final entry = '- $stamp · $trimmed\n';
    final newBody = '\n$entry${body.trimLeft().isEmpty ? '' : body}';
    await file.writeAsString(
        '${raw.substring(0, headerEnd)}$newBody');
    return relativePath;
  }
}
