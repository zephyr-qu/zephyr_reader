/// 书籍导入服务 - 使用新错误处理系统
///
/// 示例：展示如何将现有服务迁移到统一错误处理
library;

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:zephyr_reader/core/error/app_error.dart';
import 'package:zephyr_reader/features/bookshelf/domain/models/import_task.dart';
import 'package:zephyr_reader/features/reader/domain/models/chapter_info.dart';
import 'package:zephyr_reader/src/rust/api/core.dart' as rust_api;
import 'package:zephyr_reader/src/rust/api/cover.dart' as rust_cover;

/// 导入结果
class ImportResult {
  final bool success;
  final ImportTask? task;
  final AppError? error;

  const ImportResult._({required this.success, this.task, this.error});

  factory ImportResult.success(ImportTask task) =>
      ImportResult._(success: true, task: task);

  factory ImportResult.failure(AppError error) =>
      ImportResult._(success: false, error: error);
}

/// 书籍导入服务（新错误处理版本）
@injectable
class BookImportServiceV2 {
  Directory? _booksDir;
  Directory? _coversDir;
  Future<void>? _initFuture;

  BookImportServiceV2() {
    _initFuture = _initDirectories();
  }

  /// 初始化存储目录
  Future<void> _initDirectories() async {
    final appDir = await getApplicationDocumentsDirectory();
    _booksDir = Directory(p.join(appDir.path, 'books'));
    _coversDir = Directory(p.join(appDir.path, 'covers'));

    await _booksDir?.create(recursive: true);
    await _coversDir?.create(recursive: true);
  }

  Future<void> _ensureInitialized() async {
    if (_initFuture != null) {
      await _initFuture;
      _initFuture = null;
    }
  }

