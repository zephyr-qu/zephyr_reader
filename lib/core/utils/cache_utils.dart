/// 缓存管理器
///
/// 提供应用缓存清理与大小统计的静态方法。
/// 涵盖临时目录、应用缓存目录及日志目录。
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import './logging.dart';

class CacheManager {
  /// 清理缓存
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

  /// 计算缓存大小
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

  /// 删除目录内容
  static Future<int> _deleteDirectoryContents(Directory dir) async {
    int totalBytes = 0;

    if (!await dir.exists()) {
      return 0;
    }

    try {
      await for (final entity in dir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File) {
          totalBytes += await entity.length();
          await entity.delete();
        } else if (entity is Directory) {
          await entity.delete(recursive: true);
        }
      }
    } catch (e) {
      Logging.debug('删除目录内容失败：$e');
    }

    return totalBytes;
  }

  /// 计算目录大小
  static Future<int> _calculateDirectorySize(Directory dir) async {
    int totalBytes = 0;

    if (!await dir.exists()) {
      return 0;
    }

    try {
      await for (final entity in dir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File) {
          totalBytes += await entity.length();
        }
      }
    } catch (e) {
      Logging.debug('计算目录大小失败：$e');
    }

    return totalBytes;
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
