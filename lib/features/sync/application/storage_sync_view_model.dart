

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
import 'package:zephyr_reader/src/rust/api/data/stats.dart' as rust_stats;

@injectable
class StorageSyncViewModel {
  final configService = WebDavConfigService(prefs: getIt<SharedPreferences>());

  final isConfigured = signal(false);
  final lastSyncTime = signal<DateTime?>(null);
  final serverUrl = signal<String>('');
  final isSyncing = signal(false);

  final cacheSize = signal<int>(0);
  final dbSize = signal<int>(0);
  final booksSize = signal<int>(0);
  final totalUsed = signal<int>(0);
  final totalAvailable = signal<int>(0);

  final noteCount = signal<int>(0);


  final loading = signal<bool>(true);

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

      await Future.wait([_calcStorage(), _loadNoteCount()]);
    } finally {
      loading.value = false;
    }
  }

  Future<void> refresh() async {
    await initialize();
  }

  Future<void> _calcStorage() async {
    final cacheBytes = await CacheUtils.getCacheSize();
    cacheSize.value = cacheBytes;

    final appDir = await getApplicationDocumentsDirectory();
    final totalBytes = await _dirSize(appDir);
    totalUsed.value = totalBytes;

    final dbFile = File(p.join(appDir.path, 'reader.db'));
    dbSize.value = await dbFile.length();

    booksSize.value = (totalBytes - cacheBytes - dbSize.value).clamp(
      0,
      totalBytes,
    );
  }

  Future<void> _loadNoteCount() async {
    try {
      final global = await rust_stats.getGlobalReadingStats();
      noteCount.value = global.totalNotesCount;
    } catch (_) {
      noteCount.value = 0;
    }
  }

  Future<int> _dirSize(Directory dir) async {
    int total = 0;
    try {
      await for (final entity in dir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File) total += await entity.length();
      }
    } catch (e) {
      Logging.error('计算缓存大小失败', exception: e);
    }
    return total;
  }

  String formatBytes(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

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

  Future<void> clearCache() async {
    await CacheUtils.clearCache();
    await _calcStorage();
  }

  /// Delegated to configService; exposed for dialog use.
  Future<WebDavConfig?> getConfig() => configService.getConfig();
  Future<void> saveConfig(WebDavConfig config) {
    isConfigured.value = true;
    serverUrl.value = config.baseUrl;
    return configService.saveConfig(config);
  }
  Future<void> clearConfig() {
    isConfigured.value = false;
    serverUrl.value = '';
    return configService.clearConfig();
  }

  Future<bool> testConnection() async {
    return await configService.testCurrentConfig();
  }
}
