import 'dart:io';

import '../entities/page.dart';
import '../repositories/vault_repository.dart';

class WritePage {
  const WritePage(this._repo);
  final VaultRepository _repo;

  Future<void> call(Page page, {required Directory root}) =>
      _repo.writePage(page, root: root);
}
