import 'dart:convert';
import 'dart:io' as io;

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../../../../core/db/quill_database.dart' hide Page;
import '../../../../core/markdown/wikilink_parser.dart';
import '../../../../core/markdown/yaml_scalar.dart';
import '../../../../core/ulid/ulid_generator.dart';
import '../../../vault/data/indexer.dart';
import '../../../vault/domain/entities/frontmatter.dart';
import '../../../vault/domain/entities/frontmatter_entry.dart';
import '../../../vault/domain/entities/page.dart';
import '../../../vault/domain/repositories/vault_repository.dart';
import '../../domain/entities/database_schema.dart';
import '../../domain/repositories/database_repository.dart';
import '../datasources/database_yaml_parser.dart';

class DatabaseRepositoryImpl implements DatabaseRepository {
  DatabaseRepositoryImpl(
    this._db, {
    VaultRepository? vault,
    Indexer? indexer,
    UlidGenerator? ulids,
  })  : _vault = vault,
        _indexer = indexer,
        _ulids = ulids ?? const UlidGenerator();

  final QuillDatabase _db;
  final VaultRepository? _vault;
  final Indexer? _indexer;
  final UlidGenerator _ulids;

  @override
  Future<List<DatabaseSchema>> listDatabases() async {
    final rows = await _db.select(_db.databases).get();
    final schemas = <DatabaseSchema>[];
    for (final r in rows) {
      final s = DatabaseYamlParser.parse(r.schemaYaml, folderPath: r.folderPath);
      if (s != null) schemas.add(s);
    }
    return schemas;
  }

