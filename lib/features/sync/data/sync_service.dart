import 'dart:convert';

import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/core/local/file_storage.dart';
import 'package:zephyr_reader/core/utils/logging.dart';

/// 同步队列状态
enum SyncQueueStatus {
  idle('空闲'),
  syncing('同步中'),
  success('同步成功'),
  failed('同步失败'),
  offline('离线');

  final String displayName;
  const SyncQueueStatus(this.displayName);
}

/// 同步任务
class SyncTask {
  final String id;
  final String type;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  SyncQueueStatus status;
  String? errorMessage;

  SyncTask({
    required this.id,
    required this.type,
    required this.data,
    required this.createdAt,
    this.status = SyncQueueStatus.idle,
    this.errorMessage,
  });
}

/// 同步服务实现
@LazySingleton()
class SyncRepository {
  final FileStorage _fileStorage;

  static const String _syncQueueFile = 'sync_queue.json';

  SyncRepository(this._fileStorage);

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
              status: SyncQueueStatus.values.firstWhere(
                (s) => s.name == item['status'],
                orElse: () => SyncQueueStatus.idle,
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

  Future<void> addTask(SyncTask task) async {
    final tasks = await getPendingTasks();
    tasks.add(task);
    await _saveTasks(tasks);
  }

  Future<SyncQueueStatus> sync() async {
    final tasks = await getPendingTasks();
    if (tasks.isEmpty) {
      return SyncQueueStatus.idle;
    }

    var hasError = false;

    for (var task in tasks) {
      task.status = SyncQueueStatus.syncing;
      await _saveTasks(tasks);

      try {
        await _executeSyncTask(task);
        task.status = SyncQueueStatus.success;
      } catch (e, stackTrace) {
        hasError = true;
        task.status = SyncQueueStatus.failed;
        task.errorMessage = e.toString();
        Logging.error(
          'Sync task failed: ${task.type}',
          exception: e,
          stackTrace: stackTrace,
        );
      }

      await _saveTasks(tasks);
    }

    await clearCompleted();

    return hasError ? SyncQueueStatus.failed : SyncQueueStatus.success;
  }

  /// 执行单个同步任务
  Future<void> _executeSyncTask(SyncTask task) async {
    switch (task.type) {
      case 'bookshelf':
        await _syncBookshelf(task);
        break;
      case 'reading_progress':
        await _syncReadingProgress(task);
        break;
      case 'bookmark':
        await _syncBookmark(task);
        break;
      case 'settings':
        await _syncSettings(task);
        break;
      default:
        throw Exception('未知的同步任务类型：${task.type}');
    }
  }

  /// 同步书架数据
  Future<void> _syncBookshelf(SyncTask task) async {
    // 从任务数据中获取书籍信息
    final books = task.data['books'] as List?;
    if (books == null || books.isEmpty) return;

    // 这里应该调用书架服务来更新本地数据库
    // 由于依赖注入循环问题，这里使用事件总线或者回调机制
    // 暂时将数据保存到文件存储
    await _fileStorage.saveString('sync_bookshelf.json', jsonEncode(books));
  }

  /// 同步阅读进度
  Future<void> _syncReadingProgress(SyncTask task) async {
    final bookId = task.data['bookId'] as String?;
    final progress = task.data['progress'] as Map?;

    if (bookId == null || progress == null) return;

    // 保存进度数据
    await _fileStorage.saveString(
      'sync_progress_$bookId.json',
      jsonEncode({
        'bookId': bookId,
        'progress': progress,
        'syncedAt': DateTime.now().toIso8601String(),
      }),
    );
  }

  /// 同步书签
  Future<void> _syncBookmark(SyncTask task) async {
    final bookId = task.data['bookId'] as String?;
    final bookmarks = task.data['bookmarks'] as List?;

    if (bookId == null || bookmarks == null) return;

    // 保存书签数据
    await _fileStorage.saveString(
      'sync_bookmarks_$bookId.json',
      jsonEncode({
        'bookId': bookId,
        'bookmarks': bookmarks,
        'syncedAt': DateTime.now().toIso8601String(),
      }),
    );
  }

  /// 同步设置
  Future<void> _syncSettings(SyncTask task) async {
    final settings = task.data['settings'] as Map?;
    if (settings == null) return;

    // 保存设置数据
    await _fileStorage.saveString(
      'sync_settings.json',
      jsonEncode({
        'settings': settings,
        'syncedAt': DateTime.now().toIso8601String(),
      }),
    );
  }

  Future<void> clearCompleted() async {
    final tasks = await getPendingTasks();
    final pending = tasks
        .where(
          (task) =>
              task.status == SyncQueueStatus.idle ||
              task.status == SyncQueueStatus.failed,
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
