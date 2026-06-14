import 'dart:async';

import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/core/utils/app_error_mapper.dart';
import 'package:file_picker/file_picker.dart';
import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/core/local/preferences_service.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/core/settings/settings_keys.dart';
import 'package:zephyr_reader/src/rust/api/backup.dart' as backup_api;

enum BackupStatus {
  idle,
  exporting,
  exportingDone,
  restoring,
  restoringDone,
  error,
}


/// 本地备份 ViewModel
///
/// 状态机：
///   idle → exporting → exportingDone → idle
///   idle → restoring → restoringDone → idle
///   任意 → error → idle
@lazySingleton
class BackupViewModel {
  final PreferencesService _prefs;

  BackupViewModel(this._prefs);

  // ============ Signals ============

  final status = signal(BackupStatus.idle);
  final errorMessage = signal<String?>(null);
  final lastBackupAt = signal<DateTime?>(null);
  final currentStats = asyncSignal<backup_api.BackupStats?>(
    AsyncState.loading(),
  );

  // ============ 初始化 ============

  /// 从 PreferencesService 恢复上次备份的元信息，并刷新当前数据库统计。
  Future<void> initialize() async {
    _readLastBackupMeta();
    await _refreshStats();
  }

  /// 从 PreferencesService 读取上次备份的时间戳和文件大小，写入对应 signal。
  void _readLastBackupMeta() {
    final ts = _prefs.getIntOrNull(SettingsKeys.lastBackupAt);
    batch(() {
      if (ts != null) {
        lastBackupAt.value = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
      }
    });
  }

  /// 调用 Rust 侧获取当前数据库的备份统计信息（如记录数、大小）。
  Future<void> _refreshStats() async {
    try {
      currentStats.value = AsyncState.data(await backup_api.getBackupStats());
    } catch (e) {
      Logging.warning('获取备份统计失败: $e');
      currentStats.value = AsyncState.error(e);
    }
  }

  // ============ 操作 ============

  /// 执行备份导出流程：
  /// 1. 弹出系统文件保存对话框让用户选择位置
  /// 2. 调用 Rust 侧导出数据库
  /// 3. 记录备份元信息并更新界面状态
  ///
  /// 用户取消选择时不会产生任何副作用。
  Future<void> performBackup() async {
    if (status.value != BackupStatus.idle) return;

    batch(() {
      status.value = BackupStatus.exporting;
      errorMessage.value = null;
    });

    try {
      // 1. 文件选择：用户选保存目录+文件名
      final now = DateTime.now();
      final suggestedName =
          'zephyr-backup-${now.year}${_pad(now.month)}${_pad(now.day)}-${_pad(now.hour)}${_pad(now.minute)}.db';

      final dirPath = await FilePicker.getDirectoryPath(
        dialogTitle: '选择备份保存位置',
      );
      if (dirPath == null) {
        status.value = BackupStatus.idle;
        return; // 用户取消
      }
      final savePath = '$dirPath/$suggestedName';

      // 2. 调用 Rust 导出到所选路径
      final manifest = await backup_api.exportDatabase(destPath: savePath);

      // 3. 记录元信息
      await _prefs.setInt(SettingsKeys.lastBackupAt, manifest.exportedAt);
      await _prefs.setInt(SettingsKeys.lastBackupSize, manifest.dbSize);
      batch(() {
        _readLastBackupMeta();
        status.value = BackupStatus.exportingDone;
      });
    } catch (e) {
      batch(() {
        errorMessage.value = AppErrorMapper.humanReadable(e);
        status.value = BackupStatus.error;
      });
    }
  }

  /// 执行恢复流程：
  /// 1. 将指定备份文件恢复至本地数据库
  /// 2. 更新备份元信息
  ///
  /// [filePath] 为备份文件路径，[manifest] 为备份时记录的清单信息。
  Future<void> performRestore(
    String filePath,
    backup_api.BackupManifest manifest,
  ) async {
    if (status.value != BackupStatus.idle) return;

    batch(() {
      status.value = BackupStatus.restoring;
      errorMessage.value = null;
    });

    try {
      await backup_api.restoreDatabase(backupPath: filePath);
      // 清理 7 天前的自动快照
      try {
        final cutoff =
            DateTime.now()
                .subtract(const Duration(days: 7))
                .millisecondsSinceEpoch ~/
            1000;
        await backup_api.cleanupAutoSnapshots(olderThanUnix: cutoff);
      } catch (_) {
        // 快照清理失败不影响还原结果
      }

      // 更新元信息
      await _prefs.setInt(SettingsKeys.lastBackupAt, manifest.exportedAt);
      await _prefs.setInt(SettingsKeys.lastBackupSize, manifest.dbSize);
      batch(() {
        _readLastBackupMeta();
        status.value = BackupStatus.restoringDone;
      });
    } catch (e) {
      batch(() {
        errorMessage.value = AppErrorMapper.humanReadable(e);
        status.value = BackupStatus.error;
      });
    }
  }

  /// 将状态重置为 idle（关闭成功/错误提示），并重新刷新数据库统计。
  Future<void> dismissResult() async {
    batch(() {
      status.value = BackupStatus.idle;
      errorMessage.value = null;
    });
    await _refreshStats();
  }

  /// 判断上次备份是否超过 7 天，用于在界面上提示用户备份已过期。
  bool get isBackupStale {
    final at = lastBackupAt.value;
    if (at == null) return true;
    return DateTime.now().difference(at).inDays > 7;
  }

  /// 将数字补齐为两位字符串（如 3 → "03"），用于生成备份文件名中的日期段。
  String _pad(int n) => n.toString().padLeft(2, '0');

  /// 释放所有 signal 资源。
  void dispose() {
    status.dispose();
    errorMessage.dispose();
    lastBackupAt.dispose();
    currentStats.dispose();
  }
}
