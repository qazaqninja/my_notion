import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/core/db/quill_database.dart';
import 'package:my_notion/core/markdown/frontmatter_parser.dart';
import 'package:my_notion/core/ulid/ulid_generator.dart';
import 'package:my_notion/features/vault/data/datasources/vault_fs_datasource.dart';
import 'package:my_notion/features/vault/data/indexer.dart';
import 'package:my_notion/features/vault/data/repositories/vault_repository_impl.dart';
import 'package:my_notion/features/vault/presentation/bloc/vault_bloc.dart';
import 'package:my_notion/features/vault/presentation/bloc/vault_event.dart';
import 'package:my_notion/features/vault/presentation/bloc/vault_state.dart';
import 'package:path/path.dart' as p;

void main() {
  test('CreatePage writes a new .md at the vault root and indexes it', () async {
    final tmp = await Directory.systemTemp.createTemp('quill_create_page_');
    final db = QuillDatabase.forTesting(NativeDatabase.memory());
    final repo = VaultRepositoryImpl(
      VaultFsDatasource(ulids: const UlidGenerator()),
    );
    final indexer = Indexer(db, repo.datasource);
    final bloc = VaultBloc(repo: repo, indexer: indexer, db: db);

    bloc.add(LoadFromPath(tmp.path));
    // Wait for VaultLoaded to settle.
    final loadedAt = DateTime.now();
    while (bloc.state is! VaultLoaded) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      if (DateTime.now().difference(loadedAt).inSeconds > 3) {
        fail('Vault never reached VaultLoaded: ${bloc.state}');
      }
    }

    String? createdUlid;
    bloc.add(CreatePage(title: 'Hello world', onCreated: (u) => createdUlid = u));
    final createdAt = DateTime.now();
    while (createdUlid == null) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      if (DateTime.now().difference(createdAt).inSeconds > 3) {
        fail('onCreated never fired');
      }
    }

    final file = File(p.join(tmp.path, 'Hello world.md'));
    expect(await file.exists(), isTrue);
    final raw = await file.readAsString();
    final parsed = FrontmatterParser.parse(raw);
    expect(parsed.frontmatter.id, equals(createdUlid));
    expect(parsed.frontmatter.title, equals('Hello world'));
    // M316: auto-stamped created_at on a freshly created page.
    final createdAtField = parsed.frontmatter.find('created_at');
    expect(createdAtField, isNotNull);
    expect(createdAtField!.rawScalar,
        matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
    // No workspace user configured here, so created_by stays absent.
    expect(parsed.frontmatter.find('created_by'), isNull);

    // The new page is in Drift.
    final pages = await db.select(db.pages).get();
    expect(pages.any((row) => row.ulid == createdUlid), isTrue);

    await bloc.close();
    await db.close();
    await tmp.delete(recursive: true);
  });

  test('CreatePage YAML-escapes titles containing reserved glyphs (M686)',
      () async {
    final tmp =
        await Directory.systemTemp.createTemp('quill_create_page_unsafe_');
    final db = QuillDatabase.forTesting(NativeDatabase.memory());
    final repo = VaultRepositoryImpl(
      VaultFsDatasource(ulids: const UlidGenerator()),
    );
    final indexer = Indexer(db, repo.datasource);
    final bloc = VaultBloc(repo: repo, indexer: indexer, db: db);

    bloc.add(LoadFromPath(tmp.path));
    final loadedAt = DateTime.now();
    while (bloc.state is! VaultLoaded) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      if (DateTime.now().difference(loadedAt).inSeconds > 3) {
        fail('Vault never reached VaultLoaded: ${bloc.state}');
      }
    }

    // A title with both `:` and `#` — without escape, the on-disk YAML
    // would look like `title: foo: bar #tag` which parses back as a
    // nested map / comment-stripped string, losing the original.
    const unsafe = 'foo: bar #tag';
    String? created;
    bloc.add(CreatePage(title: unsafe, onCreated: (u) => created = u));
    final createdAt = DateTime.now();
    while (created == null) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      if (DateTime.now().difference(createdAt).inSeconds > 3) {
        fail('onCreated never fired');
      }
    }

    // _safeFileName collapses `:`/`#` to `-`; the on-disk filename is
    // sanitised but the title preserved verbatim through the YAML
    // double-quote escape.
    final files =
        await tmp.list().where((f) => f.path.endsWith('.md')).toList();
    expect(files, hasLength(1));
    final raw = await File(files.first.path).readAsString();
    expect(raw, contains('title: "foo: bar #tag"'),
        reason: 'title scalar must be double-quoted on disk');
    final parsed = FrontmatterParser.parse(raw);
    expect(parsed.frontmatter.title, equals(unsafe),
        reason: 'round-trip must recover the original title verbatim');

    await bloc.close();
    await db.close();
    await tmp.delete(recursive: true);
  });

  test('CreatePage disambiguates against an existing file (M768)', () async {
    final tmp =
        await Directory.systemTemp.createTemp('quill_create_page_collide_');
    final db = QuillDatabase.forTesting(NativeDatabase.memory());
    final repo = VaultRepositoryImpl(
      VaultFsDatasource(ulids: const UlidGenerator()),
    );
    final indexer = Indexer(db, repo.datasource);
    final bloc = VaultBloc(repo: repo, indexer: indexer, db: db);

    bloc.add(LoadFromPath(tmp.path));
    final loadedAt = DateTime.now();
    while (bloc.state is! VaultLoaded) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      if (DateTime.now().difference(loadedAt).inSeconds > 3) {
        fail('Vault never reached VaultLoaded: ${bloc.state}');
      }
    }

    // First creation lands at "Notes.md".
    String? first;
    bloc.add(CreatePage(title: 'Notes', onCreated: (u) => first = u));
    while (first == null) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(await File(p.join(tmp.path, 'Notes.md')).exists(), isTrue);

    // Second creation with the same title would clobber the first via
    // the atomic tmp → rename write. The disambiguator must redirect it
    // to "Notes (2).md" instead.
    String? second;
    bloc.add(CreatePage(title: 'Notes', onCreated: (u) => second = u));
    while (second == null) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(await File(p.join(tmp.path, 'Notes.md')).exists(), isTrue,
        reason: 'first page must survive');
    expect(await File(p.join(tmp.path, 'Notes (2).md')).exists(), isTrue,
        reason: 'second page must land on a fresh filename');

    // Frontmatter title mirrors the filename so the sidebar reflects
    // both entries distinctly instead of two pages titled "Notes".
    final raw2 =
        await File(p.join(tmp.path, 'Notes (2).md')).readAsString();
    final parsed2 = FrontmatterParser.parse(raw2);
    expect(parsed2.frontmatter.title, equals('Notes (2)'));
    expect(first, isNot(equals(second)),
        reason: 'each create gets its own ULID');

    // Third creation lands at (3).
    String? third;
    bloc.add(CreatePage(title: 'Notes', onCreated: (u) => third = u));
    while (third == null) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(await File(p.join(tmp.path, 'Notes (3).md')).exists(), isTrue);

    await bloc.close();
    await db.close();
    await tmp.delete(recursive: true);
  });
}
