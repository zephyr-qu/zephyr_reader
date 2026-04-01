/// 同步状态
enum SyncStatus {
  idle('空闲'),
  syncing('同步中'),
  success('同步成功'),
  failed('同步失败'),
  offline('离线');

  final String displayName;
  const SyncStatus(this.displayName);
}

/// 同步任务
class SyncTask {
  final String id;
  final String type;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  SyncStatus status;
  String? errorMessage;

  SyncTask({
    required this.id,
    required this.type,
    required this.data,
    required this.createdAt,
    this.status = SyncStatus.idle,
    this.errorMessage,
  });
}

/// 同步仓库接口
abstract class SyncRepository {
  /// 获取所有待同步任务
  Future<List<SyncTask>> getPendingTasks();

  /// 添加同步任务
  Future<void> addTask(SyncTask task);

  /// 执行同步
  Future<SyncStatus> sync();

  /// 清空已完成任务
  Future<void> clearCompleted();
}
