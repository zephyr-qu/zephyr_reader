/// Rust 核心服务
///
/// 封装 Rust FFI 核心解析调用（解析、排版、分页、文件读取）
library;

import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/src/rust/api.dart' as api;
import 'package:zephyr_reader/src/rust/api/book.dart' as book;
import 'package:zephyr_reader/src/rust/api/file.dart' as file;
import 'package:zephyr_reader/src/rust/api/typeset.dart' as typeset;
import 'package:zephyr_reader/src/rust/domain/parser.dart';
import 'package:zephyr_reader/src/rust/domain/types.dart';
import 'package:zephyr_reader/src/rust/text/pagination.dart';

@LazySingleton()
class RustCoreService {
  // ==================== 连接测试 ====================

  String testConnection() => api.testConnection();

  // ==================== 格式检测 ====================

  List<String> getSupportedFormats() => book.getSupportedFormats();

  bool supportsFormat(String format) => book.supportsFormat(format: format);

  // ==================== 书籍解析 ====================

  Future<ParseResult> parseBook(String filePath) async =>
      book.parseBook(filePath: filePath);

  Future<BookMetadata> extractMetadata(String filePath) async =>
      book.extractMetadata(filePath: filePath);

  Future<ChapterContent> getChapter(
    String filePath,
    int chapterIndex, {
    TypesetConfig? config,
  }) async => book.getChapter(
    filePath: filePath,
    chapterIndex: chapterIndex,
    config: config,
  );

  // ==================== 分页 ====================

  Future<List<PageContent>> paginateAllContent(
    String filePath,
    int chapterIndex,
    TypesetConfig config,
  ) async => await book.paginateAllContent(
    filePath: filePath,
    chapterIndex: chapterIndex,
    config: config,
  );

  Future<PageStreamer> createPageStreamer(
    String filePath,
    int chapterIndex,
    TypesetConfig config,
  ) async => book.createPageStreamer(
    filePath: filePath,
    chapterIndex: chapterIndex,
    config: config,
  );

  // ==================== 排版 ====================

  Future<String> typesetText(String content, TypesetConfig config) async =>
      typeset.typesetText(content: content, config: config);

  // ==================== 文件操作 ====================

  Future<int> getFileSize(String filePath) async =>
      await file.getFileSize(filePath: filePath);

  Future<String> readFileChunk(
    String filePath,
    int startPos,
    int chunkSize,
  ) async => file.readFileChunk(
    filePath: filePath,
    startPos: startPos,
    chunkSize: chunkSize,
  );
}
