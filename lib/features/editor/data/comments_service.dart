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
  });

  /// Stable ULID for this comment — lets the UI track edits/deletes.
  final String id;
  final String author;
  final String body;
  final DateTime timestamp;
  final bool resolved;

  PageComment copyWith({String? body, bool? resolved}) => PageComment(
        id: id,
        author: author,
        body: body ?? this.body,
        timestamp: timestamp,
        resolved: resolved ?? this.resolved,
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
        out.add(PageComment(
          id: '${node['id'] ?? ulids.generate()}',
          author: '${node['author'] ?? ''}',
          body: '${node['body'] ?? ''}',
          timestamp:
              DateTime.tryParse('${node['at'] ?? ''}') ?? DateTime.now(),
          resolved: node['resolved'] == true,
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
  }) async {
    final existing = await list(vaultRoot, pageUlid);
    final next = [
      ...existing,
      PageComment(
        id: ulids.generate(),
        author: author,
        body: body,
        timestamp: DateTime.now(),
      ),
    ];
    await _save(vaultRoot, pageUlid, next);
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
