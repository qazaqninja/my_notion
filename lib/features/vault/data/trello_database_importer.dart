import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/markdown/yaml_scalar.dart';
import '../../../core/ulid/ulid_generator.dart';
import 'trello_to_database.dart';

/// Imports a Trello board JSON export into a Quill vault as a database
/// folder + `.database.yaml` + one .md per open card.
class TrelloDatabaseImporter {
  const TrelloDatabaseImporter._();

  static const _ulids = UlidGenerator();

  static Future<TrelloImportSummary> importTo(
    File source,
    Directory vaultRoot,
  ) async {
    final raw = await source.readAsString();
    final board = TrelloToDatabase.convert(raw);
    if (board == null) {
      throw const FormatException('Not a Trello board JSON');
    }
    final folderName = _safeFolderName(board.name);
    final folder = Directory(p.join(vaultRoot.path, folderName));
    await folder.create(recursive: true);

    // Schema file
    final dbId = _ulids.generate();
    final schemaYaml = _renderSchema(
      dbId: dbId,
      name: board.name,
      statusOptions: board.statusOptions,
    );
    await File(p.join(folder.path, '.database.yaml'))
        .writeAsString(schemaYaml);

    final imported = p.basename(source.path);
    final written = <ImportedTrelloCard>[];
    for (final card in board.cards) {
      try {
        final ulid = _ulids.generate();
        final safe = _safeFileName(card.title);
        final rel = p.join(folderName, '$safe.md');
        final out = File(p.join(vaultRoot.path, rel));
        final fmBuf = StringBuffer('---\n');
        fmBuf.writeln('id: $ulid');
        fmBuf.writeln('title: ${yamlSafeScalar(card.title)}');
        if (card.status.isNotEmpty) {
          fmBuf.writeln('status: ${yamlSafeScalar(card.status)}');
        }
        if (card.labels.isNotEmpty) {
          fmBuf.writeln('labels: [${card.labels.join(', ')}]');
        }
        if (card.due != null) fmBuf.writeln('due: ${card.due}');
        fmBuf.writeln('imported_from: ${yamlSafeScalar(imported)}');
        fmBuf.writeln('---');
        fmBuf.writeln();
        await out.writeAsString('${fmBuf.toString()}${card.body.trim()}\n');
        written.add(ImportedTrelloCard(
          ulid: ulid,
          relativePath: rel,
          title: card.title,
        ));
      } catch (e, st) {
        // Per-card robustness (M731-M733).
        // ignore: avoid_print
        print('trello_importer: skipping card "${card.title}" — $e\n$st');
      }
    }
    return TrelloImportSummary(
      folder: folderName,
      cards: written,
    );
  }

  static String _renderSchema({
    required String dbId,
    required String name,
    required List<String> statusOptions,
  }) {
    final buf = StringBuffer();
    buf.writeln('id: $dbId');
    buf.writeln('name: ${yamlSafeScalar(name)}');
    buf.writeln('icon: T');
    buf.writeln('color: "#5A82B4"');
    buf.writeln('schema:');
    buf.writeln('  title:');
    buf.writeln('    type: text');
    buf.writeln('  status:');
    buf.writeln('    type: select');
    if (statusOptions.isNotEmpty) {
      buf.writeln('    options:');
      for (final o in statusOptions) {
        buf.writeln('      - ${yamlSafeScalar(o)}');
      }
    }
    buf.writeln('  labels:');
    buf.writeln('    type: multi');
    buf.writeln('  due:');
    buf.writeln('    type: date');
    buf.writeln('views:');
    buf.writeln('  - id: all');
    buf.writeln('    name: All cards');
    buf.writeln('    type: table');
    buf.writeln('  - id: kanban');
    buf.writeln('    name: Kanban');
    buf.writeln('    type: board');
    buf.writeln('    group_by: status');
    return buf.toString();
  }

  static String _safeFolderName(String name) {
    var s = 'Trello — ${name.trim()}'
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '-');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (s.length > 100) s = s.substring(0, 100);
    return s;
  }

  static String _safeFileName(String title) {
    var s = title.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '-');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (s.isEmpty) s = 'Card';
    if (s.length > 100) s = s.substring(0, 100);
    return s;
  }

}

class ImportedTrelloCard {
  const ImportedTrelloCard({
    required this.ulid,
    required this.relativePath,
    required this.title,
  });
  final String ulid;
  final String relativePath;
  final String title;
}

class TrelloImportSummary {
  const TrelloImportSummary({required this.folder, required this.cards});
  final String folder;
  final List<ImportedTrelloCard> cards;
}
