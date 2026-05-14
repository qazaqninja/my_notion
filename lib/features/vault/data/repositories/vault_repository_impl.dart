import 'dart:io' as io;

import 'package:file/local.dart';
import 'package:path/path.dart' as p;

import '../../../../core/ulid/ulid_generator.dart';
import '../../domain/entities/page.dart';
import '../../domain/repositories/vault_repository.dart';
import '../datasources/vault_fs_datasource.dart';

class VaultRepositoryImpl implements VaultRepository {
  VaultRepositoryImpl(this._ds);
  final VaultFsDatasource _ds;

  /// Production wiring — local filesystem + real ULID generator.
  factory VaultRepositoryImpl.local() =>
      VaultRepositoryImpl(VaultFsDatasource(ulids: const UlidGenerator(), fs: const LocalFileSystem()));

  @override
  Stream<Page> scan(io.Directory root) {
    final dir = _ds.fs.directory(root.path);
    return _ds.scan(dir);
  }

  @override
  Future<Page> readPage(String relativePath, {required io.Directory root}) {
    final file = _ds.fs.file(p.join(root.path, relativePath));
    final dir = _ds.fs.directory(root.path);
    return _ds.readOne(file, vaultRoot: dir);
  }

  @override
  Future<void> writePage(Page page, {required io.Directory root}) {
    final dir = _ds.fs.directory(root.path);
    return _ds.write(page, vaultRoot: dir);
  }
}
