import 'package:zephyr_reader/features/reader/domain/models/chapter_info.dart';

/// 单个导入任务
class ImportTask {
  /// 文件路径
  final String filePath;

  /// 文件
  final String fileName;

  /// 文件格式
  final String format;

  /// 文件大小
  final int fileSize;

  /// 状
  ImportTaskStatus status;

  /// 错误信息
  String? error;

  /// 导入后的书籍 ID
  int bookId;

  /// 书籍标题（从 Rust 解析获取
  String? title;

  /// 作者（Rust 解析获取
  String? author;

  /// 章节数量（从 Rust 解析获取
  int? chapterCount;

  /// 封面路径（从 Rust 解析获取
  String? coverPath;

  /// 章节列表（从 Rust 解析获取
  List<ChapterInfo> chapters = [];

  ImportTask({
    required this.filePath,
    required this.fileName,
    required this.format,
    required this.fileSize,
    this.status = ImportTaskStatus.pending,
    this.error,
    required this.bookId,
    this.title,
    this.author,
    this.chapterCount,
    this.coverPath,
    List<ChapterInfo>? chapters,
  }) {
    this.chapters = chapters ?? [];
  }
}

/// 导入任务状
enum ImportTaskStatus {
  /// 等待
  pending,

  /// 进行
  processing,

  /// 已完
  completed,

  /// 失败
  failed,

  /// 已跳过（重复
  skipped,
}
