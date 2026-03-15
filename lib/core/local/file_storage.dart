import 'dart:io';
import 'dart:typed_data';

import 'package:injectable/injectable.dart';
import 'package:path_provider/path_provider.dart';

import '../../shared/utils/logging.dart';

@LazySingleton()
class FileStorage {
  // 缓存目录，避免重复调用平台通道
  late Future<Directory> _appDir;
  late Future<Directory> _tempDir;

  @PostConstruct()
  Future<void> init() async {
    _appDir = getApplicationDocumentsDirectory();
    _tempDir = getTemporaryDirectory();
  }

  Future<Directory> get appDirectory => _appDir;
  Future<Directory> get tempDirectory => _tempDir;

  Future<String> _buildPath(String filename, {bool useTemp = false}) async {
    final dir = useTemp ? await tempDirectory : await appDirectory;
    return '${dir.path}/$filename';
  }

  // ========== 常用操作 ==========

  /// 保存文本到文件
  Future<bool> saveString(
    String filename,
    String content, {
    bool useTemp = false,
  }) async {
    try {
      final path = await _buildPath(filename, useTemp: useTemp);
      final file = File(path);
      await file.writeAsString(content, flush: true);
      return true;
    } catch (e) {
      _logError('saveString failed: $e');
      return false;
    }
  }

  /// 读取文本文件
  Future<String?> readString(String filename, {bool useTemp = false}) async {
    try {
      final path = await _buildPath(filename, useTemp: useTemp);
      final file = File(path);
      if (await file.exists()) {
        return await file.readAsString();
      }
      return null;
    } catch (e) {
      _logError('readString failed: $e');
      return null;
    }
  }

  /// 保存二进制数据
  Future<bool> saveBytes(
    String filename,
    Uint8List bytes, {
    bool useTemp = false,
  }) async {
    try {
      final path = await _buildPath(filename, useTemp: useTemp);
      final file = File(path);
      await file.writeAsBytes(bytes, flush: true);
      return true;
    } catch (e) {
      _logError('saveBytes failed: $e');
      return false;
    }
  }

  /// 读取二进制数据
  Future<Uint8List?> readBytes(String filename, {bool useTemp = false}) async {
    try {
      final path = await _buildPath(filename, useTemp: useTemp);
      final file = File(path);
      if (await file.exists()) {
        return await file.readAsBytes();
      }
      return null;
    } catch (e) {
      _logError('readBytes failed: $e');
      return null;
    }
  }

  /// 检查文件是否存在
  Future<bool> exists(String filename, {bool useTemp = false}) async {
    final path = await _buildPath(filename, useTemp: useTemp);
    return await File(path).exists();
  }

  /// 删除文件
  Future<bool> delete(String filename, {bool useTemp = false}) async {
    try {
      final path = await _buildPath(filename, useTemp: useTemp);
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      _logError('delete failed: $e');
      return false;
    }
  }

  /// 清空临时目录（谨慎使用）
  Future<bool> clearTemp() async {
    try {
      final dir = await tempDirectory;
      final files = dir.listSync();
      for (var file in files) {
        await file.delete(recursive: true);
      }
      return true;
    } catch (e) {
      _logError('clearTemp failed: $e');
      return false;
    }
  }

  /// 获取目录使用空间（KB）
  Future<int> getUsage({bool includeTemp = false}) async {
    try {
      final dir = await appDirectory;
      final usage = await _getDirSize(dir);
      if (includeTemp) {
        final temp = await tempDirectory;
        return usage + await _getDirSize(temp);
      }
      return usage;
    } catch (e) {
      _logError('getUsage failed: $e');
      return 0;
    }
  }

  /// 获取目录 使用空间（KB）
  Future<int> _getDirSize(Directory dir) async {
    int total = 0;
    final files = dir.listSync(recursive: true, followLinks: false);
    for (var file in files) {
      if (file is File) {
        total += await file.length();
      }
    }
    return (total / 1024).ceil();
  }

  void _logError(String msg) {
    Logging.error(msg);
  }
}
