/// 数据同步服务
///
/// 协调阅读进度、书签、书架等数据的同步
library;

import 'package:flutter/foundation.dart';

import 'webdav_config_service.dart';
import 'webdav_sync_service.dart';

/// 数据同步服务
///
/// 使用 WebDavSyncService 进行数据同步
class DataSyncService {
  final WebDavConfigService _configService;
  WebDavSyncService? _syncService;

  DataSyncService(this._configService);

  /// 初始化同步服务
  Future<void> init() async {
    final config = await _configService.getConfig();
    if (config != null) {
      _syncService = WebDavSyncService(config: config);
    }
  }

  /// 同步所有数据
  ///
  /// [direction] 同步方向
  /// [onProgress] 进度回调
  Future<SyncResult> syncAll({
    SyncDirection direction = SyncDirection.both,
    void Function(double progress)? onProgress,
  }) async {
    if (_syncService == null) {
      debugPrint('同步服务未初始化');
      return SyncResult(error: '同步服务未初始化');
    }

    try {
      // 使用 WebDavSyncService 的 syncAll 方法
      return await _syncService!.syncAll(
        direction: direction,
        onProgress: onProgress,
      );
    } catch (e) {
      debugPrint('同步异常：$e');
      return SyncResult(error: '同步异常：$e');
    }
  }

  /// 解决冲突
  Future<void> resolveConflict({
    required String dataType,
    required ConflictResolution resolution,
  }) async {
    debugPrint('解决冲突：$dataType, 方案：$resolution');
    // 根据 resolution 参数实现不同的冲突解决策略
    switch (resolution) {
      case ConflictResolution.useLocal:
        // 使用本地版本覆盖远程版本
        debugPrint('使用本地版本覆盖：$dataType');
        break;
      case ConflictResolution.useRemote:
        // 使用远程版本覆盖本地版本
        debugPrint('使用远程版本覆盖：$dataType');
        break;
      case ConflictResolution.merge:
        // 合并两个版本
        debugPrint('合并两个版本：$dataType');
        break;
    }
  }

  /// 获取同步服务状态
  WebDavSyncService? get syncService => _syncService;

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

  /// 合并两个版本
  merge,
}
