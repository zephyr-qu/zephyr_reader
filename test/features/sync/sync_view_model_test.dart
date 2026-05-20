library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/core/local/file_storage.dart';
import 'package:zephyr_reader/features/sync/application/sync_view_model.dart';
import 'package:zephyr_reader/features/sync/data/sync_service.dart';

class _MockFileStorage implements FileStorage {
  String? storedContent;

  @override
  Future<void> init() async {}

  @override
  Future<Directory> get appDirectory async => Directory.systemTemp;

  @override
  Future<Directory> get tempDirectory async => Directory.systemTemp;

  @override
  Future<bool> saveString(
    String filename,
    String content, {
    bool useTemp = false,
  }) async {
    storedContent = content;
    return true;
  }

  @override
  Future<String?> readString(String filename, {bool useTemp = false}) async =>
      storedContent;

  @override
  Future<bool> saveBytes(
    String filename,
    Uint8List bytes, {
    bool useTemp = false,
  }) async => true;

  @override
  Future<Uint8List?> readBytes(String filename, {bool useTemp = false}) async =>
      null;

  @override
  Future<bool> exists(String filename, {bool useTemp = false}) async =>
      storedContent != null;

  @override
  Future<bool> delete(String filename, {bool useTemp = false}) async {
    storedContent = null;
    return true;
  }

  @override
  Future<bool> clearTemp() async => true;

  @override
  Future<int> getUsage({bool includeTemp = false}) async => 0;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SyncViewModel', () {
    late _MockFileStorage fileStorage;
    late SyncRepository repo;
    late SyncViewModel vm;

    setUp(() {
      fileStorage = _MockFileStorage();
      repo = SyncRepository(fileStorage);
      vm = SyncViewModel(repo);
    });

    group('同步任务管理', () {
      test('初始状态应为空闲', () {
        expect(vm.syncStatus.value, equals(SyncQueueStatus.idle));
        expect(vm.pendingTaskCount.value, equals(0));
        expect(vm.isSyncing.value, isFalse);
      });

      test('loadPendingTasks 应加载任务数量', () async {
        await repo.addTask(
          SyncTask(
            id: 'task_1',
            type: 'bookshelf',
            data: {'books': []},
            createdAt: DateTime.now(),
          ),
        );

        await vm.loadPendingTasks();

        expect(vm.pendingTaskCount.value, equals(1));
      });

      test('sync 应处理所有待处理任务', () async {
        await repo.addTask(
          SyncTask(
            id: 'task_1',
            type: 'bookshelf',
            data: {'books': []},
            createdAt: DateTime.now(),
          ),
        );

        await vm.sync();

        expect(vm.pendingTaskCount.value, equals(0));
        expect(vm.isSyncing.value, isFalse);
      });

      test('sync 在无任务时应返回空闲', () async {
        await vm.sync();

        expect(vm.syncStatus.value, equals(SyncQueueStatus.idle));
      });

      test('sync 在同步中时不应重复执行', () async {
        vm.isSyncing.value = true;
        await vm.sync();
      });

      test('clearCompleted 应清空已完成任务', () async {
        await repo.addTask(
          SyncTask(
            id: 'task_1',
            type: 'bookshelf',
            data: {'books': []},
            createdAt: DateTime.now(),
          ),
        );
        await vm.loadPendingTasks();
        expect(vm.pendingTaskCount.value, equals(1));

        await vm.sync();
        await vm.clearCompleted();

        expect(vm.pendingTaskCount.value, equals(0));
      });

      test('失败任务应保持待处理状态不被 clearCompleted 清空', () async {
        final task = SyncTask(
          id: 'task_1',
          type: 'unknown_type',
          data: {},
          createdAt: DateTime.now(),
        );
        await repo.addTask(task);

        await vm.sync();

        expect(vm.syncStatus.value, equals(SyncQueueStatus.failed));
      });
    });
  });
}
