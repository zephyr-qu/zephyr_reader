import 'dart:convert';

import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/core/local/file_storage.dart';
import 'package:zephyr_reader/shared/utils/logging.dart';

import '../domain/sync_repository.dart';

/// 同步服务实现
@LazySingleton(as: SyncRepository)
class SyncService implements SyncRepository {
  final FileStorage _fileStorage;

  static const String _syncQueueFile = 'sync_queue.json';

  SyncService(this._fileStorage);

  @override
  Future<List<SyncTask>> getPendingTasks() async {
    try {
      final content = await _fileStorage.readString(_syncQueueFile);
      if (content == null) return [];

      final List<dynamic> json = jsonDecode(content);
      return json
          .map(
            (item) => SyncTask(
              id: item['id'],
              type: item['type'],
              data: Map<String, dynamic>.from(item['data']),
              createdAt: DateTime.parse(item['createdAt']),
              status: SyncStatus.values.firstWhere(
                (s) => s.name == item['status'],
                orElse: () => SyncStatus.idle,
              ),
              errorMessage: item['errorMessage'],
            ),
          )
          .toList();
    } catch (e) {
      Logging.error('Failed to load sync queue: $e');
      return [];
    }
  }

  @override
  Future<void> addTask(SyncTask task) async {
    final tasks = await getPendingTasks();
    tasks.add(task);
    await _saveTasks(tasks);
  }

  @override
  Future<SyncStatus> sync() async {
    final tasks = await getPendingTasks();
    if (tasks.isEmpty) {
      return SyncStatus.idle;
    }

    // TODO: 实现实际的同步逻辑
    // 这里只是示例，实际需要对接云同步服务

    for (var task in tasks) {
      task.status = SyncStatus.syncing;
      await _saveTasks(tasks);

      try {
        // 模拟同步过程
        await Future.delayed(const Duration(milliseconds: 500));

        // 标记为成功
        task.status = SyncStatus.success;
      } catch (e) {
        task.status = SyncStatus.failed;
        task.errorMessage = e.toString();
      }

      await _saveTasks(tasks);
    }

    return SyncStatus.success;
  }

  @override
  Future<void> clearCompleted() async {
    final tasks = await getPendingTasks();
    final pending = tasks
        .where(
          (task) =>
              task.status == SyncStatus.idle ||
              task.status == SyncStatus.failed,
        )
        .toList();
    await _saveTasks(pending);
  }

  Future<void> _saveTasks(List<SyncTask> tasks) async {
    final json = tasks
        .map(
          (task) => {
            'id': task.id,
            'type': task.type,
            'data': task.data,
            'createdAt': task.createdAt.toIso8601String(),
            'status': task.status.name,
            'errorMessage': task.errorMessage,
          },
        )
        .toList();

    await _fileStorage.saveString(_syncQueueFile, jsonEncode(json));
  }
}
