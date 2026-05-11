/// Rust 封面提取服务
library;

import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/src/rust/api/cover.dart' as rust;

@LazySingleton()
class RustCoverService {
  Future<String> extractBookCover({
    required String filePath,
    required String outputDir,
  }) async =>
      await rust.extractBookCover(
              filePath: filePath, outputDir: outputDir)
          ;

  bool supportsCoverExtraction(String filePath) =>
      rust.supportsCoverExtraction(filePath: filePath);
}
