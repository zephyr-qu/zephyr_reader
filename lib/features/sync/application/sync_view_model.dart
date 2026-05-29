import 'package:signals_flutter/signals_flutter.dart';

import '../domain/repositories/sync_repository.dart';

/// 同步视图模型
class SyncViewModel {
  final SyncRepository _repo;

  final syncStatus = signal<SyncQueueStatus>(SyncQueueStatus.idle);
  final pendingTaskCount = signal<int>(0);
  final isSyncing = signal<bool>(false);

  SyncViewModel(this._repo);

  Future<void> loadPendingTasks() async {
    final tasks = await _repo.getPendingTasks();
    pendingTaskCount.value = tasks.length;
  }

  Future<void> sync() async {
    if (isSyncing.value) return;

    isSyncing.value = true;
    syncStatus.value = SyncQueueStatus.syncing;

    try {
      final status = await _repo.sync();
      syncStatus.value = status;
      await loadPendingTasks();
    } catch (e) {
      syncStatus.value = SyncQueueStatus.failed;
    } finally {
      isSyncing.value = false;
    }
  }

  /// 清空已完成任务
  Future<void> clearCompleted() async {
    await _repo.clearCompleted();
    await loadPendingTasks();
  }
}
