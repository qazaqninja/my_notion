/// Regression tests for EditorBloc.close() flush behaviour (M714).
///
/// Contract: when the bloc is closed while in a dirty EditorLoaded state,
/// it must persist the in-memory page before super.close() returns —
/// otherwise the debounce timer is cancelled and the last keystrokes
/// are lost. This used to silently drop edits when the user navigated
/// away within 500ms of typing.
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/core/db/quill_database.dart';
import 'package:my_notion/core/markdown/frontmatter_parser.dart';
import 'package:my_notion/core/ulid/ulid_generator.dart';
import 'package:my_notion/features/editor/presentation/bloc/editor_bloc.dart';
import 'package:my_notion/features/editor/presentation/bloc/editor_event.dart';
import 'package:my_notion/features/editor/presentation/bloc/editor_state.dart';
import 'package:my_notion/features/vault/data/datasources/vault_fs_datasource.dart';
import 'package:my_notion/features/vault/data/indexer.dart';
import 'package:my_notion/features/vault/data/repositories/vault_repository_impl.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tmp;
  late QuillDatabase db;
  late VaultRepositoryImpl repo;
  late Indexer indexer;
  late String ulid;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('quill_editor_flush_');
    db = QuillDatabase.forTesting(NativeDatabase.memory());
    repo = VaultRepositoryImpl(
      VaultFsDatasource(ulids: const UlidGenerator()),
    );
    indexer = Indexer(db, repo.datasource);

    ulid = '01HX0V9R5N6E8L3P7Q8S9U2X4B';
    final file = File(p.join(tmp.path, 'p.md'));
    await file.writeAsString('---\nid: $ulid\ntitle: P\n---\n\noriginal body\n');
    await indexer.reindex(tmp);
  });

  tearDown(() async {
    await db.close();
    try {
      await tmp.delete(recursive: true);
    } catch (_) {}
  });

  test('close() flushes dirty body to disk before super.close (M714)',
      () async {
    final bloc = EditorBloc(repo: repo, indexer: indexer, db: db);
    bloc.setVaultRoot(tmp);
    bloc.add(OpenEditor(ulid));

    // Wait for EditorLoaded
    final deadline = DateTime.now().add(const Duration(seconds: 3));
    while (bloc.state is! EditorLoaded) {
      if (DateTime.now().isAfter(deadline)) {
        fail('Editor never reached EditorLoaded: ${bloc.state}');
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }

    // Type something — marks dirty, scheduleSave fires its 500ms timer.
    bloc.add(const EditBody('new body content'));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final mid = bloc.state;
    expect(mid is EditorLoaded && mid.dirty, isTrue);

    // Close immediately — well before the 500ms debounce fires.
    await bloc.close();

    // Disk should have the new body verbatim.
    final raw =
        await File(p.join(tmp.path, 'p.md')).readAsString();
    final parsed = FrontmatterParser.parse(raw);
    expect(parsed.body.trim(), equals('new body content'),
        reason: 'close() must flush in-memory edits to disk');
  });

  test('save race: edits during in-flight save stay dirty (M715)',
      () async {
    final bloc = EditorBloc(repo: repo, indexer: indexer, db: db);
    bloc.setVaultRoot(tmp);
    bloc.add(OpenEditor(ulid));

    final deadline = DateTime.now().add(const Duration(seconds: 3));
    while (bloc.state is! EditorLoaded) {
      if (DateTime.now().isAfter(deadline)) {
        fail('Editor never reached EditorLoaded: ${bloc.state}');
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }

    // First edit + explicit save. Then immediately queue another edit
    // — Bloc default transformer is concurrent, so the second handler
    // can interleave with the save's awaits.
    bloc.add(const EditBody('first version'));
    bloc.add(const SaveNow());
    bloc.add(const EditBody('second version'));

    // Settle.
    await Future<void>.delayed(const Duration(milliseconds: 200));

    final s = bloc.state;
    expect(s is EditorLoaded, isTrue);
    final loaded = s as EditorLoaded;
    // The in-memory page must reflect the most recent edit.
    expect(loaded.page.body.trim(), equals('second version'),
        reason: 'latest body wins in memory');
    // dirty must stay true so the next debounce / explicit save picks
    // up the second edit. Without M715, the post-save emit would clear
    // dirty using the stale loaded snapshot.
    expect(loaded.dirty, isTrue,
        reason: 'second-version edit must keep dirty=true after save');

    await bloc.close();
    // After close() flushes (M714), disk has the latest body.
    final raw =
        await File(p.join(tmp.path, 'p.md')).readAsString();
    final parsed = FrontmatterParser.parse(raw);
    expect(parsed.body.trim(), equals('second version'));
  });

  test('close() is a no-op when state is clean', () async {
    final bloc = EditorBloc(repo: repo, indexer: indexer, db: db);
    bloc.setVaultRoot(tmp);
    bloc.add(OpenEditor(ulid));

    final deadline = DateTime.now().add(const Duration(seconds: 3));
    while (bloc.state is! EditorLoaded) {
      if (DateTime.now().isAfter(deadline)) {
        fail('Editor never reached EditorLoaded: ${bloc.state}');
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }

    final before =
        await File(p.join(tmp.path, 'p.md')).readAsString();
    // No EditBody dispatched — bloc stays dirty=false.
    await bloc.close();

    final after =
        await File(p.join(tmp.path, 'p.md')).readAsString();
    expect(after, equals(before),
        reason: 'clean close() must not rewrite the file');
  });
}
