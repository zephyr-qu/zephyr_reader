import 'dart:async';
import 'dart:io';

import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/core/utils/cache_utils.dart';
import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/di/service_locator.dart';
import 'package:zephyr_reader/features/sync/application/services/sync_models.dart';
import 'package:zephyr_reader/features/sync/application/services/webdav_config_service.dart';
import 'package:zephyr_reader/features/sync/application/services/webdav_sync_service.dart';

@injectable
/// 存储同步 ViewModel。
///
/// 管理 WebDAV 同步配置、同步状态和本地数据导出/导入。
class StorageSyncViewModel {
  final configService = WebDavConfigService(prefs: getIt<SharedPreferences>());

  final isConfigured = signal(false);
  final lastSyncTime = signal<DateTime?>(null);
  final serverUrl = signal<String>('');
  final isSyncing = signal(false);

  // UNUSED: 以下 5 个存储用量信号由 _calcStorage() 计算，但页面从未读取展示
  final cacheSize = signal<int>(0);
  final dbSize = signal<int>(0);
  final booksSize = signal<int>(0);
  final totalUsed = signal<int>(0);
  final totalAvailable = signal<int>(0);
  // (noteCount 已移除 — 死代码)

  final loading = signal<bool>(true);

  /// 初始化 ViewModel，加载 WebDAV 配置、存储用量和笔记数量。
  Future<void> initialize() async {
    loading.value = true;
    try {
      isConfigured.value = configService.isConfigured.value;
      final time = await configService.getLastSyncTime();
      lastSyncTime.value = time;

      final config = await configService.getConfig();
      if (config != null) {
        serverUrl.value = config.baseUrl;
      }

      await _calcStorage();
    } finally {
      loading.value = false;
    }
  }

  /// 重新初始化（刷新全部数据）。
  Future<void> refresh() async {
    await initialize();
  }

  /// 计算应用缓存、数据库和书籍文件的大小。
  Future<void> _calcStorage({int? knownCacheBytes}) async {
    final cacheBytes = knownCacheBytes ?? await SystemCache.getCacheSize();
    cacheSize.value = cacheBytes;

    final appDir = await getApplicationDocumentsDirectory();
    final totalBytes = await _dirSize(appDir);
    totalUsed.value = totalBytes;

    final dbFile = File(p.join(appDir.path, 'reader.db'));
    dbSize.value = dbFile.existsSync() ? await dbFile.length() : 0;

    booksSize.value = (totalBytes - cacheBytes - dbSize.value).clamp(
      0,
      totalBytes,
    );
  }

  /// 递归计算目录下所有文件的总字节数。
  Future<int> _dirSize(Directory dir) async {
    int total = 0;
    try {
      await for (final entity in dir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File) {
          try {
            total += await entity.length();
          } catch (e) {
            Logging.error('计算文件大小失败: ${entity.path}', exception: e);
          }
        }
      }
    } catch (e) {
      Logging.error('计算缓存大小失败', exception: e);
    }
    return total;
  }

  /// 将字节数格式化为可读字符串（KB / MB / GB）。
  String formatBytes(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// 触发 WebDAV 全量同步（上传+下载）。
  Future<SyncResult?> triggerSync() async {
    final config = await configService.getConfig();
    if (config == null) return null;

    isSyncing.value = true;
    try {
      final service = getIt<WebDavSyncService>();
      service.setConfig(config);
      final result = await service.syncAll();
      await configService.setLastSyncTime(DateTime.now());
      lastSyncTime.value = DateTime.now();
      return result;
    } finally {
      isSyncing.value = false;
    }
  }

  /// 清除应用缓存并重新计算存储用量。
  Future<void> clearCache() async {
    await SystemCache.clearCache();
    await _calcStorage(knownCacheBytes: 0);
  }

  /// Delegated to configService; exposed for dialog use.
  Future<WebDavConfig?> getConfig() => configService.getConfig();

  /// 保存 WebDAV 配置并更新 UI 状态。
  Future<void> saveConfig(WebDavConfig config) {
    isConfigured.value = true;
    serverUrl.value = config.baseUrl;
    return configService.saveConfig(config);
  }

  /// 清除 WebDAV 配置，标记为未配置。
  Future<void> clearConfig() {
    isConfigured.value = false;
    serverUrl.value = '';
    return configService.clearConfig();
  }

  /// 测试当前 WebDAV 配置是否可连接。
  Future<bool> testConnection() async {
    return await configService.testCurrentConfig();
  }
}
