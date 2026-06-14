/// 系统缓存管理器
///
/// 管理 OS 级临时/缓存目录及日志目录的清理与统计。
/// 不涉及业务数据（字体、封面、数据库等）。
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import './logging.dart';

class SystemCache {
  /// 清理系统缓存
  ///
  /// 返回清理的字节数
  static Future<int> clearCache() async {
    int totalBytes = 0;

    try {
      // 获取临时目录
      final tempDir = await getTemporaryDirectory();
      totalBytes += await _deleteDirectoryContents(tempDir);

      // 获取应用缓存目录
      final cacheDir = await getApplicationCacheDirectory();
      totalBytes += await _deleteDirectoryContents(cacheDir);

      // 清理日志文件
      final logDir = await _getLogDirectory();
      if (logDir != null) {
        totalBytes += await _deleteDirectoryContents(logDir);
      }
    } catch (e) {
      Logging.debug('清理缓存失败：$e');
    }

    return totalBytes;
  }

  /// 计算系统缓存大小
  ///
  /// 返回缓存总字节数
  static Future<int> getCacheSize() async {
    int totalBytes = 0;

    try {
      // 临时目录
      final tempDir = await getTemporaryDirectory();
      totalBytes += await _calculateDirectorySize(tempDir);

      // 应用缓存目录
      final cacheDir = await getApplicationCacheDirectory();
      totalBytes += await _calculateDirectorySize(cacheDir);

      // 日志目录
      final logDir = await _getLogDirectory();
      if (logDir != null) {
        totalBytes += await _calculateDirectorySize(logDir);
      }
    } catch (e) {
      Logging.debug('计算缓存大小失败：$e');
    }

    return totalBytes;
  }

  /// 遍历目录内容，对每个条目执行 [action] 并返回结果总和。
  static Future<int> _walkDir(
    Directory dir,
    String errorLabel,
    Future<int> Function(FileSystemEntity) action,
  ) async {
    if (!await dir.exists()) return 0;
    int total = 0;
    try {
      await for (final entity
          in dir.list(recursive: true, followLinks: false)) {
        total += await action(entity);
      }
    } catch (e) {
      Logging.debug('$errorLabel：$e');
    }
    return total;
  }

  /// 删除目录内容，返回删除的字节数。
  static Future<int> _deleteDirectoryContents(Directory dir) {
    return _walkDir(dir, '删除目录内容失败', (entity) async {
      if (entity is File) {
        final len = await entity.length();
        await entity.delete();
        return len;
      } else if (entity is Directory) {
        await entity.delete(recursive: true);
      }
      return 0;
    });
  }

  /// 计算目录大小。
  static Future<int> _calculateDirectorySize(Directory dir) {
    return _walkDir(dir, '计算目录大小失败', (entity) async {
      if (entity is File) {
        return await entity.length();
      }
      return 0;
    });
  }

  /// 获取日志目录
  static Future<Directory?> _getLogDirectory() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final logDir = Directory(p.join(appDir.path, 'zephyr_reader', 'logs'));
      if (await logDir.exists()) {
        return logDir;
      }
    } catch (e) {
      Logging.debug('获取日志目录失败：$e');
    }
    return null;
  }
}
