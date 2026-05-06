/// Rust 安全路径服务
library;

import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/src/rust/api/security.dart' as rust;

@LazySingleton()
class RustSecurityService {
  Future<String> validatePathSecurely({
    required String filePath,
    required String allowedBase,
  }) => rust.validatePathSecurely(filePath: filePath, allowedBase: allowedBase);

  Future<String> validateFilePath(String filePath) =>
      rust.validateFilePath(filePath: filePath);
}
