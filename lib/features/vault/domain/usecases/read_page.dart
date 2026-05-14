import 'dart:io';

import '../entities/page.dart';
import '../repositories/vault_repository.dart';

class ReadPage {
  const ReadPage(this._repo);
  final VaultRepository _repo;

  Future<Page> call(String relativePath, {required Directory root}) =>
      _repo.readPage(relativePath, root: root);
}
