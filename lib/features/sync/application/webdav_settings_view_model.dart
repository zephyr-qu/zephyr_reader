import 'package:signals_flutter/signals_flutter.dart';

import 'services/webdav_config_service.dart';
import 'services/webdav_sync_service.dart';
import 'services/sync_models.dart';
import 'sync_view_model.dart';

class WebDavSettingsViewModel {
  final WebDavConfigService configService;
  final WebDavSyncService syncService;
  final SyncViewModel syncVm;

  final isConfigured = signal(false);
  final autoSyncEnabled = signal(false);
  final autoSyncInterval = signal(30);
  final isTesting = signal(false);
  final testResult = signal<bool?>(null);
  final lastSyncTime = signal<DateTime?>(null);
  final syncStatusText = signal('未配置');
  final isSyncing = signal(false);
  final syncMessage = signal('');
  final syncProgress = signal(0.0);
  final conflicts = signal<List<ConflictInfo>>([]);

  WebDavSettingsViewModel({
    required this.configService,
    required this.syncService,
    required this.syncVm,
  }) {
    _syncFromConfigService();
  }

  void _syncFromConfigService() {
    isConfigured.value = configService.isConfigured.value;
    autoSyncEnabled.value = configService.autoSyncEnabled.value;
    autoSyncInterval.value = configService.autoSyncInterval.value;
  }

  Future<void> loadConfigStatus() async {
    final config = await configService.getConfig();
    isConfigured.value = config != null;
    lastSyncTime.value = await configService.getLastSyncTime();
    syncStatusText.value = config != null ? '已配置' : '未配置';
    _syncFromConfigService();
  }

  Future<bool> testConnection() async {
    isTesting.value = true;
    testResult.value = null;
    try {
      final result = await configService.testCurrentConfig();
      testResult.value = result;
      return result;
    } catch (_) {
      testResult.value = false;
      return false;
    } finally {
      isTesting.value = false;
    }
  }

  Future<WebDavConfig?> getConfig() => configService.getConfig();

  Future<void> saveConfig(WebDavConfig config) async {
    await configService.saveConfig(config);
    isConfigured.value = true;
  }

  Future<void> clearConfig() async {
    await configService.clearConfig();
    isConfigured.value = false;
  }

  Future<void> toggleAutoSync(bool enabled) async {
    autoSyncEnabled.value = enabled;
    await configService.setAutoSync(enabled: enabled);
  }

  Future<void> setAutoSyncInterval(int minutes) async {
    autoSyncInterval.value = minutes;
    await configService.setAutoSync(enabled: true, intervalMinutes: minutes);
  }

  void resetTestResult() {
    testResult.value = null;
  }

  Future<void> performSync(SyncDirection direction) async {
    final config = await configService.getConfig();
    if (config == null) return;

    syncService.setConfig(config);
    isSyncing.value = true;
    syncMessage.value = '准备同步...';
    syncProgress.value = 0.0;
    conflicts.value = [];

    try {
      final subscription = syncService.eventStream.listen((event) {
        syncMessage.value = event.message;
        if (event.progress != null && event.total != null) {
          syncProgress.value = event.progress! / event.total!;
        }
        if (event.type == SyncEventType.conflict &&
            event.conflictInfo != null) {
          conflicts.value = [...conflicts.value, event.conflictInfo!];
        }
      });

      final result = await syncService.syncAll(
        direction: direction,
        autoResolveConflicts: true,
      );

      await subscription.cancel();

      final now = DateTime.now();
      lastSyncTime.value = now;
      await configService.setLastSyncTime(now);

      if (!result.success && result.conflictCount > 0) {
        syncMessage.value = '同步完成，但存在 ${result.conflictCount} 个冲突';
      } else if (result.success) {
        syncMessage.value =
            '同步完成！上传：${result.uploadedCount}, 下载：${result.downloadedCount}';
      } else {
        syncMessage.value = '同步失败：${result.error ?? "未知错误"}';
      }
    } catch (e) {
      syncMessage.value = '同步异常：$e';
    } finally {
      isSyncing.value = false;
    }
  }

  void dispose() {
    isConfigured.dispose();
    autoSyncEnabled.dispose();
    autoSyncInterval.dispose();
    isTesting.dispose();
    testResult.dispose();
    lastSyncTime.dispose();
    syncStatusText.dispose();
    isSyncing.dispose();
    syncMessage.dispose();
    syncProgress.dispose();
    conflicts.dispose();
  }
}
