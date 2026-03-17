/// 书籍导入服务
library;

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:zephyr_reader/features/reader/domain/models.dart';
import 'package:zephyr_reader/src/rust/api.dart' as rust_api;
import 'package:zephyr_reader/src/rust/api.dart';

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

/// 书籍导入服务
class BookImportService {
  /// 应用书籍存储目录
  late final Directory _booksDir;

  /// 应用封面存储目录
  late final Directory _coversDir;

  BookImportService() {
    _initDirectories();
  }

  /// 初始化存储目
  Future<void> _initDirectories() async {
    final appDir = await getApplicationDocumentsDirectory();
    _booksDir = Directory(p.join(appDir.path, 'books'));
    _coversDir = Directory(p.join(appDir.path, 'covers'));

    if (!await _booksDir.exists()) {
      await _booksDir.create(recursive: true);
    }
    if (!await _coversDir.exists()) {
      await _coversDir.create(recursive: true);
    }
  }

  /// 选择文件
  Future<List<PlatformFile>?> selectFiles({
    bool allowMultiple = true,
    List<String>? allowedExtensions,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: allowMultiple,
        type: FileType.custom,
        allowedExtensions: allowedExtensions ?? ['txt', 'epub', 'pdf'],
      );

      return result?.files;
    } catch (e) {
      debugPrint('BookImportService.selectFiles error: $e');
      return null;
    }
  }

  /// 选择文件
  Future<String?> selectFolder() async {
    try {
      final folder = await FilePicker.platform.getDirectoryPath();
      return folder;
    } catch (e) {
      debugPrint('BookImportService.selectFolder error: $e');
      return null;
    }
  }

  /// 扫描文件夹中的所有书籍文
  Future<List<PlatformFile>> scanFolder(String folderPath) async {
    final files = <PlatformFile>[];
    final supportedFormats = {'txt', 'epub', 'pdf'};

    try {
      final dir = Directory(folderPath);
      if (!await dir.exists()) {
        debugPrint('文件夹不存在folderPath');
        return files;
      }

      await for (final entity in dir.list(recursive: false)) {
        if (entity is File) {
          final ext = p.extension(entity.path).toLowerCase().substring(1);
          if (supportedFormats.contains(ext)) {
            files.add(
              PlatformFile(
                name: p.basename(entity.path),
                path: entity.path,
                size: await entity.length(),
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('BookImportService.scanFolder error: $e');
    }

    return files;
  }

  /// 导入单个文件
  Future<ImportTask> importFile(PlatformFile file) async {
    final task = ImportTask(
      filePath: file.path!,
      fileName: file.name,
      format: p.extension(file.name).toLowerCase().substring(1),
      fileSize: file.size,
      bookId: 0, // 需要初始化为有效的 ID
    );

    try {
      task.status = ImportTaskStatus.processing;

      // 检查是否已存在
      if (await isDuplicate(file.path!)) {
        task.status = ImportTaskStatus.skipped;
        task.error = '书籍已存';
        return task;
      }

      // 复制文件到应用目
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${timestamp}_${file.name}';
      final destPath = p.join(_booksDir.path, fileName);

      // 复制文件
      final srcFile = File(file.path!);
      await srcFile.copy(destPath);

      // 使用 Rust 引擎解析书籍
      final parseResult = await _parseBook(destPath, task.format);

      if (parseResult == null) {
        task.status = ImportTaskStatus.failed;
        task.error = '解析失败';
        return task;
      }

      // 更新任务信息
      task.title = parseResult.title;
      task.author = parseResult.author;
      task.chapterCount = parseResult.chapterCount;
      task.coverPath = parseResult.coverPath;
      task.chapters = parseResult.chapters;

      task.status = ImportTaskStatus.completed;

      return task;
    } catch (e) {
      task.status = ImportTaskStatus.failed;
      task.error = '导入失败e';
      debugPrint('BookImportService.importFile error: $e');
      return task;
    }
  }

  /// 使用 Rust 引擎解析书籍
  Future<dynamic> _parseBook(String filePath, String format) async {
    try {
      // 调用 Rust 异步解析
      final result = await asyncParseLocalBook(filePath: filePath);

      // 解包 ApiResult 获取实际数据
      // 对于 Opaque 类型，使用 .value 属性访问实际数据
      final bookInfo = (result as dynamic).value;

      if (bookInfo != null) {
        // 如果EPUB PDF，提取封面
        String? coverPath;
        if (format == 'epub' || format == 'pdf') {
          coverPath = await _extractCover(filePath);
        }

        // 转换章节数据
        final chapters = _convertChapters(bookInfo.chapters);

        // 创建包含正确类型的数据对象
        return {
          'title': bookInfo.title,
          'author': bookInfo.author,
          'chapterCount': bookInfo.chapter_count,
          'coverPath': coverPath ?? bookInfo.cover_path,
          'chapters': chapters,
        };
      }
          return null;
    } catch (e) {
      debugPrint('BookImportService._parseBook error: $e');
      return null;
    }
  }

  /// 将动态章节数据转换为 ChapterInfo 列表
  List<ChapterInfo> _convertChapters(dynamic chapters) {
    if (chapters == null || chapters is! List) {
      return [];
    }

    final List<ChapterInfo> result = [];
    for (final chapter in chapters) {
      if (chapter != null) {
        result.add(
          ChapterInfo(
            chapterId: chapter.chapter_id ?? 0,
            title: chapter.title ?? '',
            startIndex: (chapter.start_index ?? 0).toInt(),
            endIndex: (chapter.end_index ?? 0).toInt(),
            contentLength: (chapter.content_length ?? 0).toInt(),
            index: chapter.index ?? 0,
          ),
        );
      }
    }
    return result;
  }

  /// 提取书籍封面
  Future<String?> _extractCover(String filePath) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final coverFilename = 'cover_$timestamp.jpg';
      final coverDestPath = p.join(_coversDir.path, coverFilename);

      // 调用 Rust 提取封面（返回ApiResultString）
      final result = rust_api.extractBookCover(
        filePath: filePath,
        outputDir: _coversDir.path,
      );

      // 解包 ApiResultString 获取路径
      final coverPath = (result as dynamic).value;

      if (coverPath != null && coverPath is String) {
        // 复制封面到标准位置
        final coverFile = File(coverPath);
        if (await coverFile.exists()) {
          final newCoverFile = await coverFile.copy(coverDestPath);
          return newCoverFile.path;
        }
      }

      return null;
    } catch (e) {
      debugPrint('BookImportService._extractCover error: $e');
      return null;
    }
  }

  /// 批量导入文件
  Future<List<ImportTask>> importFiles(
    List<PlatformFile> files, {
    void Function(int current, int total, ImportTask task)? onProgress,
  }) async {
    final tasks = <ImportTask>[];

    for (int i = 0; i < files.length; i++) {
      final file = files[i];
      final task = await importFile(file);
      tasks.add(task);

      onProgress?.call(i + 1, files.length, task);
    }

    return tasks;
  }

  /// 检查文件是否为重复
  Future<bool> isDuplicate(String filePath) async {
    // 获取文件名（不含路径
    final fileName = p.basename(filePath);

    // 检查书籍目录中是否存在相同文件名的文件
    if (await _booksDir.exists()) {
      await for (final entity in _booksDir.list()) {
        if (entity is File) {
          final existingName = p.basename(entity.path).substring(11); // 去掉时间戳前缀
          if (existingName == fileName) {
            return true;
          }
        }
      }
    }

    return false;
  }

  /// 获取文件信息
  Future<Map<String, dynamic>?> getFileInfo(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return null;
      }

      final format = p.extension(filePath).toLowerCase().substring(1);

      return {
        'name': p.basename(filePath),
        'path': filePath,
        'format': format,
        'size': await file.length(),
      };
    } catch (e) {
      debugPrint('BookImportService.getFileInfo error: $e');
      return null;
    }
  }

  /// 获取支持的格式列
  List<String> getSupportedFormats() {
    return ['txt', 'epub', 'pdf'];
  }
}
