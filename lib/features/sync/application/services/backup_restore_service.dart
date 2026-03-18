/// 备份恢复服务
///
/// 提供数据备份和恢复功
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
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
}

/// 备份恢复服务
class BackupRestoreService {
  final backups = signal<List<BackupInfo>>([]);
  final isBackingUp = signal(false);
  final isRestoring = signal(false);

  BackupRestoreService() {
    _loadBackups();
  }

  static const String _backupDir = 'zephyr_reader/backups';

  Future<void> _loadBackups() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${dir.path}/$_backupDir');

      if (!await backupDir.exists()) {
        backups.value = [];
        return;
      }

      final files = backupDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList();

      final backupList = <BackupInfo>[];
      for (final file in files) {
        final stats = await file.stat();
        final fileName = file.path.split('/').last;
        final timestamp = fileName.replaceAll('.json', '').split('_').last;

        backupList.add(
          BackupInfo(
            id: fileName.replaceAll('.json', ''),
            createdAt: DateTime.parse(timestamp),
            fileSize: stats.size,
            types: [BackupType.all],
          ),
        );
      }

      backupList.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      backups.value = backupList;
    } catch (e) {
      debugPrint('加载备份列表失败e');
      backups.value = [];
    }
  }

  Future<BackupInfo?> createBackup({
    List<BackupType> types = const [BackupType.all],
    String? note,
  }) async {
    isBackingUp.value = true;

    try {
      final dir = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${dir.path}/$_backupDir');

      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      final timestamp = DateTime.now().toIso8601String();
      final fileName = 'backup_$timestamp.json';
      final filePath = '${backupDir.path}/$fileName';

      final backupData = <String, dynamic>{};

      if (types.contains(BackupType.all) ||
          types.contains(BackupType.readingProgress)) {
        backupData['readingProgress'] = await _backupReadingProgress();
      }

      if (types.contains(BackupType.all) ||
          types.contains(BackupType.bookmarks)) {
        backupData['bookmarks'] = await _backupBookmarks();
      }

      if (types.contains(BackupType.all) ||
          types.contains(BackupType.bookshelf)) {
        backupData['bookshelf'] = await _backupBookshelf();
      }

      if (types.contains(BackupType.all) ||
          types.contains(BackupType.settings)) {
        backupData['settings'] = await _backupSettings();
      }

      final file = File(filePath);
      await file.writeAsString(jsonEncode(backupData));

      final stats = await file.stat();
      final backupInfo = BackupInfo(
        id: fileName.replaceAll('.json', ''),
        createdAt: DateTime.now(),
        fileSize: stats.size,
        types: types,
        note: note,
      );

      await _loadBackups();
      debugPrint('备份创建成功fileName');

      return backupInfo;
    } catch (e) {
      debugPrint('创建备份失败e');
      return null;
    } finally {
      isBackingUp.value = false;
    }
  }

  Future<bool> restoreBackup(String backupId) async {
    isRestoring.value = true;

    try {
      final dir = await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}/$_backupDir/$backupId.json';
      final file = File(filePath);

      if (!await file.exists()) {
        debugPrint('备份文件不存在：$backupId');
        return false;
      }

      final content = await file.readAsString();
      final backupData = jsonDecode(content) as Map<String, dynamic>;

      if (backupData.containsKey('readingProgress')) {
        await _restoreReadingProgress(backupData['readingProgress']);
      }

      if (backupData.containsKey('bookmarks')) {
        await _restoreBookmarks(backupData['bookmarks']);
      }

      if (backupData.containsKey('bookshelf')) {
        await _restoreBookshelf(backupData['bookshelf']);
      }

      if (backupData.containsKey('settings')) {
        await _restoreSettings(backupData['settings']);
      }

      debugPrint('备份恢复成功backupId');
      return true;
    } catch (e) {
      debugPrint('备份恢复失败e');
      return false;
    } finally {
      isRestoring.value = false;
    }
  }

  Future<bool> deleteBackup(String backupId) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}/$_backupDir/$backupId.json';
      final file = File(filePath);

      if (await file.exists()) {
        await file.delete();
        await _loadBackups();
        debugPrint('备份删除成功backupId');
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('备份删除失败e');
      return false;
    }
  }

  Future<String?> exportBackup(String backupId) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final sourcePath = '${dir.path}/$_backupDir/$backupId.json';

      final downloadDir = await getDownloadsDirectory();
      if (downloadDir == null) {
        return null;
      }

      final destPath = '${downloadDir.path}/zephyr_reader_$backupId.json';
      final sourceFile = File(sourcePath);
      await sourceFile.copy(destPath);

      debugPrint('备份导出成功destPath');
      return destPath;
    } catch (e) {
      debugPrint('备份导出失败e');
      return null;
    }
  }

  Future<bool> importBackup(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return false;
      }

      final dir = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${dir.path}/$_backupDir');

      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      final fileName = filePath.split('/').last;
      final destPath = '${backupDir.path}/$fileName';
      await file.copy(destPath);

      await _loadBackups();
      debugPrint('备份导入成功fileName');
      return true;
    } catch (e) {
      debugPrint('备份导入失败e');
      return false;
    }
  }

  Future<bool> autoBackup() async {
    if (backups.value.isEmpty) {
      return await createBackup() != null;
    }

    final lastBackup = backups.value.first;
    final now = DateTime.now();
    final diff = now.difference(lastBackup.createdAt);

    if (diff.inHours > 24) {
      return await createBackup() != null;
    }

    return true;
  }

  Future<Map<String, dynamic>> _backupReadingProgress() async => {};
  Future<Map<String, dynamic>> _backupBookmarks() async => {};
  Future<Map<String, dynamic>> _backupBookshelf() async => {};
  Future<Map<String, dynamic>> _backupSettings() async => {};

  Future<void> _restoreReadingProgress(Map<String, dynamic> data) async {}
  Future<void> _restoreBookmarks(Map<String, dynamic> data) async {}
  Future<void> _restoreBookshelf(Map<String, dynamic> data) async {}
  Future<void> _restoreSettings(Map<String, dynamic> data) async {}
}
