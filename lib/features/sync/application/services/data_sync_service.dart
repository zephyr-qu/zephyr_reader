/// 数据同步服务
///
/// 协调阅读进度、书签、书架等数据的同�?library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'webdav_sync_service.dart';
import 'webdav_config_service.dart';

/// 数据同步服务
class DataSyncService {
  final WebDavConfigService _configService;
  WebDavSyncService? _syncService;

  DataSyncService(this._configService);

  /// 初始化同步服�?
   Future<void> init() async {
    final config = await _configService.getConfig();
    if (config != null) {
      _syncService = WebDavSyncService(config: config);
    }
  }

  /// 同步所有数�?
   Future<SyncResult> syncAll({
    SyncDirection direction = SyncDirection.both,
  }) async {
    if (_syncService == null) {
      debugPrint('同步服务未初始化');
      return SyncResult(error: '同步服务未初始化');
    }

    try {
      final result = SyncResult();

      // 同步阅读进度
      final progressResult = await _syncReadingProgress(direction);
      result.uploadedCount += progressResult.uploadedCount;
      result.downloadedCount += progressResult.downloadedCount;
      result.conflictCount += progressResult.conflictCount;

      // 同步书签
      final bookmarkResult = await _syncBookmarks(direction);
      result.uploadedCount += bookmarkResult.uploadedCount;
      result.downloadedCount += bookmarkResult.downloadedCount;
      result.conflictCount += bookmarkResult.conflictCount;

      // 同步书架
      final bookshelfResult = await _syncBookshelf(direction);
      result.uploadedCount += bookshelfResult.uploadedCount;
      result.downloadedCount += bookshelfResult.downloadedCount;
      result.conflictCount += bookshelfResult.conflictCount;

      result.success = result.conflictCount == 0;
      return result;
    } catch (e) {
      debugPrint('同步异常�?e');
      return SyncResult(error: '同步异常�?e');
    }
  }