  @override
  Future<DatabaseSchema?> getDatabase(String id) async {
    final row = await (_db.select(_db.databases)..where((d) => d.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return null;
    return DatabaseYamlParser.parse(row.schemaYaml, folderPath: row.folderPath);
  }

  @override
  Future<List<DatabasePageRow>> getRows(String databaseId) async {
    final rows = await (_db.select(_db.pages)
          ..where((p) => p.databaseId.equals(databaseId))
          ..orderBy([(p) => OrderingTerm.asc(p.title)]))
        .get();
    return [
      for (final row in rows)
        DatabasePageRow(
          ulid: row.ulid,
          title: row.title,
          relativePath: row.relativePath,
          cells: _decodeCells(row.frontmatterJson),
          mtimeMs: row.mtimeMs,
          createdAt: _stringCell(row.frontmatterJson, 'created_at'),
        ),
    ];
  }

  static String? _stringCell(String fmJson, String key) {
    if (fmJson.isEmpty) return null;
    try {
      final decoded = jsonDecode(fmJson);
      if (decoded is! Map<String, dynamic>) return null;
      final entries = decoded['entries'];
      if (entries is! List) return null;
      for (final e in entries) {
        if (e is Map<String, dynamic> && e['key'] == key) {
          final raw = e['rawScalar']?.toString();
          return (raw == null || raw.isEmpty) ? null : raw;
        }
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<DatabasePageRow> updateCell({
    required String ulid,
    required ColumnDef column,
    required Object? newValue,
    required io.Directory vaultRoot,
  }) async {
    if (_vault == null || _indexer == null) {
      throw StateError('updateCell requires vault + indexer wiring');
    }
    final row = await (_db.select(_db.pages)..where((p) => p.ulid.equals(ulid)))
        .getSingleOrNull();
    if (row == null) throw StateError('Page not found: $ulid');
    final page = await _vault.readPage(row.relativePath, root: vaultRoot);
    // Honour the same locked / permissions: read_only contract that
    // EditorBloc enforces (editor_bloc.dart:261 / 290). Without this
    // check, DB cell edits would silently bypass the page lock —
    // they write directly through readPage / writePage and don't hit
    // the bloc at all.
    final lockedVal = page.frontmatter.get('locked');
    final permVal = '${page.frontmatter.get('permissions')}'.trim().toLowerCase();
    final isLocked = lockedVal == true ||
        '$lockedVal'.toLowerCase() == 'true' ||
        permVal == 'read_only' ||
        permVal == 'read-only' ||
        permVal == 'readonly' ||
        permVal == 'locked';
    if (isLocked) {
      throw const PageLockedException();
    }
    final previousValue = page.frontmatter.get(column.key);
    final next = _writeCellEntry(page.frontmatter, column, newValue);
    final updated = page.copyWith(frontmatter: next);
    await _vault.writePage(updated, root: vaultRoot);
    await _indexer.upsertPage(updated);
    // Two-way relation propagation: when this column declares an
    // inverse, diff the old/new ULID sets and mirror the change on
    // each linked page's inverse column. Self-references are skipped
    // so a self-pointing row doesn't recurse.
    if (column.type == ColumnType.relation && column.inverseOf != null) {
      await _propagateInverse(
        sourceUlid: ulid,
        oldValue: previousValue,
        newValue: newValue,
        inverseColumn: column.inverseOf!,
        vaultRoot: vaultRoot,
      );
    }
    return DatabasePageRow(
      ulid: updated.ulid,
      title: updated.title,
      relativePath: updated.relativePath,
      cells: _cellsFromEntries(updated.frontmatter.entries),
    );
  }

  Future<void> _propagateInverse({
    required String sourceUlid,
    required dynamic oldValue,
    required dynamic newValue,
    required String inverseColumn,
    required io.Directory vaultRoot,
  }) async {
    final vault = _vault;
    final indexer = _indexer;
    if (vault == null || indexer == null) return;
    final oldSet = _ulidsIn(oldValue);
    final newSet = _ulidsIn(newValue);
    final added = newSet.difference(oldSet);
    final removed = oldSet.difference(newSet);
    if (added.isEmpty && removed.isEmpty) return;
    for (final linkedUlid in {...added, ...removed}) {
      if (linkedUlid == sourceUlid) continue;
      final linkedRow = await (_db.select(_db.pages)
            ..where((p) => p.ulid.equals(linkedUlid)))
          .getSingleOrNull();
      if (linkedRow == null) continue;
      final linked =
          await vault.readPage(linkedRow.relativePath, root: vaultRoot);
      final mutated = _mirrorRelation(
        linked.frontmatter,
        inverseColumn,
        addUlid: added.contains(linkedUlid) ? sourceUlid : null,
        removeUlid: removed.contains(linkedUlid) ? sourceUlid : null,
      );
      if (identical(mutated, linked.frontmatter)) continue;
      final saved = linked.copyWith(frontmatter: mutated);
      await vault.writePage(saved, root: vaultRoot);
      await indexer.upsertPage(saved);
    }
  }

  static Set<String> _ulidsIn(dynamic v) {
    if (v == null) return const {};
    final out = <String>{};
    if (v is List) {
      for (final item in v) {
        out.addAll(WikilinkParser.find('$item').map((w) => w.ulid));
      }
    } else {
      out.addAll(WikilinkParser.find('$v').map((w) => w.ulid));
    }
    return out;
  }

  /// Public test entry-point for the inverse-relation rewriter — see
  /// `_mirrorRelation` for the contract. Exposed so it's exercisable
  /// without filesystem + Drift setup.
  static Frontmatter mirrorRelation(
    Frontmatter fm,
    String key, {
    String? addUlid,
    String? removeUlid,
  }) =>
      _mirrorRelation(fm, key, addUlid: addUlid, removeUlid: removeUlid);

  /// Mutate [fm]'s [key] entry to add or remove a `[[ULID]]` wikilink.
  /// Always re-emits the entry as a YAML flow-list to keep the round-
  /// trip deterministic. Idempotent — adding a ULID already present
  /// or removing one that isn't there returns the original frontmatter.
  static Frontmatter _mirrorRelation(
    Frontmatter fm,
    String key, {
    String? addUlid,
    String? removeUlid,
  }) {
    final existing = fm.entries.indexWhere((e) => e.key == key);
    final currentValue = existing >= 0 ? fm.entries[existing].rawScalar : '';
    final currentSet = _ulidsIn(currentValue);
    final next = Set<String>.from(currentSet);
    if (addUlid != null) next.add(addUlid);
    if (removeUlid != null) next.remove(removeUlid);
    if (next.length == currentSet.length &&
        next.containsAll(currentSet) &&
        currentSet.containsAll(next)) {
      return fm;
    }
    final ordered = next.toList()..sort();
    final raw = ordered.isEmpty
        ? ''
        : '[${ordered.map((u) => '[[$u]]').join(', ')}]';
    final newEntries = List<FrontmatterEntry>.from(fm.entries);
    final entry = FrontmatterEntry(
      key: key,
      rawScalar: raw,
      type: FrontmatterType.relation,
      value: ordered,
    );
    if (existing >= 0) {
      newEntries[existing] = entry;
    } else if (ordered.isNotEmpty) {
      newEntries.add(entry);
    }
    return Frontmatter(entries: newEntries);
  }

  @override
  Future<DatabasePageRow> createRow({
    required DatabaseSchema schema,
    required String title,
    required io.Directory vaultRoot,
  }) async {
    if (_vault == null || _indexer == null) {
      throw StateError('createRow requires vault + indexer wiring');
    }
    final ulid = _ulids.generate();
    final fileName = _safeFileName(title);
    final relativePath = p.join(schema.folderPath, '$fileName.md');

    // Seed cell entries from the optional row template — frontmatter
    // values copied verbatim (sans id / title which the new row
    // replaces). Falls back to empty placeholders per declared column.
    final templateEntries = <String, FrontmatterEntry>{};
    String templateBody = '';
    if (schema.rowTemplate != null && schema.rowTemplate!.isNotEmpty) {
      try {
        final tplPage =
            await _vault.readPage(schema.rowTemplate!, root: vaultRoot);
        for (final e in tplPage.frontmatter.entries) {
          if (e.key == 'id' || e.key == 'title') continue;
          templateEntries[e.key] = e;
        }
        templateBody = tplPage.body;
      } catch (_) {
        // Missing/unreadable template = no seeding. Don't fail the create.
      }
    }

    final entries = <FrontmatterEntry>[
      FrontmatterEntry(
        key: 'id',
        rawScalar: ulid,
        type: FrontmatterType.ulid,
        value: ulid,
      ),
      FrontmatterEntry(
        key: 'title',
        rawScalar: yamlSafeScalar(title),
        type: FrontmatterType.text,
        value: title,
      ),
      for (final c in schema.columns)
        if (c.key != 'id' && c.key != 'title')
          templateEntries.remove(c.key) ??
              FrontmatterEntry(
                key: c.key,
                rawScalar: '',
                type: _columnToFrontmatterType(c.type),
                value: null,
              ),
      // Any leftover template entries that aren't declared in the schema —
      // keep them so the template can carry extras (e.g. `tags`).
      ...templateEntries.values,
    ];
    final page = Page(
      ulid: ulid,
      relativePath: relativePath,
      title: title,
      frontmatter: Frontmatter(entries: entries),
      body: templateBody,
      mtimeMs: DateTime.now().millisecondsSinceEpoch,
    );
    await _vault.writePage(page, root: vaultRoot);
    await _indexer.upsertPage(page);
    // Set databaseId on the freshly inserted row.
    await (_db.update(_db.pages)..where((row) => row.ulid.equals(ulid)))
        .write(PagesCompanion(databaseId: Value(schema.id)));
    return DatabasePageRow(
      ulid: ulid,
      title: title,
      relativePath: relativePath,
      cells: _cellsFromEntries(entries),
    );
  }

  /// Builds the next Frontmatter with [column].key set to [newValue].
  /// Preserves declared order; appends if the key is new.
  static Frontmatter _writeCellEntry(
    Frontmatter fm,
    ColumnDef column,
    Object? newValue,
  ) {
    final fmType = _columnToFrontmatterType(column.type);
    final (raw, parsed) = _rawAndValueFor(column.type, newValue);
    final entry = FrontmatterEntry(
      key: column.key,
      rawScalar: raw,
      type: fmType,
      value: parsed,
    );
    final next = <FrontmatterEntry>[];
    bool replaced = false;
    for (final e in fm.entries) {
      if (e.key == column.key) {
        next.add(entry);
        replaced = true;
      } else {
        next.add(e);
      }
    }
    if (!replaced) next.add(entry);
    return Frontmatter(entries: next);
  }

  static (String, Object?) _rawAndValueFor(ColumnType t, Object? v) {
    if (v == null) return ('', null);
    final s = v is String ? v : '$v';
    switch (t) {
      case ColumnType.number:
        final n = num.tryParse(s.trim());
        // When the value parses as a number, n.toString() is always
        // YAML-safe ('123', '12.5'). When parse fails, fall back to
        // the raw string but escape it — a user typing 'foo: bar'
        // into a number column shouldn't corrupt the YAML.
        return (n != null ? n.toString() : yamlSafeScalar(s), n ?? s);
      case ColumnType.checkbox:
        final b = s.trim().toLowerCase() == 'true';
        return (b ? 'true' : 'false', b);
      case ColumnType.multi:
        final parts = [
          for (final p in s.split(','))
            if (p.trim().isNotEmpty) p.trim(),
        ];
        return ('[${parts.map(yamlFlowItem).join(', ')}]', parts);
      case ColumnType.date:
        // The UI date picker emits YYYY-MM-DD which is always safe,
        // but a CSV / external import could route non-date text
        // ('next week', 'TBD: q3') through this branch. Route through
        // yamlSafeScalar — ISO dates are short alphanumerics so the
        // escape is a no-op for them.
        return (yamlSafeScalar(s), s);
      case ColumnType.text:
      case ColumnType.select:
      case ColumnType.relation:
      case ColumnType.formula:
      case ColumnType.rollup:
      case ColumnType.person:
      case ColumnType.file:
      case ColumnType.createdTime:
      case ColumnType.lastEditedTime:
        return (yamlSafeScalar(s), s);
    }
  }

  static FrontmatterType _columnToFrontmatterType(ColumnType t) => switch (t) {
        ColumnType.text => FrontmatterType.text,
        ColumnType.number => FrontmatterType.number,
        ColumnType.date => FrontmatterType.date,
        ColumnType.select => FrontmatterType.select,
        ColumnType.multi => FrontmatterType.multi,
        ColumnType.relation => FrontmatterType.relation,
        ColumnType.formula => FrontmatterType.formula,
        ColumnType.rollup => FrontmatterType.formula,
        ColumnType.person => FrontmatterType.text,
        ColumnType.file => FrontmatterType.file,
        ColumnType.checkbox => FrontmatterType.checkbox,
        // The two timestamp types are derived metadata — they're never
        // written back to frontmatter, so they're treated as plain text
        // if a value flows through this path (defensive fallback).
        ColumnType.createdTime => FrontmatterType.text,
        ColumnType.lastEditedTime => FrontmatterType.text,
      };

  static Map<String, dynamic> _cellsFromEntries(List<FrontmatterEntry> entries) {
    return {for (final e in entries) e.key: e.rawScalar};
  }

  static String _safeFileName(String title) {
    // Strip path separators and reserved characters; collapse spaces.
    final stripped = title
        .replaceAll(RegExp(r'[\\/<>:"|?*]+'), '-')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return stripped.isEmpty ? 'Untitled' : stripped;
  }

  Map<String, dynamic> _decodeCells(String fmJson) {
    if (fmJson.isEmpty) return const {};
    try {
      final decoded = jsonDecode(fmJson);
      if (decoded is! Map<String, dynamic>) return const {};
      final entries = decoded['entries'];
      if (entries is! List) return const {};
      final out = <String, dynamic>{};
      for (final e in entries) {
        if (e is Map<String, dynamic>) {
          final key = e['key']?.toString();
          final raw = e['rawScalar']?.toString();
          if (key != null) out[key] = raw ?? '';
        }
      }
      return out;
    } catch (_) {
      return const {};
    }
  }
}

