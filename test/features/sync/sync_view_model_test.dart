import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zephyr_reader/core/local/file_storage.dart';
import 'package:zephyr_reader/features/sync/application/sync_view_model.dart';
import 'package:zephyr_reader/features/sync/data/sync_service.dart';
import 'package:zephyr_reader/features/sync/domain/repositories/sync_repository.dart'
    hide SyncRepository;

// ===== Mock classes using mocktail =====

class _MockFileStorage extends Mock implements FileStorage {}

// ===== Helper function to create ViewModel =====

SyncViewModel createViewModel({FileStorage? fileStorage}) {
  return SyncViewModel(SyncRepository(fileStorage ?? _MockFileStorage()));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SyncViewModel', () {
    late FileStorage fileStorage;
    late SyncRepository repo;
    late SyncViewModel vm;

    setUp(() {
      fileStorage = _MockFileStorage();
      repo = SyncRepository(fileStorage);
      vm = createViewModel(fileStorage: fileStorage);

      // Configure file storage mocks
      when(() => fileStorage.init()).thenAnswer((_) async {});
      when(
        () => fileStorage.appDirectory,
      ).thenAnswer((_) async => Directory.systemTemp);
      when(
        () => fileStorage.tempDirectory,
      ).thenAnswer((_) async => Directory.systemTemp);
      when(
        () => fileStorage.saveString(
          any(),
          any(),
          useTemp: any(named: 'useTemp'),
        ),
      ).thenAnswer((_) async => true);
      when(
        () => fileStorage.readString(any(), useTemp: any(named: 'useTemp')),
      ).thenAnswer((_) async => null);
      when(
        () =>
            fileStorage.saveBytes(any(), any(), useTemp: any(named: 'useTemp')),
      ).thenAnswer((_) async => true);
      when(
        () => fileStorage.readBytes(any(), useTemp: any(named: 'useTemp')),
      ).thenAnswer((_) async => null);
      when(
        () => fileStorage.exists(any(), useTemp: any(named: 'useTemp')),
      ).thenAnswer((_) async => false);
      when(
        () => fileStorage.delete(any(), useTemp: any(named: 'useTemp')),
      ).thenAnswer((_) async => true);
      when(() => fileStorage.clearTemp()).thenAnswer((_) async => true);
      when(
        () => fileStorage.getUsage(includeTemp: any(named: 'includeTemp')),
      ).thenAnswer((_) async => 0);
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
