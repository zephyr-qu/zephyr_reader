import 'package:injectable/injectable.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../data/sync_service.dart';

/// 同步视图模型
@injectable
class SyncViewModel {
  final SyncRepository _repo;

  /// 同步状态
  final syncStatus = signal<SyncStatus>(SyncStatus.idle);

  /// 待同步任务数
  final pendingTaskCount = signal<int>(0);

  /// 是否正在同步
  final isSyncing = signal<bool>(false);

  SyncViewModel(this._repo);

  /// 加载待同步任务
  Future<void> loadPendingTasks() async {
    final tasks = await _repo.getPendingTasks();
    pendingTaskCount.value = tasks.length;
  }

  /// 执行同步
  Future<void> sync() async {
    if (isSyncing.value) return;

    isSyncing.value = true;
    syncStatus.value = SyncStatus.syncing;

    try {
      final status = await _repo.sync();
      syncStatus.value = status;
      await loadPendingTasks();
    } catch (e) {
      syncStatus.value = SyncStatus.failed;
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
