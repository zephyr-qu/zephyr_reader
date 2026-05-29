import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:signals_flutter/signals_flutter.dart';

import 'package:zephyr_reader/core/battery/battery_state_service.dart';
import 'package:zephyr_reader/core/network/network_state_service.dart';

import 'sync_models.dart';

class WebdavAutoSyncService {
  final Signal<AutoSyncConfig> config;
  final Future<SyncResult> Function(SyncDirection direction) onSync;
  final void Function(SyncEvent) emitEvent;
  Timer? _timer;

  static const String _autoSyncConfigFile = 'auto_sync_config.json';

  WebdavAutoSyncService({
    required this.config,
    required this.onSync,
    required this.emitEvent,
  }) {
    _loadAutoSyncConfig();
  }

  void start() {
    stop();

    final cfg = config.value;
    if (!cfg.enabled) {
      return;
    }

    _timer = Timer.periodic(cfg.interval, (_) async {
      await _performAutoSync();
    });

    emitEvent(
      SyncEvent(
        type: SyncEventType.started,
        message: '定时同步已启动，间隔 ${cfg.interval.inMinutes} 分钟',
      ),
    );
  }

  void stop() {
    _timer?.cancel();
    _timer = null;

    emitEvent(SyncEvent(type: SyncEventType.cancelled, message: '定时同步已停止'));
  }

  Future<void> updateConfig(AutoSyncConfig newConfig) async {
    config.value = newConfig;
    await _saveAutoSyncConfig();

    if (newConfig.enabled) {
      start();
    } else {
      stop();
    }
  }

  Future<void> _performAutoSync() async {
    final cfg = config.value;
    if (!cfg.enabled) {
      return;
    }

    if (cfg.onlyOnWifi) {
      final isWifi = await NetworkStateService().isOnWifi();
      if (!isWifi) {
        debugPrint('定时同步跳过：非 WiFi 网络');
        return;
      }
    }

    if (cfg.requireCharging) {
      final isCharging = await BatteryStateService().isCharging();
      if (!isCharging) {
        debugPrint('定时同步跳过：设备未充电');
        return;
      }
    }

    await onSync(cfg.direction);
  }

  Future<void> _loadAutoSyncConfig() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final configFile = File(p.join(appDir.path, _autoSyncConfigFile));

      if (await configFile.exists()) {
        final content = await configFile.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        config.value = AutoSyncConfig.fromJson(json);
      }
    } catch (e) {
      debugPrint('加载自动同步配置失败：$e');
    }
  }

  Future<void> _saveAutoSyncConfig() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final configFile = File(p.join(appDir.path, _autoSyncConfigFile));

      await configFile.writeAsString(
        jsonEncode(config.value.toJson()),
        flush: true,
      );
    } catch (e) {
      debugPrint('保存自动同步配置失败：$e');
    }
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
