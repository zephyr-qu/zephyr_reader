/// 缓存管理器
///
/// 提供缓存清理、缓存大小计算等功能
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// 缓存管理器
class CacheUtils {
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
      debugPrint('清理缓存失败：$e');
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
      debugPrint('计算缓存大小失败：$e');
    }

    return totalBytes;
  }

  /// 格式化缓存大小
  static String formatCacheSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(2)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }

  /// 删除目录内容
  static Future<int> _deleteDirectoryContents(Directory dir) async {
    int totalBytes = 0;

    if (!await dir.exists()) {
      return 0;
    }

    try {
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          totalBytes += await entity.length();
          await entity.delete();
        } else if (entity is Directory) {
          await entity.delete(recursive: true);
        }
      }
    } catch (e) {
      debugPrint('删除目录内容失败：$e');
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
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          totalBytes += await entity.length();
        }
      }
    } catch (e) {
      debugPrint('计算目录大小失败：$e');
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
      debugPrint('获取日志目录失败：$e');
    }
    return null;
  }
}
