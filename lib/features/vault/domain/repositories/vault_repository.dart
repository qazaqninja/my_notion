import 'dart:io' as io;

import '../entities/page.dart';

/// Abstract contract for vault operations. Implementations live in `data/`.
abstract class VaultRepository {
  Stream<Page> scan(io.Directory root);
  Future<Page> readPage(String relativePath, {required io.Directory root});
  Future<void> writePage(Page page, {required io.Directory root});
}
