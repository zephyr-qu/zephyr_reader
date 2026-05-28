import 'dart:convert';

import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/core/local/file_storage.dart';
import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/features/sync/domain/repositories/sync_repository.dart'
    as domain;

/// 同步服务实现
@LazySingleton(as: domain.SyncRepository)
class SyncRepository implements domain.SyncRepository {
  final FileStorage _fileStorage;

  static const String _syncQueueFile = 'sync_queue.json';

  SyncRepository(this._fileStorage);

  @override
  Future<List<domain.SyncTask>> getPendingTasks() async {
    try {
      final content = await _fileStorage.readString(_syncQueueFile);
      if (content == null) return [];

      final List<dynamic> json = jsonDecode(content) as List<dynamic>;
      return json
          .map(
            (item) => domain.SyncTask(
              id: item['id'] as String,
              type: item['type'] as String,
              data: Map<String, dynamic>.from(item['data'] as Map),
              createdAt: DateTime.parse(item['createdAt'] as String),
              status: domain.SyncQueueStatus.values.firstWhere(
                (s) => s.name == item['status'],
                orElse: () => domain.SyncQueueStatus.idle,
              ),
              errorMessage: item['errorMessage'] as String?,
            ),
          )
          .toList();
    } catch (e) {
      Logging.error('Failed to load sync queue: $e');
      return [];
    }
  }

  @override
  Future<void> addTask(domain.SyncTask task) async {
    final tasks = await getPendingTasks();
    tasks.add(task);
    await _saveTasks(tasks);
  }

  @override
  Future<domain.SyncQueueStatus> sync() async {
    final tasks = await getPendingTasks();
    if (tasks.isEmpty) {
      return domain.SyncQueueStatus.idle;
    }

    var hasError = false;

    for (var task in tasks) {
      task.status = domain.SyncQueueStatus.syncing;
      await _saveTasks(tasks);

      try {
        await _executeSyncTask(task);
        task.status = domain.SyncQueueStatus.success;
      } catch (e, stackTrace) {
        hasError = true;
        task.status = domain.SyncQueueStatus.failed;
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

    return hasError
        ? domain.SyncQueueStatus.failed
        : domain.SyncQueueStatus.success;
  }

  /// 执行单个同步任务
  Future<void> _executeSyncTask(domain.SyncTask task) async {
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
  Future<void> _syncBookshelf(domain.SyncTask task) async {
    // 从任务数据中获取书籍信息
    final books = task.data['books'] as List?;
    if (books == null || books.isEmpty) return;

    // 这里应该调用书架服务来更新本地数据库
    // 由于依赖注入循环问题，这里使用事件总线或者回调机制
    // 暂时将数据保存到文件存储
    await _fileStorage.saveString('sync_bookshelf.json', jsonEncode(books));
  }

  /// 同步阅读进度
  Future<void> _syncReadingProgress(domain.SyncTask task) async {
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
  Future<void> _syncBookmark(domain.SyncTask task) async {
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
  Future<void> _syncSettings(domain.SyncTask task) async {
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

  @override
  Future<void> clearCompleted() async {
    final tasks = await getPendingTasks();
    final pending = tasks
        .where(
          (task) =>
              task.status == domain.SyncQueueStatus.idle ||
              task.status == domain.SyncQueueStatus.failed,
        )
        .toList();
    await _saveTasks(pending);
  }

  Future<void> _saveTasks(List<domain.SyncTask> tasks) async {
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
