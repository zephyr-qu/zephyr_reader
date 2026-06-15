import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/core/local/preferences_service.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/core/utils/cache_utils.dart';
import 'package:zephyr_reader/di/service_locator.dart';
import 'package:zephyr_reader/features/data/application/services/sync_models.dart';
import 'package:zephyr_reader/features/data/application/services/webdav_config_service.dart';
import 'package:zephyr_reader/features/data/application/services/webdav_sync_service.dart';

@injectable
/// 数据管理 ViewModel。
///
/// 管理 WebDAV 同步配置、同步状态和本地数据导出/导入。
class DataManagementViewModel {
  final configService = WebDavConfigService(prefs: getIt<PreferencesService>());

  final isConfigured = signal(false);
  final lastSyncTime = signal<DateTime?>(null);
  final serverUrl = signal<String>('');
  final isSyncing = signal(false);

  final loading = signal<bool>(true);

  /// 初始化 ViewModel，加载 WebDAV 配置。
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
    } finally {
      loading.value = false;
    }
  }

  /// 重新初始化（刷新全部数据）。
  Future<void> refresh() async {
    await initialize();
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

  /// 清除应用缓存。
  Future<void> clearCache() async {
    await SystemCache.clearCache();
  }

  /// Delegated to configService; exposed for dialog use.
  Future<WebDavConfig?> getConfig() => configService.getConfig();

  /// 保存 WebDAV 配置并更新 UI 状态。
  Future<void> saveConfig(WebDavConfig config) async {
    await configService.saveConfig(config);
    final updated = await configService.getConfig();
    isConfigured.value = updated != null;
    if (updated != null) {
      serverUrl.value = updated.baseUrl;
    }
  }

  /// 清除 WebDAV 配置，标记为未配置。
  Future<void> clearConfig() async {
    await configService.clearConfig();
    isConfigured.value = false;
    serverUrl.value = '';
    lastSyncTime.value = null;
  }

  /// 测试当前 WebDAV 配置是否可连接。
  Future<bool> testConnection() async {
    return await configService.testCurrentConfig();
  }

  void dispose() {
    isConfigured.dispose();
    lastSyncTime.dispose();
    serverUrl.dispose();
    isSyncing.dispose();
    loading.dispose();
  }
}
