/// Rust 增量解析服务
library;

import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/src/rust/api/core.dart' as rust_core;
import 'package:zephyr_reader/src/rust/api/incremental.dart' as rust;
import 'package:zephyr_reader/src/rust/parser/incremental.dart' show CacheStats;

@LazySingleton()
class RustIncrementalService {
  rust_core.ApiResult init() => rust.initIncrementalParser();

  rust.ApiResultLocalBookInfo parseLocalBookIncremental(String filePath) =>
      rust.parseLocalBookIncremental(filePath: filePath);

  rust_core.ApiResult clearCache() => rust.clearIncrementalParserCache();

  CacheStats getStats() => rust.getIncrementalParserStats();
}
