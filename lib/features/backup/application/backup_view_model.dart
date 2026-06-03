import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/core/settings/settings_keys.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:zephyr_reader/src/rust/api/backup.dart';

enum BackupStatus {
  idle,
  exporting,
  exportingDone,
  restoring,
  restoringDone,
  error,
}

@injectable
/// 本地备份 ViewModel
///
/// 状态机：
///   idle → exporting → exportingDone → idle
///   idle → restoring → restoringDone → idle
///   任意 → error → idle
class BackupViewModel {
  final SharedPreferences _prefs;

  // ============ Signals ============

  final status = signal(BackupStatus.idle);
  final errorMessage = signal<String?>(null);
  final lastBackupAt = signal<DateTime?>(null);
  final lastBackupSize = signal<int>(0);
  final currentStats = signal<BackupStats?>(null);
  final lastManifest = signal<BackupManifest?>(null);

  BackupViewModel(this._prefs);

  // ============ 初始化 ============

  Future<void> initialize() async {
    _readLastBackupMeta();
    await _refreshStats();
  }

  void _readLastBackupMeta() {
    final ts = _prefs.getInt(SettingsKeys.lastBackupAt);
    final size = _prefs.getInt(SettingsKeys.lastBackupSize);
    if (ts != null) {
      lastBackupAt.value = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
    }
    if (size != null) {
      lastBackupSize.value = size;
    }
  }

  Future<void> _refreshStats() async {
    try {
      currentStats.value = await getBackupStats();
    } catch (e) {
      // 静默失败，stats 为 null 时 UI 降级显示
    }
  }

  // ============ 操作 ============

  Future<void> performBackup() async {
    if (status.value != BackupStatus.idle) return;

    status.value = BackupStatus.exporting;
    errorMessage.value = null;

    try {
      // 1. 文件选择：用户选保存目录+文件名
      final now = DateTime.now();
      final suggestedName =
          'zephyr-backup-${now.year}${_pad(now.month)}${_pad(now.day)}-${_pad(now.hour)}${_pad(now.minute)}.db';

      final savePath = await FilePicker.saveFile(
        dialogTitle: '选择备份保存位置',
        fileName: suggestedName,
        type: FileType.custom,
        allowedExtensions: ['db'],
      );
      if (savePath == null) {
        status.value = BackupStatus.idle;
        return; // 用户取消
      }

      // 2. 调用 Rust 导出
      final manifest = await exportDatabase(destPath: savePath);

      // 3. 记录元信息
      await _prefs.setInt('last_backup_at', manifest.exportedAt);
      await _prefs.setInt('last_backup_size', manifest.dbSize);
      _readLastBackupMeta();
      lastManifest.value = manifest;

      status.value = BackupStatus.exportingDone;
    } catch (e) {
      errorMessage.value = e.toString();
      status.value = BackupStatus.error;
    }
  }

  Future<void> performRestore() async {
    if (status.value != BackupStatus.idle) return;

    status.value = BackupStatus.restoring;
    errorMessage.value = null;

    try {
      // 1. 文件选择：用户选备份文件
      final result = await FilePicker.pickFiles(
        dialogTitle: '选择备份文件',
        type: FileType.custom,
        allowedExtensions: ['db'],
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) {
        status.value = BackupStatus.idle;
        return; // 用户取消
      }
      final filePath = result.files.single.path;
      if (filePath == null) {
        errorMessage.value = '无法读取选择的文件路径';
        status.value = BackupStatus.error;
        return;
      }

      // 2. inspect 备份
      final manifest = await inspectBackup(backupPath: filePath);
      if (manifest == null) {
        errorMessage.value = '所选文件不是有效的 Zephyr Reader 备份文件';
        status.value = BackupStatus.error;
        return;
      }

      // 3. 用 RestoreConfirmDialog 确认（调用方处理）
      //    如果用户确认，执行 restore
      status.value = BackupStatus.restoring;
      await restoreDatabase(backupPath: filePath);

      // 4. 更新元信息
      await _prefs.setInt('last_backup_at', manifest.exportedAt);
      await _prefs.setInt('last_backup_size', manifest.dbSize);
      _readLastBackupMeta();
      lastManifest.value = manifest;

      status.value = BackupStatus.restoringDone;
    } catch (e) {
      errorMessage.value = e.toString();
      status.value = BackupStatus.error;
    }
  }

  Future<void> dismissResult() async {
    status.value = BackupStatus.idle;
    lastManifest.value = null;
    errorMessage.value = null;
    await _refreshStats();
  }

  String? lastBackupTimeAgo(AppLocalizations l10n) {
    final at = lastBackupAt.value;
    if (at == null) return null;
    final diff = DateTime.now().difference(at);
    if (diff.inDays > 0) return '$diff.inDays days ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}min ago';
    return 'just now';
  }

  bool get isBackupStale {
    final at = lastBackupAt.value;
    if (at == null) return true;
    return DateTime.now().difference(at).inDays > 7;
  }

  String _pad(int n) => n.toString().padLeft(2, '0');
}
