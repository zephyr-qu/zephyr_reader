/// Rust 核心解析服务
///
/// 封装 Rust FFI 核心解析调用，提供文件解析、排版、流式读取等功能
library;

import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/src/rust/api/core.dart' as rust;
import 'package:zephyr_reader/src/rust/ffi/types.dart';
import 'package:zephyr_reader/src/rust/stream/page_stream.dart';

@LazySingleton()
class RustCoreService {
  String testConnection() => rust.testConnection();

  rust.ApiResult setAllowedBaseDir(String baseDir) =>
      rust.setAllowedBaseDir(baseDir: baseDir);

  List<String> getSupportedFormats() => rust.getSupportedFormats();

  bool supportsFormat(String format) => rust.supportsFormat(format: format);

  rust.ApiResultParseResult parseBook(String filePath) =>
      rust.parseBook(filePath: filePath);

  rust.ApiResultBookMetadata extractMetadata(String filePath) =>
      rust.extractMetadata(filePath: filePath);

  rust.ApiResultString extractChapter({
    required String filePath,
    required int chapterId,
  }) => rust.extractChapter(filePath: filePath, chapterId: chapterId);

  rust.ApiResultVecPageContent getTxtChapterContent({
    required String filePath,
    required int chapterIndex,
    required TypesetConfig config,
  }) => rust.getTxtChapterContent(
    filePath: filePath,
    chapterIndex: chapterIndex,
    config: config,
  );

  rust.ApiResultString typesetText({
    required String content,
    required String language,
    required TypesetConfig config,
  }) => rust.typesetText(content: content, language: language, config: config);

  rust.ApiResultI64 getFileSize(String filePath) =>
      rust.getFileSize(filePath: filePath);

  rust.ApiResultString readFileChunk({
    required String filePath,
    required int startPos,
    required int chunkSize,
  }) => rust.readFileChunk(
    filePath: filePath,
    startPos: startPos,
    chunkSize: chunkSize,
  );

  PageStreamer createPageStreamer({
    required String content,
    required TypesetConfig config,
  }) => rust.createPageStreamer(content: content, config: config);

  List<PageContent> paginateAllContent({
    required String content,
    required int chapterId,
    required TypesetConfig config,
  }) => rust.paginateAllContent(
    content: content,
    chapterId: chapterId,
    config: config,
  );
}
