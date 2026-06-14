import 'dart:async';
import 'dart:io';

import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/src/rust/api/core.dart' as core_api;
import 'package:zephyr_reader/src/rust/api/cover.dart' as cover_api;

/// 书籍导入服务。
///
/// 处理文件导入、文件夹扫描和封面提取等 I/O 密集型操作。
/// 不持有状态，所有方法为纯函数（有副作用但无实例可变状态）。
@lazySingleton
class BookImportService {
  /// 从文件导入书籍（解析并存入数据库）。
  Future<bool> importBook(String filePath) async {
    try {
      final bookId = await core_api.parseBook(filePath: filePath);
      // 导入后自动提取封面到磁盘
      await _extractCover(bookId, filePath);
      return true;
    } catch (e, stack) {
      Logging.error(
        'BookImportService.importBook error',
        exception: e,
        stackTrace: stack,
      );
      return false;
    }
  }

  /// 并发上限
  static const int _scanConcurrency = 4;

  /// 扫描文件夹并将发现的书籍文件导入数据库。
  ///
  /// [onProgress] 可选进度回调，接收 (done, total) 用于 UI 展示。
  /// 返回 (successCount, failCount)。
  Future<(int, int)> scanFolder(
    String folderPath, {
    void Function(int done, int total)? onProgress,
  }) async {
    final extensions = {'.txt', '.epub', '.pdf'};
    final dir = Directory(folderPath);
    final files = await dir
        .list(recursive: true)
        .where((e) => e is File)
        .cast<File>()
        .where((f) => extensions.contains(p.extension(f.path).toLowerCase()))
        .map((f) => f.path)
        .toList();
    if (files.isEmpty) {
      return (0, 0);
    }

    final total = files.length;
    var done = 0;
    var success = 0;
    var fail = 0;
    onProgress?.call(0, total);

    final sem = _Semaphore(_scanConcurrency);
    await Future.wait(
      files.map(
        (file) => sem.acquire(() async {
          try {
            final bookId = await core_api.parseBook(filePath: file);
            await _extractCover(bookId, file);
            success++;
          } catch (e, stack) {
            fail++;
            Logging.error(
              'scanFolder error: $file',
              exception: e,
              stackTrace: stack,
            );
          } finally {
            done++;
            onProgress?.call(done, total);
          }
        }),
      ),
    );

    return (success, fail);
  }

  /// 重新提取并保存书籍封面。
  Future<bool> reExtractCover(String bookId, String filePath) async {
    if (!cover_api.supportsCoverExtraction(filePath: filePath)) {
      return false;
    }
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final coverDir = p.join(appDir.path, 'zephyr_reader', 'covers');
      final coverPath = await cover_api.extractAndSaveCover(
        bookId: bookId,
        filePath: filePath,
        outputDir: coverDir,
      );
      return coverPath.isNotEmpty;
    } catch (e, stack) {
      Logging.error(
        'BookImportService.reExtractCover error',
        exception: e,
        stackTrace: stack,
      );
      return false;
    }
  }

  /// 提取书籍封面并保存到磁盘，失败不阻塞导入流程。
  Future<void> _extractCover(String bookId, String filePath) async {
    if (!cover_api.supportsCoverExtraction(filePath: filePath)) return;
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final coverDir = p.join(appDir.path, 'zephyr_reader', 'covers');
      await cover_api.extractAndSaveCover(
        bookId: bookId,
        filePath: filePath,
        outputDir: coverDir,
      );
    } catch (_) {
      // 封面提取失败不影响导入结果
    }
  }
}

/// 简单信号量，限制并发数。
class _Semaphore {
  final int _max;
  int _count = 0;
  final _queue = <Completer<void>>[];

  _Semaphore(this._max);

  Future<T> acquire<T>(Future<T> Function() fn) async {
    if (_count < _max) {
      _count++;
      try {
        return await fn();
      } finally {
        _release();
      }
    }
    final completer = Completer<void>();
    _queue.add(completer);
    await completer.future;
    return acquire(fn);
  }

  void _release() {
    if (_queue.isNotEmpty) {
      _count--;
      _queue.removeAt(0).complete();
    } else {
      _count--;
    }
  }
}
