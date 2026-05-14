import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../../../core/ulid/ulid_generator.dart';

/// One thread entry on a page. Stored in
/// `<vaultRoot>/.quill/comments/<page-ulid>.yaml` as a list of maps.
class PageComment {
  const PageComment({
    required this.id,
    required this.author,
    required this.body,
    required this.timestamp,
    this.resolved = false,
    this.blockId,
  });

  /// Stable ULID for this comment — lets the UI track edits/deletes.
  final String id;
  final String author;
  final String body;
  final DateTime timestamp;
  final bool resolved;

  /// When non-null, this comment is anchored to a block whose source
  /// ends with ` ^<blockId>`. Page-level comments leave it null.
  /// Surfaced to the UI as a small "block" pill in the threads dialog.
  final String? blockId;

  PageComment copyWith({String? body, bool? resolved, String? blockId}) =>
      PageComment(
        id: id,
        author: author,
        body: body ?? this.body,
        timestamp: timestamp,
        resolved: resolved ?? this.resolved,
        blockId: blockId ?? this.blockId,
      );
}

class CommentsService {
  const CommentsService({this.ulids = const UlidGenerator()});
  final UlidGenerator ulids;

  static String _file(Directory vaultRoot, String pageUlid) =>
      p.join(vaultRoot.path, '.quill', 'comments', '$pageUlid.yaml');

  Future<List<PageComment>> list(Directory vaultRoot, String pageUlid) async {
    final file = File(_file(vaultRoot, pageUlid));
    if (!await file.exists()) return const [];
    try {
      final raw = await file.readAsString();
      final dynamic doc = loadYaml(raw);
      if (doc is! YamlList) return const [];
      final out = <PageComment>[];
      for (final node in doc) {
        if (node is! YamlMap) continue;
        final rawBlockId = node['block_id'];
        out.add(PageComment(
          id: '${node['id'] ?? ulids.generate()}',
          author: '${node['author'] ?? ''}',
          body: '${node['body'] ?? ''}',
          timestamp:
              DateTime.tryParse('${node['at'] ?? ''}') ?? DateTime.now(),
          resolved: node['resolved'] == true,
          blockId: rawBlockId != null && '$rawBlockId'.trim().isNotEmpty
              ? '$rawBlockId'.trim()
              : null,
        ));
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  Future<void> add(
    Directory vaultRoot,
    String pageUlid, {
    required String author,
    required String body,
    String? blockId,
  }) async {
    final existing = await list(vaultRoot, pageUlid);
    final next = [
      ...existing,
      PageComment(
        id: ulids.generate(),
        author: author,
        body: body,
        timestamp: DateTime.now(),
        blockId: blockId,
      ),
    ];
    await _save(vaultRoot, pageUlid, next);
  }

  /// Comments anchored to a specific block — empty when [blockId] has
  /// no matches. Useful for the inline "block comments" affordance in
  /// the renderer.
  Future<List<PageComment>> listForBlock(
    Directory vaultRoot,
    String pageUlid,
    String blockId,
  ) async {
    final all = await list(vaultRoot, pageUlid);
    return [for (final c in all) if (c.blockId == blockId) c];
  }

  Future<void> delete(
      Directory vaultRoot, String pageUlid, String commentId) async {
    final remaining = (await list(vaultRoot, pageUlid))
        .where((c) => c.id != commentId)
        .toList();
    await _save(vaultRoot, pageUlid, remaining);
  }

  Future<void> setResolved(Directory vaultRoot, String pageUlid,
      String commentId, bool resolved) async {
    final updated = (await list(vaultRoot, pageUlid)).map((c) {
      return c.id == commentId ? c.copyWith(resolved: resolved) : c;
    }).toList();
    await _save(vaultRoot, pageUlid, updated);
  }

  Future<void> _save(
    Directory vaultRoot,
    String pageUlid,
    List<PageComment> comments,
  ) async {
    final file = File(_file(vaultRoot, pageUlid));
    if (comments.isEmpty) {
      if (await file.exists()) await file.delete();
      return;
    }
    await file.parent.create(recursive: true);
    final buf = StringBuffer();
    for (final c in comments) {
      buf.writeln('- id: ${c.id}');
      buf.writeln('  author: ${_yamlQuote(c.author)}');
      buf.writeln('  at: ${c.timestamp.toUtc().toIso8601String()}');
      if (c.resolved) buf.writeln('  resolved: true');
      if (c.blockId != null) buf.writeln('  block_id: ${c.blockId}');
      buf.writeln('  body: ${_yamlQuote(c.body)}');
    }
    await file.writeAsString(buf.toString());
  }

  static String _yamlQuote(String s) {
    // Always single-line quoted with escaped quotes. Multi-line bodies
    // collapse newlines to literal \n — comments aren't expected to be
    // novel-length.
    final escaped = s.replaceAll('\\', r'\\').replaceAll('"', r'\"').replaceAll('\n', r'\n');
    return '"$escaped"';
  }
}
