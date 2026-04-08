/// Rust 引擎分页服务
///
/// 使用 Rust 引擎进行精确的文本分页计算
library;

import 'package:flutter/material.dart';
import 'package:zephyr_reader/src/rust/api/core.dart' as rust_api;
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
class RustPaginationService {
  /// 使用 Rust 引擎分页
  ///
  /// [content] 待分页的文本内容
  /// [chapterId] 章节 ID
  /// [fontSize] 字体大小
  /// [lineHeight] 行间距
  /// [pageWidth] 页面宽度（像素）
  /// [pageHeight] 页面高度（像素）
  /// [padding] 页边距（像素）
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
      // 创建排版配置
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

      // 调用 Rust 引擎分页
      final pages = rust_api.paginateAllContent(
        content: content,
        chapterId: chapterId,
        config: config,
      );

      // 转换为 PageItem 列表
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
      // 如果 Rust 分页失败，返回空列表
      return [];
    }
  }

  /// 创建分页器（流式分页）
  ///
  /// 适用于大文件，可以按需获取页面
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

    return rust_api.createPageStreamer(content: content, config: config);
  }
}
