import 'dart:io';

import '../entities/page.dart';
import '../repositories/vault_repository.dart';

class ScanVault {
  const ScanVault(this._repo);
  final VaultRepository _repo;

  Stream<Page> call(Directory root) => _repo.scan(root);
}