  /// 选择文件 - 返回 Result 类型
  Future<Result<List<PlatformFile>>> selectFiles({
    bool allowMultiple = true,
    List<String>? allowedExtensions,
  }) {
    return Result.guardAsync(() async {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: allowMultiple,
        type: FileType.custom,
        allowedExtensions: allowedExtensions ?? ['txt', 'epub', 'pdf'],
      );

      if (result == null || result.files.isEmpty) {
        throw AppError.cancelled(message: '未选择文件');
      }

      return result.files;
    });
  }

  /// 选择文件夹 - 返回 Result 类型
  Future<Result<String>> selectFolder() {
    return Result.guardAsync(() async {
      final folder = await FilePicker.platform.getDirectoryPath();

      if (folder == null || folder.isEmpty) {
        throw AppError.cancelled(message: '未选择文件夹');
      }

      return folder;
    });
  }

  /// 导入单个文件 - 返回 Result 类型
  Future<Result<ImportTask>> importFile(PlatformFile file) async {
    try {
      await _ensureInitialized();

      final task = ImportTask(
        filePath: file.path!,
        fileName: file.name,
        format: p.extension(file.name).toLowerCase().substring(1),
        fileSize: file.size,
        bookId: 0,
      );

      task.status = ImportTaskStatus.processing;

      // 检查重复
      if (await isDuplicate(file.path!)) {
        task.status = ImportTaskStatus.skipped;
        task.error = '书籍已存在';
        return Result.success(task);
      }

      // 复制文件
      final destResult = await _copyFileToAppDirectory(file);
      if (destResult.isFailure) {
        task.status = ImportTaskStatus.failed;
        task.error = destResult.error!.message;
        return Result.success(task);
      }
      final destPath = destResult.value!;

      // 解析书籍
      final parseResult = await _parseBook(destPath, task.format);
      if (parseResult.isFailure) {
        task.status = ImportTaskStatus.failed;
        task.error = parseResult.error!.message;
        return Result.success(task);
      }
      final bookInfo = parseResult.value!;

      // 更新任务信息
      task.title = bookInfo['title'] as String?;
      task.author = bookInfo['author'] as String?;
      task.chapterCount = bookInfo['chapterCount'] as int?;
      task.coverPath = bookInfo['coverPath'] as String?;
      task.chapters = bookInfo['chapters'] as List<ChapterInfo>? ?? [];
      task.status = ImportTaskStatus.completed;

      return Result.success(task);
    } catch (e, stack) {
      return Result.failure(AppError.fromException(e, stackTrace: stack));
    }
  }

  /// 复制文件到应用目录
  Future<Result<String>> _copyFileToAppDirectory(PlatformFile file) async {
    return Result.guardAsync(() async {
      if (_booksDir == null) {
        throw AppError.file(message: '存储目录未初始化', detail: '_booksDir is null');
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${timestamp}_${file.name}';
      final destPath = p.join(_booksDir!.path, fileName);

      final srcFile = File(file.path!);
      if (!await srcFile.exists()) {
        throw AppError.file(message: '源文件不存在', detail: 'Path: ${file.path}');
      }

      await srcFile.copy(destPath);
      return destPath;
    });
  }

  /// 使用 Rust 引擎解析书籍
  Future<Result<Map<String, dynamic>>> _parseBook(
    String filePath,
    String format,
  ) async {
    return Result.guardAsync(() async {
      final result = rust_api.parseBook(filePath: filePath);
      final parseResult = (result as dynamic);

      // Access book info and chapters from the parse result
      final bookInfo = parseResult.bookInfo ?? parseResult.book_info;
      final chapters = parseResult.chapters ?? bookInfo?.chapters;

      if (bookInfo == null) {
        throw AppError.parse(
          message: '无法解析书籍文件',
          detail: 'Rust parser returned null',
          filePath: filePath,
        );
      }

      // 提取封面
      String? coverPath;
      if (format == 'epub' || format == 'pdf') {
        final coverResult = await _extractCover(filePath);
        if (coverResult.isSuccess) {
          coverPath = coverResult.value;
        }
      }

      return {
        'title': bookInfo.title,
        'author': bookInfo.author,
        'chapterCount': bookInfo.chapterCount ?? bookInfo.chapter_count,
        'coverPath': coverPath ?? bookInfo.coverPath ?? bookInfo.cover_path,
        'chapters': _convertChapters(chapters),
      };
    });
  }

  /// 提取封面
  Future<Result<String?>> _extractCover(String filePath) {
    return Result.guardAsync(() async {
      if (_coversDir == null) return null;

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final coverFilename = 'cover_$timestamp.jpg';
      final coverDestPath = p.join(_coversDir!.path, coverFilename);

      final result = rust_cover.extractBookCover(
        filePath: filePath,
        outputDir: _coversDir!.path,
      );

      final coverPath = (result as dynamic).value as String?;
      if (coverPath == null) return null;

      final coverFile = File(coverPath);
      if (!await coverFile.exists()) return null;

      final newCoverFile = await coverFile.copy(coverDestPath);
      return newCoverFile.path;
    });
  }

  List<ChapterInfo> _convertChapters(dynamic chapters) {
    if (chapters == null || chapters is! List) return [];

    return chapters.map((chapter) {
      // Rust ChapterInfo fields: chapterId (String/UUID), title, startIndex (i64), endIndex (i64), contentLength (i64), index (i32)
      final chapterIdVal = chapter.chapterId ?? chapter.chapter_id;
      final chapterIndex = chapter.index ?? chapter.chapterIndex ?? 0;
      return ChapterInfo(
        chapterId: chapterIdVal is String ? chapterIdVal : chapterIndex.toString(),
        title: chapter.title ?? '',
        startIndex: (chapter.startIndex ?? chapter.start_index ?? 0).toInt(),
        endIndex: (chapter.endIndex ?? chapter.end_index ?? 0).toInt(),
        contentLength:
            (chapter.contentLength ?? chapter.content_length ?? 0).toInt(),
        index: chapterIndex,
      );
    }).toList();
  }

  /// 检查文件是否重复
  Future<bool> isDuplicate(String filePath) async {
    await _ensureInitialized();

    final fileName = p.basename(filePath);
    if (_booksDir == null || !await _booksDir!.exists()) return false;

    await for (final entity in _booksDir!.list()) {
      if (entity is File) {
        final existingName = p.basename(entity.path).substring(11);
        if (existingName == fileName) return true;
      }
    }

    return false;
  }

  /// 批量导入 - 收集所有结果
  Future<List<Result<ImportTask>>> importFiles(
    List<PlatformFile> files, {
    void Function(int current, int total, ImportTask task)? onProgress,
  }) async {
    final results = <Result<ImportTask>>[];

    for (int i = 0; i < files.length; i++) {
      final result = await importFile(files[i]);
      results.add(result);

      if (result.isSuccess) {
        onProgress?.call(i + 1, files.length, result.value!);
      }
    }

    return results;
  }
}

/// ============================================
/// 在 UI 层使用的示例
/// ============================================

/*
class ImportPage extends StatelessWidget {
  final _importService = getIt<BookImportServiceV2>();

  Future<void> _onImportPressed(BuildContext context) async {
    // 选择文件
    final selectResult = await _importService.selectFiles();

    if (selectResult.isSuccess) {
      final files = selectResult.value!;
      // 用户选择了文件，开始导入
      for (final file in files) {
        final importResult = await _importService.importFile(file);

        if (importResult.isSuccess) {
          final task = importResult.value!;
          if (task.status == ImportTaskStatus.completed) {
            // 导入成功
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('《${task.title}》导入成功')),
            );
          } else if (task.status == ImportTaskStatus.skipped) {
            // 已存在
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('《${task.title}》已存在')),
            );
          }
        } else {
          // 导入失败
          final error = importResult.error!;
          ErrorHandler().handleError(
            error,
            context: context,
            onRetry: () => _onImportPressed(context),
          );
        }
      }
    } else {
      // 选择文件失败（用户取消等）
      final error = selectResult.error!;
      if (error.type != ErrorType.cancelled) {
        ErrorHandler().handleError(error, context: context);
      }
    }
  }
}
*/
