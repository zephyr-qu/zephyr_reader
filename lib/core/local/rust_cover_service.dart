/// Rust 封面提取服务
library;

import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/src/rust/api/core.dart' as rust_core;
import 'package:zephyr_reader/src/rust/api/cover.dart' as rust;

@LazySingleton()
class RustCoverService {
  rust_core.ApiResultString extractBookCover({
    required String filePath,
    required String outputDir,
  }) => rust.extractBookCover(filePath: filePath, outputDir: outputDir);

  bool supportsCoverExtraction(String filePath) =>
      rust.supportsCoverExtraction(filePath: filePath);
}
