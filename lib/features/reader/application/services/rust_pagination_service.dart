/// Rust 引擎分页服务
///
/// 使用 Rust 引擎进行精确的文本分页计算
library;

import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/core/local/rust_core_service.dart';
import 'package:zephyr_reader/src/rust/ffi/types.dart';
import 'package:zephyr_reader/src/rust/stream/page_stream.dart';

/// 分页结果项
class PageItem {
  final int pageIndex;
  final String content;
  final bool isLastPage;

  PageItem({
    required this.pageIndex,
    required this.content,
    required this.isLastPage,
  });
}

/// Rust 引擎分页服务
@injectable
class RustPaginationService {
  final RustCoreService _core;

  RustPaginationService(this._core);

  Future<List<PageItem>> paginateContent({
    required String content,
    required int chapterId,
    required double fontSize,
    required double lineHeight,
    required double pageWidth,
    required double pageHeight,
    required double padding,
  }) async {
    try {
      final config = TypesetConfig(
        pageWidth: (pageWidth - (padding * 2)).toInt(),
        pageHeight: (pageHeight - (padding * 2)).toInt(),
        fontSize: fontSize.toInt(),
        lineSpacing: lineHeight,
        letterSpacing: 0,
        paragraphSpacing: 8.0,
        firstLineIndent: 2,
        language: LanguageType.auto,
        enableHyphenation: false,
      );

      final pages = _core.paginateAllContent(
        content: content,
        chapterId: chapterId,
        config: config,
      );

      return pages
          .asMap()
          .entries
          .map(
            (entry) => PageItem(
              pageIndex: entry.value.pageIndex,
              content: entry.value.content,
              isLastPage: entry.value.isLastPage,
            ),
          )
          .toList();
    } catch (e) {
      debugPrint('RustPaginationService.paginateContent error: $e');
      return [];
    }
  }

  PageStreamer createPageStreamer({
    required String content,
    required double fontSize,
    required double lineHeight,
    required double pageWidth,
    required double pageHeight,
  }) {
    final config = TypesetConfig(
      pageWidth: pageWidth.toInt(),
      pageHeight: pageHeight.toInt(),
      fontSize: fontSize.toInt(),
      lineSpacing: lineHeight,
      letterSpacing: 0,
      paragraphSpacing: 8.0,
      firstLineIndent: 2,
      language: LanguageType.auto,
      enableHyphenation: false,
    );

    return _core.createPageStreamer(content: content, config: config);
  }
}
