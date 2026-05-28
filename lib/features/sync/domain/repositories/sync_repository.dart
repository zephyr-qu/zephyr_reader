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

abstract class SyncRepository {
  Future<List<SyncTask>> getPendingTasks();
  Future<void> addTask(SyncTask task);
  Future<SyncQueueStatus> sync();
  Future<void> clearCompleted();
}
