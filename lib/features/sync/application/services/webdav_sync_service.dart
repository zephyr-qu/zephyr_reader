library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:get_it/get_it.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals_flutter/signals_flutter.dart';

import 'package:zephyr_reader/core/utils/logging.dart';

import 'sync_exceptions.dart';
import 'sync_models.dart';
import 'webdav_client_service.dart';
import 'webdav_config_service.dart';
import 'webdav_connection_manager.dart';
import 'webdav_backup_manager.dart';
import 'webdav_conflict_resolver.dart';
import 'webdav_auto_sync_service.dart';

class WebDavSyncService {
  WebDavConfig? _config;
  WebdavConnectionManager? _connectionManagerParam;

  WebdavConnectionManager get _connectionManager =>
      _connectionManagerParam ??= WebdavConnectionManager(
        configService: WebDavConfigService(prefs: GetIt.I<SharedPreferences>()),
      );

  late final WebdavConflictResolver _conflictResolver;
  late final WebdavBackupManager _backupManager;
  late final WebdavAutoSyncService _autoSyncService;
  WebDavClientService? _client;
  CancelToken? _cancelToken;

  final _eventController = StreamController<SyncEvent>.broadcast();
  Stream<SyncEvent> get eventStream => _eventController.stream;

  final syncStatus = signal<SyncStatus>(SyncStatus.idle);
  final syncProgress = signal<double>(0.0);
  final lastSyncTime = signal<DateTime?>(null);
  final errorMessage = signal<String?>(null);
  final syncMessage = signal<String>('');
  final currentUploadProgress = signal<double>(0.0);
  final currentDownloadProgress = signal<double>(0.0);

  final conflicts = signal<List<ConflictInfo>>([]);
  final syncHistory = signal<List<SyncHistoryRecord>>([]);
  final backups = signal<List<BackupInfo>>([]);
  final autoSyncConfig = signal<AutoSyncConfig>(AutoSyncConfig());

  final int maxRetries;
  final Duration retryDelay;

  static const String _dataDirName = 'data';
  static const String _syncSubDirName = 'zephyr_reader';
  static const String _backupDirName = 'backups';
  static const String _historyFile = 'sync_history.json';
  static const String _incrementalFile = 'sync_incremental.json';
  static const int _maxHistoryRecords = 50;

  WebDavSyncService({
    WebDavConfig? config,
    WebdavConnectionManager? connectionManager,
    this.maxRetries = 3,
    this.retryDelay = const Duration(seconds: 2),
  }) : _connectionManagerParam = connectionManager {
    if (config != null) {
      setConfig(config);
    }
    _conflictResolver = WebdavConflictResolver(
      getClient: () => _client!,
      getRemotePath: () => '',
      emitEvent: _emitEvent,
      conflicts: conflicts,
      uploadFile: _uploadFile,
      downloadFile: _downloadFile,
      getFileInfo: _getFileInfo,
      fileExists: _fileExists,
    );
    _backupManager = WebdavBackupManager(
      emitEvent: _emitEvent,
      backups: backups,
      getLocalFile: _getLocalFile,
      backupDirName: _backupDirName,
    );
    _autoSyncService = WebdavAutoSyncService(
      config: autoSyncConfig,
      onSync: (direction) => syncIncremental(direction: direction),
      emitEvent: _emitEvent,
    );
    _loadHistory();
  }

  void setConfig(WebDavConfig config) {
    _config = config;
    _connectionManager.invalidate();
  }

  WebDavConfig? get config => _config;

  void _emitEvent(SyncEvent event) {
    if (!_eventController.isClosed) {
      _eventController.add(event);
    }
  }

