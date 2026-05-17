/// Rust 双语对齐服务
library;

import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/src/rust/api/bilingual.dart' as rust;
import 'package:zephyr_reader/src/rust/domain/types.dart';

@LazySingleton()
class RustBilingualService {
  Future<BilingualAlignment> alignBilingualContent({
    required String chineseContent,
    required String englishContent,
    double minSimilarity = 0.5,
  }) async =>
      rust.alignBilingualContent(
        chineseContent: chineseContent,
        englishContent: englishContent,
        minSimilarity: minSimilarity,
      );

  BilingualAlignment simpleBilingualAlign({
    required String chineseContent,
    required String englishContent,
  }) =>
      rust.simpleBilingualAlign(
        chineseContent: chineseContent,
        englishContent: englishContent,
      );
}
