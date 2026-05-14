import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_notion/features/vault/data/workspace_config.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tmp;
  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('quill_ws_cfg_');
  });
  tearDown(() async {
    try {
      await tmp.delete(recursive: true);
    } catch (_) {}
  });

  test('returns defaults when .quill.yaml is missing', () async {
    final cfg = await WorkspaceConfig.load(tmp);
    expect(cfg.name, isNull);
    expect(cfg.icon, isNull);
    expect(cfg.favorites, isEmpty);
  });

  test('reads workspace.name + icon + favorites', () async {
    await File(p.join(tmp.path, '.quill.yaml')).writeAsString('''
workspace:
  name: My Vault
  icon: 📚
favorites:
  - 01HX0V9R5N6E8L3P7Q8S9U2X4B
  - 01HX0VEY5T6K7R9X4Y8Z0A3D4G
''');
    final cfg = await WorkspaceConfig.load(tmp);
    expect(cfg.name, equals('My Vault'));
    expect(cfg.icon, equals('📚'));
    expect(cfg.favorites,
        equals(['01HX0V9R5N6E8L3P7Q8S9U2X4B', '01HX0VEY5T6K7R9X4Y8Z0A3D4G']));
  });

  test('save then load round-trips fields', () async {
    const cfg = WorkspaceConfig(
      name: 'Test Vault',
      icon: '🦄',
      favorites: ['ABCDEFGHJKMNPQRSTVWXYZ1234'],
    );
    await cfg.save(tmp);
    final reloaded = await WorkspaceConfig.load(tmp);
    expect(reloaded.name, equals('Test Vault'));
    expect(reloaded.icon, equals('🦄'));
    expect(reloaded.favorites, equals(['ABCDEFGHJKMNPQRSTVWXYZ1234']));
  });

  test('save writes nothing when all fields are default', () async {
    const cfg = WorkspaceConfig();
    await cfg.save(tmp);
    final raw =
        await File(p.join(tmp.path, '.quill.yaml')).readAsString();
    expect(raw, isEmpty);
  });

  test('garbage YAML → defaults, no crash', () async {
    await File(p.join(tmp.path, '.quill.yaml')).writeAsString('not: valid: yaml: here:');
    final cfg = await WorkspaceConfig.load(tmp);
    expect(cfg.name, isNull);
    expect(cfg.icon, isNull);
  });

  group('sidebar customization', () {
    test('reads sidebar.order list', () async {
      await File(p.join(tmp.path, '.quill.yaml')).writeAsString('''
sidebar:
  order:
    - workspace
    - favorites
    - more
    - databases
    - recent
''');
      final cfg = await WorkspaceConfig.load(tmp);
      expect(cfg.sidebarOrder,
          equals(['workspace', 'favorites', 'more', 'databases', 'recent']));
    });

    test('reads sidebar.hidden list', () async {
      await File(p.join(tmp.path, '.quill.yaml')).writeAsString('''
sidebar:
  hidden:
    - recent
    - more
''');
      final cfg = await WorkspaceConfig.load(tmp);
      expect(cfg.sidebarHidden, equals(['recent', 'more']));
    });

    test('save round-trips sidebar fields', () async {
      const cfg = WorkspaceConfig(
        sidebarOrder: ['workspace', 'favorites', 'databases'],
        sidebarHidden: ['recent'],
      );
      await cfg.save(tmp);
      final reloaded = await WorkspaceConfig.load(tmp);
      expect(reloaded.sidebarOrder,
          equals(['workspace', 'favorites', 'databases']));
      expect(reloaded.sidebarHidden, equals(['recent']));
    });

    test('missing sidebar block → null / empty defaults', () async {
      await File(p.join(tmp.path, '.quill.yaml')).writeAsString('''
workspace:
  name: bare
''');
      final cfg = await WorkspaceConfig.load(tmp);
      expect(cfg.sidebarOrder, isNull);
      expect(cfg.sidebarHidden, isEmpty);
    });
  });
}
