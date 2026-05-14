import 'package:yaml/yaml.dart';

import '../../features/vault/domain/entities/frontmatter.dart';
import '../../features/vault/domain/entities/frontmatter_entry.dart';
import '../../features/vault/domain/entities/page.dart';
import 'type_inference.dart';

/// Splits a markdown file into a frontmatter block + body. Round-tripping is
/// the contract: for unedited pages, `serialise(parse(raw)) == raw` exactly.
///
/// Strategy: never reformat the YAML. We capture the raw YAML block as a
/// string, parse it once for value extraction, and re-emit the original
/// string verbatim on serialise (unless the caller has modified entries).
class FrontmatterParser {
  const FrontmatterParser._();

  /// Marker line — strict: must be exactly `---` followed by a newline.
  static const _delim = '---';

  static ParsedMarkdown parse(String raw) {
    // Only treat as frontmattered if the file *starts with* `---\n`.
    if (!raw.startsWith('$_delim\n') && raw != _delim) {
      return ParsedMarkdown(frontmatter: Frontmatter.empty, body: raw);
    }

    // Find the matching closing `---` line.
    final searchFrom = _delim.length + 1; // skip the opening `---\n`
    final lines = _findClosingDelim(raw, searchFrom);
    if (lines == null) {
      // No closing delim — treat the whole thing as body for safety.
      return ParsedMarkdown(frontmatter: Frontmatter.empty, body: raw);
    }
    final (closeStart, closeEnd) = lines;

    final yamlBlock = raw.substring(searchFrom, closeStart);
    final body = raw.substring(closeEnd);

    final entries = _parseEntries(yamlBlock);
    return ParsedMarkdown(
      frontmatter: Frontmatter(entries: entries, rawYaml: yamlBlock),
      body: body,
    );
  }

  static String serialise(ParsedMarkdown doc) {
    if (doc.frontmatter.isEmpty && doc.frontmatter.rawYaml == null) {
      return doc.body;
    }
    final yaml = doc.frontmatter.rawYaml ?? _emitYaml(doc.frontmatter.entries);
    return '$_delim\n$yaml$_delim\n${doc.body.isNotEmpty && !doc.body.startsWith('\n') ? '' : ''}${doc.body}';
  }

  /// Locate the closing `---\n` (or `---` at EOF). Returns
  /// `(start-of-delim-line, end-of-delim-line-including-newline)` or null.
  static (int, int)? _findClosingDelim(String raw, int from) {
    int idx = from;
    while (idx < raw.length) {
      final nl = raw.indexOf('\n', idx);
      final lineEnd = nl == -1 ? raw.length : nl;
      final line = raw.substring(idx, lineEnd);
      if (line == _delim) {
        // delimiter line; include trailing newline if present
        final endIncl = nl == -1 ? lineEnd : nl + 1;
        return (idx, endIncl);
      }
      if (nl == -1) break;
      idx = nl + 1;
    }
    return null;
  }

  /// Parse the YAML block into an *ordered* list of entries. Uses
  /// `package:yaml`'s `YamlMap`, which preserves insertion order for
  /// flow/block mappings (we rely on this — see test).
  static List<FrontmatterEntry> _parseEntries(String yamlBlock) {
    if (yamlBlock.trim().isEmpty) return const [];
    final dynamic doc = loadYaml(yamlBlock);
    if (doc is! YamlMap) return const [];

    final entries = <FrontmatterEntry>[];
    for (final entry in doc.nodes.entries) {
      final keyNode = entry.key;
      final valueNode = entry.value;
      final key = (keyNode is YamlScalar) ? '${keyNode.value}' : '$keyNode';
      final value = _yamlToDart(valueNode);
      final scalar = _scalarFromBlock(yamlBlock, key);
      entries.add(
        FrontmatterEntry(
          key: key,
          rawScalar: scalar,
          type: TypeInference.infer(value),
          value: value,
        ),
      );
    }
    return entries;
  }

  /// For an entry `key: <raw>`, extract `<raw>` exactly as it appears.
  /// Falls back to `value.toString()` if not found.
  static String _scalarFromBlock(String yamlBlock, String key) {
    final pattern = RegExp('^${RegExp.escape(key)}:[ \t]*(.*)\$', multiLine: true);
    final m = pattern.firstMatch(yamlBlock);
    if (m == null) return '';
    return m.group(1) ?? '';
  }

  static Object? _yamlToDart(dynamic node) {
    if (node is YamlScalar) return node.value;
    if (node is YamlList) return node.map(_yamlToDart).toList(growable: false);
    if (node is YamlMap) {
      return {
        for (final e in node.entries) '${e.key}': _yamlToDart(e.value),
      };
    }
    return node;
  }

  static String _emitYaml(List<FrontmatterEntry> entries) {
    final buf = StringBuffer();
    for (final e in entries) {
      buf.write(e.key);
      buf.write(':');
      if (e.rawScalar.isNotEmpty) {
        buf.write(' ');
        buf.write(e.rawScalar);
      }
      buf.write('\n');
    }
    return buf.toString();
  }
}
