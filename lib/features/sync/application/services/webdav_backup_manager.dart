import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/core/utils/logging.dart';

import 'sync_models.dart';

class WebdavBackupManager {
  final void Function(SyncEvent) emitEvent;
  final Signal<List<BackupInfo>> backups;
  final Future<File> Function(SyncDataType type) getLocalFile;
  final String backupDirName;

  WebdavBackupManager({
    required this.emitEvent,
    required this.backups,
    required this.getLocalFile,
    required this.backupDirName,
  });

  Future<BackupInfo> createBackup({
    List<SyncDataType>? dataTypes,
    String? note,
  }) async {
    final appDir = await getApplicationDocumentsDirectory();
    final backupDir = Directory(p.join(appDir.path, backupDirName));

    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }

    final timestamp = DateTime.now();
    final backupId = timestamp.millisecondsSinceEpoch.toString();
    final backupFileName =
        'backup_${timestamp.toIso8601String().replaceAll(':', '-')}.zip';
    final backupFilePath = p.join(backupDir.path, backupFileName);

    final includedTypes = dataTypes ?? SyncDataType.values;
    final backupData = <String, dynamic>{};

    for (final dataType in includedTypes) {
      final localFile = await getLocalFile(dataType);
      if (await localFile.exists()) {
        final content = await localFile.readAsString();
        backupData[dataType.filename] = content;
      }
    }

    final backupFile = File(backupFilePath);
    final backupContent = jsonEncode(backupData);
    await backupFile.writeAsString(backupContent, flush: true);

    final backupInfo = BackupInfo(
      id: backupId,
      timestamp: timestamp,
      filePath: backupFilePath,
      fileSize: await backupFile.length(),
      includedDataTypes: includedTypes.map((e) => e.name).toList(),
      note: note,
    );

    backups.value = [...backups.value, backupInfo];
    await _saveBackups();

    emitEvent(SyncEvent(type: SyncEventType.completed, message: '备份创建成功'));

    return backupInfo;
  }

  Future<bool> restoreBackup(BackupInfo backupInfo) async {
    try {
      final backupFile = File(backupInfo.filePath);
      if (!await backupFile.exists()) {
        throw Exception('备份文件不存在');
      }

      final content = await backupFile.readAsString();
      final backupData = jsonDecode(content) as Map<String, dynamic>;

      for (final entry in backupData.entries) {
        final dataType = SyncDataType.values.firstWhere(
          (e) => e.filename == entry.key,
          orElse: () => SyncDataType.settings,
        );

        final localFile = await getLocalFile(dataType);
        await localFile.parent.create(recursive: true);
        await localFile.writeAsString(entry.value as String, flush: true);
      }

      emitEvent(SyncEvent(type: SyncEventType.completed, message: '备份恢复成功'));

      return true;
    } catch (e) {
      Logging.error('恢复备份异常：$e');
      emitEvent(SyncEvent(type: SyncEventType.failed, message: '备份恢复失败：$e'));
      return false;
    }
  }

  Future<bool> deleteBackup(BackupInfo backupInfo) async {
    try {
      final backupFile = File(backupInfo.filePath);
      if (await backupFile.exists()) {
        await backupFile.delete();
      }

      backups.value = backups.value
          .where((b) => b.id != backupInfo.id)
          .toList();
      await _saveBackups();

      return true;
    } catch (e) {
      Logging.error('删除备份异常：$e');
      return false;
    }
  }

  List<BackupInfo> getBackups() {
    return backups.value;
  }

  Future<void> _saveBackups() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final backupListFile = File(
        p.join(appDir.path, backupDirName, 'backup_list.json'),
      );

      final jsonList = backups.value.map((info) => info.toJson()).toList();
      await backupListFile.writeAsString(jsonEncode(jsonList), flush: true);
    } catch (e) {
      Logging.error('保存备份列表失败：$e');
    }
  }
}