  Future<SyncResult> syncAll({
    SyncDirection direction = SyncDirection.both,
    bool enableIncrementalSync = true,
    bool autoResolveConflicts = false,
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    if (_config == null || !_config!.isValid) {
      return SyncResult(success: false, error: 'WebDAV 配置未设置');
    }

    _cancelToken = cancelToken ?? CancelToken();
    syncStatus.value = SyncStatus.syncing;
    syncProgress.value = 0.0;
    currentUploadProgress.value = 0.0;
    currentDownloadProgress.value = 0.0;
    syncMessage.value = '开始同步...';
    errorMessage.value = null;
    conflicts.value = [];

    _emitEvent(SyncEvent(type: SyncEventType.started, message: '开始同步所有数据'));

    final result = SyncResult();
    var retryCount = 0;

    try {
      _client = await _connectionManager.getConnectedClient();

      syncMessage.value = '检查远程目录...';
      await _ensureRemoteDirectory();
      syncProgress.value = 5.0;

      final dataTypes = SyncDataType.values;
      final totalSteps = dataTypes.length;
      var completedSteps = 0;

      for (final dataType in dataTypes) {
        if (_cancelToken!.isCancelled) {
          _emitEvent(
            SyncEvent(type: SyncEventType.cancelled, message: '同步已取消'),
          );
          throw WebDavSyncCancelledException();
        }

        syncMessage.value = '同步${dataType.displayName}...';

        try {
          final opResult = await _syncDataTypeWithConflictHandling(
            dataType,
            direction,
            enableIncrementalSync: enableIncrementalSync,
            autoResolveConflicts: autoResolveConflicts,
            onProgress: (progress) {
              final baseProgress = 5 + (completedSteps / totalSteps) * 90;
              final stepProgress = (progress / 100) * (90 / totalSteps);
              syncProgress.value = baseProgress + stepProgress;
              onProgress?.call(syncProgress.value / 100);

              _emitEvent(
                SyncEvent(
                  type: SyncEventType.progress,
                  message:
                      '同步${dataType.displayName}: ${progress.toStringAsFixed(0)}%',
                  dataType: dataType,
                  progress: progress.toInt(),
                  total: 100,
                ),
              );
            },
          );

          if (opResult.success) {
            if (direction == SyncDirection.upload ||
                direction == SyncDirection.both) {
              result.uploadedCount++;
            }
            if (direction == SyncDirection.download ||
                direction == SyncDirection.both) {
              result.downloadedCount++;
            }
          } else {
            result.error = opResult.error;
          }
        } catch (e) {
          if (retryCount < maxRetries) {
            retryCount++;
            Logging.debug('同步${dataType.displayName}失败，第 $retryCount 次重试...');
            _emitEvent(
              SyncEvent(
                type: SyncEventType.recovered,
                message: '同步失败，正在重试 ($retryCount/$maxRetries)',
                dataType: dataType,
              ),
            );

            await Future<void>.delayed(retryDelay * retryCount);
            try {
              final opResult = await _syncDataTypeWithConflictHandling(
                dataType,
                direction,
                enableIncrementalSync: enableIncrementalSync,
                autoResolveConflicts: autoResolveConflicts,
              );

              if (opResult.success) {
                if (direction == SyncDirection.upload ||
                    direction == SyncDirection.both) {
                  result.uploadedCount++;
                }
                if (direction == SyncDirection.download ||
                    direction == SyncDirection.both) {
                  result.downloadedCount++;
                }
              }
            } catch (retryError) {
              result.conflictCount++;
              Logging.error('重试失败：$retryError');
            }
          } else {
            result.conflictCount++;
            Logging.error('同步${dataType.displayName}失败，已达最大重试次数');
          }
        }

        completedSteps++;
      }

      syncProgress.value = 100.0;
      syncStatus.value = SyncStatus.success;
      lastSyncTime.value = DateTime.now();
      syncMessage.value = '同步完成';

      _emitEvent(
        SyncEvent(type: SyncEventType.completed, message: result.summary),
      );

      result.success = result.conflictCount == 0 && result.error == null;
      return result;
    } catch (e) {
      debugPrint('同步异常：$e');
      syncStatus.value = SyncStatus.failed;
      errorMessage.value = '同步异常：$e';
      syncMessage.value = '同步失败';

      _emitEvent(SyncEvent(type: SyncEventType.failed, message: '同步失败：$e'));

      return SyncResult(success: false, error: e.toString());
    }
  }

  Future<SyncOperationResult> _syncDataTypeWithConflictHandling(
    SyncDataType type,
    SyncDirection direction, {
    bool enableIncrementalSync = true,
    bool autoResolveConflicts = false,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final localFile = File(p.join(appDir.path, _dataDirName, type.filename));
      final remotePath = p.join(
        _config!.remotePath,
        _syncSubDirName,
        type.filename,
      );

      final localExists = await localFile.exists();
      final remoteExists = await _fileExists(remotePath);

      if (localExists && remoteExists && direction == SyncDirection.both) {
        final conflictInfo = await _conflictResolver.checkConflict(
          localFile,
          remotePath,
          type,
        );

        if (conflictInfo != null) {
          if (autoResolveConflicts && conflictInfo.autoResolution != null) {
            _emitEvent(
              SyncEvent(
                type: SyncEventType.conflictResolved,
                message: '自动解决冲突：${type.name}',
                dataType: type,
                conflictInfo: conflictInfo,
              ),
            );

            return await _conflictResolver.resolveConflict(
              type,
              conflictInfo.autoResolution!,
              localFile,
              remotePath,
              onProgress: onProgress,
            );
          } else {
            conflicts.value = [...conflicts.value, conflictInfo];

            _emitEvent(
              SyncEvent(
                type: SyncEventType.conflict,
                message: '检测到冲突：${type.name}',
                dataType: type,
                conflictInfo: conflictInfo,
              ),
            );

            return SyncOperationResult.failure('检测到冲突，需要手动解决');
          }
        }
      }

      return await _syncDataType(
        type,
        direction,
        localFile,
        remotePath,
        enableIncrementalSync: enableIncrementalSync,
        onProgress: onProgress,
      );
    } catch (e) {
      debugPrint('同步数据类型 ${type.name} 异常：$e');
      return SyncOperationResult.failure(e.toString());
    }
  }

  Future<SyncOperationResult> _syncDataType(
    SyncDataType type,
    SyncDirection direction,
    File localFile,
    String remotePath, {
    bool enableIncrementalSync = true,
    void Function(double progress)? onProgress,
  }) async {
    try {
      if (direction == SyncDirection.upload ||
          direction == SyncDirection.both) {
        if (await localFile.exists()) {
          final uploaded = await _uploadFile(
            localFile: localFile,
            remotePath: remotePath,
            onProgress: (progress) {
              onProgress?.call(progress * 0.5);
            },
          );
          if (!uploaded) {
            return SyncOperationResult.failure('上传失败');
          }
        }
      }

      if (direction == SyncDirection.download ||
          direction == SyncDirection.both) {
        final downloaded = await _downloadFile(
          remotePath: remotePath,
          localFile: localFile,
          onProgress: (progress) {
            onProgress?.call(progress * 0.5);
          },
        );
        if (!downloaded && direction == SyncDirection.download) {
          return SyncOperationResult.failure('下载失败');
        }
      }

      return SyncOperationResult.success();
    } catch (e) {
      debugPrint('同步数据类型 ${type.name} 异常：$e');
      return SyncOperationResult.failure(e.toString());
    }
  }

  Future<SyncResult> syncIncremental({
    SyncDirection direction = SyncDirection.both,
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    if (_config == null || !_config!.isValid) {
      return SyncResult(success: false, error: 'WebDAV 配置未设置');
    }

    _cancelToken = cancelToken ?? CancelToken();
    syncStatus.value = SyncStatus.syncing;
    syncProgress.value = 0.0;
    syncMessage.value = '开始增量同步...';
    errorMessage.value = null;

    final startTime = DateTime.now();
    final result = SyncResult();
    final changedFiles = <String>[];
    var uploadedBytes = 0;
    var downloadedBytes = 0;

    _emitEvent(SyncEvent(type: SyncEventType.started, message: '开始增量同步'));

    try {
      _client = await _connectionManager.getConnectedClient();
      await _ensureRemoteDirectory();
      syncProgress.value = 5.0;

      final localChanges = await _loadIncrementalChanges();
      final remoteFiles = await _listRemoteFiles();

      final dataTypes = SyncDataType.values;
      final totalSteps = dataTypes.length;
      var completedSteps = 0;

      for (final dataType in dataTypes) {
        if (_cancelToken!.isCancelled) {
          throw WebDavSyncCancelledException();
        }

        syncMessage.value = '同步${dataType.displayName}...';

        final localFile = await _getLocalFile(dataType);
        final remotePath = _getRemotePath(dataType);
        final remoteFile = remoteFiles.firstWhere(
          (f) => f.name == dataType.filename,
          orElse: () => null,
        );

        final needsSync = await _checkIncrementalSync(
          localFile,
          remoteFile,
          localChanges.where((c) => c.dataType == dataType).toList(),
        );

        if (needsSync) {
          final opResult = await _syncDataTypeIncremental(
            dataType,
            direction,
            localFile,
            remotePath,
            localChanges.where((c) => c.dataType == dataType).toList(),
            onProgress: (progress) {
              final baseProgress = 5 + (completedSteps / totalSteps) * 90;
              final stepProgress = (progress / 100) * (90 / totalSteps);
              syncProgress.value = baseProgress + stepProgress;
              onProgress?.call(syncProgress.value / 100);
            },
          );

          if (opResult.success) {
            changedFiles.add(dataType.filename);
            if (direction == SyncDirection.upload ||
                direction == SyncDirection.both) {
              result.uploadedCount++;
              uploadedBytes += (await localFile.length()).toInt();
            }
            if (direction == SyncDirection.download ||
                direction == SyncDirection.both) {
              result.downloadedCount++;
              downloadedBytes += ((remoteFile?.size as num?) ?? 0).toInt();
            }
          } else {
            result.error = opResult.error;
          }
        }

        completedSteps++;
      }

      await _clearIncrementalChanges();

      syncProgress.value = 100.0;
      syncStatus.value = SyncStatus.success;
      lastSyncTime.value = DateTime.now();
      syncMessage.value = '增量同步完成';

      _emitEvent(
        SyncEvent(
          type: SyncEventType.completed,
          message: '增量同步完成，变更 ${changedFiles.length} 个文件',
        ),
      );

      final historyRecord = SyncHistoryRecord(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        startTime: startTime,
        endTime: DateTime.now(),
        direction: direction,
        result: result,
        uploadedBytes: uploadedBytes,
        downloadedBytes: downloadedBytes,
        changedFiles: changedFiles,
      );
      await _addHistoryRecord(historyRecord);

      result.success = result.conflictCount == 0 && result.error == null;
      return result;
    } catch (e) {
      debugPrint('增量同步异常：$e');
      syncStatus.value = SyncStatus.failed;
      errorMessage.value = '增量同步异常：$e';
      syncMessage.value = '增量同步失败';

      _emitEvent(SyncEvent(type: SyncEventType.failed, message: '增量同步失败：$e'));

      return SyncResult(success: false, error: e.toString());
    }
  }

  Future<bool> _checkIncrementalSync(
    File localFile,
    dynamic remoteFile,
    List<IncrementalChange> changes,
  ) async {
    if (changes.isNotEmpty) {
      return true;
    }

    final localExists = await localFile.exists();
    final remoteExists = remoteFile != null;

    if (localExists != remoteExists) {
      return true;
    }

    if (localExists && remoteExists) {
      final localStat = await localFile.stat();
      final remoteModified = remoteFile.modified;
      return localStat.modified.isAfter(remoteModified as DateTime);
    }

    return false;
  }

  Future<SyncOperationResult> _syncDataTypeIncremental(
    SyncDataType type,
    SyncDirection direction,
    File localFile,
    String remotePath,
    List<IncrementalChange> changes, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      if (direction == SyncDirection.upload ||
          direction == SyncDirection.both) {
        if (await localFile.exists()) {
          if (changes.isNotEmpty) {
            await _uploadIncrementalChanges(
              localFile,
              remotePath,
              changes,
              onProgress: onProgress,
            );
          } else {
            await _uploadFile(
              localFile: localFile,
              remotePath: remotePath,
              onProgress: onProgress,
            );
          }
        }
      }

      if (direction == SyncDirection.download ||
          direction == SyncDirection.both) {
        await _downloadFile(
          remotePath: remotePath,
          localFile: localFile,
          onProgress: onProgress,
        );
      }

      return SyncOperationResult.success();
    } catch (e) {
      debugPrint('增量同步数据类型 ${type.name} 异常：$e');
      return SyncOperationResult.failure(e.toString());
    }
  }

  Future<void> _uploadIncrementalChanges(
    File localFile,
    String remotePath,
    List<IncrementalChange> changes, {
    void Function(double progress)? onProgress,
  }) async {
    final localContent = await localFile.readAsString();
    dynamic localData;

    try {
      localData = jsonDecode(localContent);
    } catch (e) {
      localData = <String, dynamic>{};
    }

    for (final change in changes) {
      if (change.operation == SyncOperation.delete) {
        if (localData is Map) {
          localData.remove(change.key);
        }
      } else {
        if (localData is Map) {
          localData[change.key] = change.value;
        }
      }
    }

    final updatedContent = jsonEncode(localData);
    final bytes = utf8.encode(updatedContent);

    await _client!.write(
      remotePath,
      bytes,
      onProgress: (current, total) {
        onProgress?.call(current / total * 100);
      },
      cancelToken: _cancelToken,
    );
  }

  Future<BackupInfo> createBackup({
    List<SyncDataType>? dataTypes,
    String? note,
  }) async {
    return _backupManager.createBackup(dataTypes: dataTypes, note: note);
  }

  Future<bool> restoreBackup(BackupInfo backupInfo) async {
    return _backupManager.restoreBackup(backupInfo);
  }

  Future<bool> deleteBackup(BackupInfo backupInfo) async {
    return _backupManager.deleteBackup(backupInfo);
  }

  List<BackupInfo> getBackups() {
    return backups.value;
  }

  List<SyncHistoryRecord> getHistory({int limit = 20}) {
    final sorted = List<SyncHistoryRecord>.from(syncHistory.value)
      ..sort((a, b) => b.startTime.compareTo(a.startTime));

    if (limit > 0 && sorted.length > limit) {
      return sorted.sublist(0, limit);
    }
    return sorted;
  }

  Future<void> clearHistory() async {
    syncHistory.value = [];
    await _saveHistory();
  }

  void startAutoSync() {
    _autoSyncService.start();
  }

  void stopAutoSync() {
    _autoSyncService.stop();
  }

  Future<void> setAutoSyncConfig(AutoSyncConfig config) async {
    await _autoSyncService.updateConfig(config);
  }

  Future<bool> resolveConflict({
    required ConflictInfo conflictInfo,
    required ConflictResolution resolution,
  }) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final localFile = File(
        p.join(appDir.path, _dataDirName, conflictInfo.dataType.filename),
      );
      final remotePath = p.join(
        _config!.remotePath,
        _syncSubDirName,
        conflictInfo.dataType.filename,
      );

      final result = await _conflictResolver.resolveConflict(
        conflictInfo.dataType,
        resolution,
        localFile,
        remotePath,
      );

      if (result.success) {
        conflicts.value = conflicts.value
            .where((c) => c != conflictInfo)
            .toList();

        _emitEvent(
          SyncEvent(
            type: SyncEventType.conflictResolved,
            message: '冲突已解决：${conflictInfo.dataType.name}',
            dataType: conflictInfo.dataType,
            conflictInfo: conflictInfo,
          ),
        );
      }

      return result.success;
    } catch (e) {
      Logging.error('解决冲突失败：$e');
      return false;
    }
  }

  Future<List<RemoteFileInfo>> listRemoteFiles() async {
    if (_config == null) {
      throw WebDavConfigInvalidException();
    }

    try {
      _client = await _connectionManager.getConnectedClient();
      final remoteDir = p.join(_config!.remotePath, _syncSubDirName);
      final files = await _client!.readDir(remoteDir);
      return files
          .where((f) => f['type'] != 'directory')
          .map((f) => RemoteFileInfo.fromWebDavFile(f))
          .toList();
    } catch (e) {
      debugPrint('列出远程文件失败：$e');
      return [];
    }
  }

  Future<bool> deleteRemoteFile(String remoteName) async {
    if (_config == null) {
      return false;
    }

    try {
      _client = await _connectionManager.getConnectedClient();
      final remotePath = p.join(
        _config!.remotePath,
        _syncSubDirName,
        remoteName,
      );
      await _client!.remove(remotePath, cancelToken: _cancelToken);
      if (kDebugMode) {
        debugPrint('文件删除成功：$remoteName');
      }
      return true;
    } catch (e) {
      debugPrint('文件删除失败：$e');
      return false;
    }
  }

  void cancelSync() {
    if (_cancelToken != null && !_cancelToken!.isCancelled) {
      _cancelToken!.cancel('用户取消同步');
      syncMessage.value = '同步已取消';
      syncStatus.value = SyncStatus.idle;

      _emitEvent(SyncEvent(type: SyncEventType.cancelled, message: '用户取消同步'));
    }
  }

  void dispose() {
    cancelSync();
    stopAutoSync();
    _autoSyncService.dispose();
    _eventController.close();
    _connectionManager.disconnect();
    _client = null;
  }

  Future<bool> _ensureRemoteDirectory() async {
    try {
      final remoteDir = p.join(_config!.remotePath, _syncSubDirName);
      await _client!.mkdirAll(remoteDir, cancelToken: _cancelToken);
      if (kDebugMode) {
        debugPrint('远程目录已创建：$remoteDir');
      }
      return true;
    } catch (e) {
      debugPrint('创建远程目录异常：$e');
      return false;
    }
  }

  Future<bool> _uploadFile({
    required File localFile,
    required String remotePath,
    void Function(double progress)? onProgress,
  }) async {
    try {
      if (!await localFile.exists()) {
        debugPrint('文件不存在：${localFile.path}');
        return false;
      }

      await _client!.writeFromFile(
        localFile.path,
        remotePath,
        onProgress: (current, total) {
          if (total > 0) {
            onProgress?.call(current / total * 100);
          }
        },
        cancelToken: _cancelToken,
      );

      if (kDebugMode) {
        debugPrint('文件上传成功：$remotePath');
      }
      return true;
    } catch (e) {
      debugPrint('文件上传失败：$e');
      return false;
    }
  }

  Future<bool> _downloadFile({
    required String remotePath,
    required File localFile,
    void Function(double progress)? onProgress,
  }) async {
    try {
      await _client!.read2File(
        remotePath,
        localFile.path,
        onProgress: (current, total) {
          if (total > 0) {
            onProgress?.call(current / total * 100);
          }
        },
        cancelToken: _cancelToken,
      );

      if (kDebugMode) {
        debugPrint('文件下载成功：$remotePath');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('文件不存在于服务器：$remotePath');
      }
      return false;
    }
  }

  Future<WebDavFileInfo?> _getFileInfo(String remotePath) async {
    try {
      if (_client == null) return null;

      final parentDir = p.dirname(remotePath);
      final fileName = p.basename(remotePath);

      final entries = await _client!.readDir(parentDir);
      for (final entry in entries) {
        if (entry.name == fileName) {
          final modified = (entry.modified as DateTime?) ?? DateTime(1970);
          return WebDavFileInfo(modified: modified);
        }
      }
    } catch (e) {
      Logging.debug('获取远程文件信息失败：$e');
    }
    return null;
  }

  Future<bool> _fileExists(String remotePath) async {
    try {
      if (_client == null) return false;

      final parentDir = p.dirname(remotePath);
      final fileName = p.basename(remotePath);

      final entries = await _client!.readDir(parentDir);
      return entries.any((entry) => entry.name == fileName);
    } catch (e) {
      return false;
    }
  }

  Future<void> _loadHistory() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final historyFile = File(p.join(appDir.path, _historyFile));

      if (await historyFile.exists()) {
        final content = await historyFile.readAsString();
        final jsonList = jsonDecode(content) as List;
        syncHistory.value = jsonList
            .map(
              (json) =>
                  SyncHistoryRecord.fromJson(json as Map<String, dynamic>),
            )
            .toList();
      }
    } catch (e) {
      debugPrint('加载同步历史失败：$e');
    }
  }

  Future<void> _addHistoryRecord(SyncHistoryRecord record) async {
    syncHistory.value = [...syncHistory.value, record];

    if (syncHistory.value.length > _maxHistoryRecords) {
      syncHistory.value = syncHistory.value.sublist(
        syncHistory.value.length - _maxHistoryRecords,
      );
    }

    await _saveHistory();
  }

  Future<void> _saveHistory() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final historyFile = File(p.join(appDir.path, _historyFile));

      final jsonList = syncHistory.value
          .map((record) => record.toJson())
          .toList();
      await historyFile.writeAsString(jsonEncode(jsonList), flush: true);
    } catch (e) {
      debugPrint('保存同步历史失败：$e');
    }
  }

  Future<List<IncrementalChange>> _loadIncrementalChanges() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final incrementalFile = File(p.join(appDir.path, _incrementalFile));

      if (await incrementalFile.exists()) {
        final content = await incrementalFile.readAsString();
        final jsonList = jsonDecode(content) as List;
        return jsonList
            .map(
              (json) =>
                  IncrementalChange.fromJson(json as Map<String, dynamic>),
            )
            .toList();
      }
    } catch (e) {
      debugPrint('加载增量变更记录失败：$e');
    }
    return [];
  }

  Future<void> _clearIncrementalChanges() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final incrementalFile = File(p.join(appDir.path, _incrementalFile));

      if (await incrementalFile.exists()) {
        await incrementalFile.delete();
      }
    } catch (e) {
      debugPrint('清除增量变更记录失败：$e');
    }
  }

  Future<File> _getLocalFile(SyncDataType type) async {
    final appDir = await getApplicationDocumentsDirectory();
    return File(p.join(appDir.path, _dataDirName, type.filename));
  }

  String _getRemotePath(SyncDataType type) {
    return p.join(_config!.remotePath, _syncSubDirName, type.filename);
  }

  Future<List<dynamic>> _listRemoteFiles() async {
    try {
      final remoteDir = p.join(_config!.remotePath, _syncSubDirName);
      return await _client!.readDir(remoteDir);
    } catch (e) {
      return [];
    }
  }
}