  /// 导出阅读进度�?JSON
  Future<void> _exportReadingProgress(String localPath) async {
    // 从数据库�?SharedPreferences 读取阅读进度
    // 这里使用示例数据结构
    final progressData = <String, dynamic>{};
    final file = File(localPath);
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(progressData));
  }

  /// 导入阅读进度
  Future<void> _importReadingProgress(String localPath) async {
    try {
      final file = File(localPath);
      if (await file.exists()) {
        final content = await file.readAsString();
        final progressData = jsonDecode(content) as Map<String, dynamic>;
        // 将进度数据导入到本地数据库或 SharedPreferences
        debugPrint('导入阅读进度�?{progressData.length} 条记�?');
      }
    } catch (e) {
      debugPrint('导入阅读进度失败�?e');
    }
  }

  /// 同步阅读进度
  Future<SyncResult> _syncReadingProgress(SyncDirection direction) async {
    final result = SyncResult();

    try {
      final dir = await getApplicationDocumentsDirectory();
      final localPath = '${dir.path}/zephyr_reader/reading_progress.json';

      if (direction == SyncDirection.upload ||
          direction == SyncDirection.both) {
        await _exportReadingProgress(localPath);

        if (await _syncService!.uploadFile(
          localPath: localPath,
          remoteName: 'reading_progress.json',
        )) {
          result.uploadedCount++;
        }
      }

      if (direction == SyncDirection.download ||
          direction == SyncDirection.both) {
        if (await _syncService!.downloadFile(
          remoteName: 'reading_progress.json',
          localPath: localPath,
        )) {
          await _importReadingProgress(localPath);
          result.downloadedCount++;
        }
      }
    } catch (e) {
      debugPrint('阅读进度同步异常�?e');
    }

    return result;
  }

  /// 导出书签�?JSON
  Future<void> _exportBookmarks(String localPath) async {
    // 从数据库读取书签数据
    // 这里使用示例数据结构
    final bookmarkData = <dynamic>[];
    final file = File(localPath);
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(bookmarkData));
  }

  /// 导入书签
  Future<void> _importBookmarks(String localPath) async {
    try {
      final file = File(localPath);
      if (await file.exists()) {
        final content = await file.readAsString();
        final bookmarkData = jsonDecode(content) as List<dynamic>;
        // 将书签数据导入到本地数据�?
          debugPrint('导入书签�?{bookmarkData.length} 条记�?');
      }
    } catch (e) {
      debugPrint('导入书签失败�?e');
    }
  }

  /// 同步书签
  Future<SyncResult> _syncBookmarks(SyncDirection direction) async {
    final result = SyncResult();

    try {
      final dir = await getApplicationDocumentsDirectory();
      final localPath = '${dir.path}/zephyr_reader/bookmarks.json';

      if (direction == SyncDirection.upload ||
          direction == SyncDirection.both) {
        await _exportBookmarks(localPath);

        if (await _syncService!.uploadFile(
          localPath: localPath,
          remoteName: 'bookmarks.json',
        )) {
          result.uploadedCount++;
        }
      }

      if (direction == SyncDirection.download ||
          direction == SyncDirection.both) {
        if (await _syncService!.downloadFile(
          remoteName: 'bookmarks.json',
          localPath: localPath,
        )) {
          await _importBookmarks(localPath);
          result.downloadedCount++;
        }
      }
    } catch (e) {
      debugPrint('书签同步异常�?e');
    }

    return result;
  }

  /// 导出书架�?JSON
  Future<void> _exportBookshelf(String localPath) async {
    // 从数据库读取书架数据
    // 这里使用示例数据结构
    final bookshelfData = <dynamic>[];
    final file = File(localPath);
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(bookshelfData));
  }

  /// 导入书架
  Future<void> _importBookshelf(String localPath) async {
    try {
      final file = File(localPath);
      if (await file.exists()) {
        final content = await file.readAsString();
        final bookshelfData = jsonDecode(content) as List<dynamic>;
        // 将书架数据导入到本地数据�?        debugPrint('导入书架�?{bookshelfData.length} 本书');
      }
    } catch (e) {
      debugPrint('导入书架失败�?e');
    }
  }

  /// 同步书架
  Future<SyncResult> _syncBookshelf(SyncDirection direction) async {
    final result = SyncResult();

    try {
      final dir = await getApplicationDocumentsDirectory();
      final localPath = '${dir.path}/zephyr_reader/bookshelf.json';

      if (direction == SyncDirection.upload ||
          direction == SyncDirection.both) {
        await _exportBookshelf(localPath);

        if (await _syncService!.uploadFile(
          localPath: localPath,
          remoteName: 'bookshelf.json',
        )) {
          result.uploadedCount++;
        }
      }

      if (direction == SyncDirection.download ||
          direction == SyncDirection.both) {
        if (await _syncService!.downloadFile(
          remoteName: 'bookshelf.json',
          localPath: localPath,
        )) {
          await _importBookshelf(localPath);
          result.downloadedCount++;
        }
      }
    } catch (e) {
      debugPrint('书架同步异常�?e');
    }

    return result;
  }

  /// 解决冲突
  Future<void> resolveConflict({
    required String dataType,
    required ConflictResolution resolution,
  }) async {
    debugPrint('解决冲突�?dataType, 方案�?resolution');
    // 根据 resolution 参数实现不同的冲突解决策�?
      switch (resolution) {
      case ConflictResolution.useLocal:
        // 使用本地版本覆盖远程版本
        debugPrint('使用本地版本覆盖�?dataType');
        break;
      case ConflictResolution.useRemote:
        // 使用远程版本覆盖本地版本
        debugPrint('使用远程版本覆盖�?dataType');
        break;
      case ConflictResolution.keepBoth:
        // 保留两个版本，创建副�?        debugPrint('保留两个版本�?dataType');
        break;
      case ConflictResolution.skip:
        // 跳过本次同步
        debugPrint('跳过同步�?dataType');
        break;
    }
  }

  /// 释放资源
  void dispose() {
    _syncService?.dispose();
  }
}

/// 冲突解决策略
enum ConflictResolution {
  /// 使用本地版本
  useLocal,

  /// 使用远程版本
  useRemote,

  /// 保留两个版本
  keepBoth,

  /// 跳过
  skip,
}
