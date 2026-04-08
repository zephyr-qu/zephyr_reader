/// 备份服务类型定义
///
/// 注意：实际备份/恢复功能需要通过 Rust API 实现
/// 此文件仅提供类型定义以保持 UI 编译通过
library;

import 'package:signals_flutter/signals_flutter.dart';

/// 备份数据类型
enum BackupType { readingProgress, bookmarks, bookshelf, settings, all }

/// 备份信息
class BackupInfo {
  final String id;
  final DateTime createdAt;
  final int fileSize;
  final List<BackupType> types;
  final String? note;

  BackupInfo({
    required this.id,
    required this.createdAt,
    required this.fileSize,
    required this.types,
    this.note,
  });

  /// 格式化文件大小
  String get fileSizeFormatted {
    if (fileSize < 1024) {
      return '$fileSize B';
    } else if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(2)} KB';
    } else {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
  }

  /// 格式化创建时间
  String get createdAtFormatted {
    return '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')} '
        '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
  }
}

/// 备份恢复服务 (Stub - 待 Rust API 实现)
class BackupRestoreService {
  final backups = signal<List<BackupInfo>>([]);
  final isBackingUp = signal(false);
  final isRestoring = signal(false);

  BackupRestoreService() {
    _loadBackups();
  }

  Future<void> _loadBackups() async {
    // TODO: 通过 Rust API 加载备份列表
    backups.value = [];
  }

  Future<BackupInfo?> createBackup({
    required List<BackupType> types,
    String? note,
  }) async {
    // TODO: 通过 Rust API 创建备份
    return null;
  }

  Future<bool> restoreBackup(BackupInfo backup) async {
    // TODO: 通过 Rust API 恢复备份
    return false;
  }

  Future<bool> deleteBackup(BackupInfo backup) async {
    // TODO: 通过 Rust API 删除备份
    return false;
  }
}
