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
import 'package:zephyr_reader/src/rust/api/data/book.dart' as book_api;
import 'package:zephyr_reader/src/rust/api/data/vocabulary.dart' as vocab_api;
import 'package:zephyr_reader/src/rust/api/search.dart';

@injectable
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
    final cacheBytes = knownCacheBytes ?? await CacheManager.getCacheSize();
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
    await CacheManager.clearCache();
    await _calcStorage(knownCacheBytes: 0);
  }

  /// 清除全部本地数据：删除所有书籍、笔记、生词本、缓存和同步配置。
  Future<void> clearAllLocalData() async {
    try {
      // 1. 删除所有书籍（级联删除笔记/书签/进度）
      final books = await book_api.listBooks();
      final appDir = await getApplicationDocumentsDirectory();
      final coversDir = p.join(appDir.path, 'covers');
      for (final book in books) {
        try {
          await book_api.deleteBook(bookId: book.bookId, coversDir: coversDir);
        } catch (e) {
          Logging.error('删除书籍失败', exception: e);
        }
      }

      // 2. 删除所有生词
      final allVocab = await vocab_api.listVocabularyByStatus();
      for (final word in allVocab) {
        try {
          await vocab_api.deleteVocabulary(id: word.id);
        } catch (e) {
          Logging.error('删除生词失败', exception: e);
        }
      }

      // 3. 清除搜索索引
      try {
        await clearAll();
      } catch (e) {
        Logging.error('清除搜索索引失败', exception: e);
      }

      // 4. 清除缓存
      await CacheManager.clearCache();

      // 5. 清除 WebDAV 同步配置
      await clearConfig();

      // 6. 重置信号状态
      lastSyncTime.value = null;
      isConfigured.value = false;
      serverUrl.value = '';
      cacheSize.value = 0;
      dbSize.value = 0;
      booksSize.value = 0;
      totalUsed.value = 0;
      totalAvailable.value = 0;

      // 7. 重新计算当前存储用量
      await _calcStorage(knownCacheBytes: 0);
    } catch (e) {
      Logging.error('清除全部数据失败', exception: e);
      rethrow;
    }
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
