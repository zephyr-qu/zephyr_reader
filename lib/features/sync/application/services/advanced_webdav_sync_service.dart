/// WebDAV 高级同步服务
///
/// 提供增量同步、备份恢复、同步历史和定时同步功能
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/core/battery/battery_state_service.dart';
import 'package:zephyr_reader/core/network/network_state_service.dart';

import 'enhanced_webdav_sync_service.dart' hide SyncOperation;
import 'webdav_client_service.dart';
import 'webdav_sync_service.dart';

/// 同步记录
class SyncHistoryRecord {
  final String id;
  final DateTime startTime;
  final DateTime endTime;
  final SyncDirection direction;
  final SyncResult result;
  final int uploadedBytes;
  final int downloadedBytes;
  final List<String> changedFiles;
  final String? errorMessage;

  SyncHistoryRecord({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.direction,
    required this.result,
    this.uploadedBytes = 0,
    this.downloadedBytes = 0,
    this.changedFiles = const [],
    this.errorMessage,
  });

  /// 获取上传项目数
  int get uploadedCount => result.uploadedCount;

  /// 获取下载项目数
  int get downloadedCount => result.downloadedCount;

  /// 获取同步时长
  Duration get duration => endTime.difference(startTime);

  /// 获取格式化时长
  String get formattedDuration {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    if (minutes > 0) {
      return '$minutes 分 $seconds 秒';
    }
    return '$seconds 秒';
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'direction': direction.name,
      'result': result.toJson(),
      'uploadedBytes': uploadedBytes,
      'downloadedBytes': downloadedBytes,
      'changedFiles': changedFiles,
      'errorMessage': errorMessage,
    };
  }

  /// 从 JSON 创建
  factory SyncHistoryRecord.fromJson(Map<String, dynamic> json) {
    return SyncHistoryRecord(
      id: json['id'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      direction: SyncDirection.values.firstWhere(
        (e) => e.name == json['direction'],
        orElse: () => SyncDirection.both,
      ),
      result: SyncResult.fromJson(json['result'] as Map<String, dynamic>),
      uploadedBytes: json['uploadedBytes'] as int? ?? 0,
      downloadedBytes: json['downloadedBytes'] as int? ?? 0,
      changedFiles: (json['changedFiles'] as List?)?.cast<String>() ?? [],
      errorMessage: json['errorMessage'] as String?,
    );
  }
}

/// 增量同步变更项
class IncrementalChange {
  final SyncDataType dataType;
  final String key;
  final dynamic value;
  final DateTime modified;
  final SyncOperation operation;

  IncrementalChange({
    required this.dataType,
    required this.key,
    required this.value,
    required this.modified,
    required this.operation,
  });

  Map<String, dynamic> toJson() {
    return {
      'dataType': dataType.name,
      'key': key,
      'value': value,
      'modified': modified.toIso8601String(),
      'operation': operation.name,
    };
  }

  factory IncrementalChange.fromJson(Map<String, dynamic> json) {
    return IncrementalChange(
      dataType: SyncDataType.values.firstWhere(
        (e) => e.name == json['dataType'],
      ),
      key: json['key'] as String,
      value: json['value'],
      modified: DateTime.parse(json['modified'] as String),
      operation: SyncOperation.values.firstWhere(
        (e) => e.name == json['operation'],
      ),
    );
  }
}

/// 备份信息
class BackupInfo {
  final String id;
  final DateTime timestamp;
  final String filePath;
  final int fileSize;
  final List<String> includedDataTypes;
  final String? note;

  BackupInfo({
    required this.id,
    required this.timestamp,
    required this.filePath,
    required this.fileSize,
    required this.includedDataTypes,
    this.note,
  });

  /// 获取格式化时间
  String get formattedTime {
    return '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')} '
        '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
  }

  /// 获取格式化大小
  String get formattedSize {
    if (fileSize < 1024) {
      return '$fileSize B';
    } else if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'filePath': filePath,
      'fileSize': fileSize,
      'includedDataTypes': includedDataTypes,
      'note': note,
    };
  }

  factory BackupInfo.fromJson(Map<String, dynamic> json) {
    return BackupInfo(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      filePath: json['filePath'] as String,
      fileSize: json['fileSize'] as int,
      includedDataTypes: (json['includedDataTypes'] as List).cast<String>(),
      note: json['note'] as String?,
    );
  }
}

/// 定时同步配置
class AutoSyncConfig {
  bool enabled;
  Duration interval;
  SyncDirection direction;
  bool onlyOnWifi;
  bool requireCharging;

  AutoSyncConfig({
    this.enabled = false,
    this.interval = const Duration(minutes: 30),
    this.direction = SyncDirection.both,
    this.onlyOnWifi = true,
    this.requireCharging = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'intervalMinutes': interval.inMinutes,
      'direction': direction.name,
      'onlyOnWifi': onlyOnWifi,
      'requireCharging': requireCharging,
    };
  }

  factory AutoSyncConfig.fromJson(Map<String, dynamic> json) {
    return AutoSyncConfig(
      enabled: json['enabled'] as bool? ?? false,
      interval: Duration(minutes: json['intervalMinutes'] as int? ?? 30),
      direction: SyncDirection.values.firstWhere(
        (e) => e.name == json['direction'],
        orElse: () => SyncDirection.both,
      ),
      onlyOnWifi: json['onlyOnWifi'] as bool? ?? true,
      requireCharging: json['requireCharging'] as bool? ?? false,
    );
  }
}

/// WebDAV 高级同步服务
class AdvancedWebDavSyncService {
  WebDavConfig? _config;
  WebDavClientService? _client;

  /// 同步事件流控制器
  final _eventController = StreamController<SyncEvent>.broadcast();

  /// 同步事件流
  Stream<SyncEvent> get eventStream => _eventController.stream;

  /// 当前同步状态
  final syncStatus = signal<SyncStatus>(SyncStatus.idle);

  /// 同步进度 (0.0 - 1.0)
  final syncProgress = signal<double>(0.0);

  /// 最后同步时间
  final lastSyncTime = signal<DateTime?>(null);

  /// 错误信息
  final errorMessage = signal<String?>(null);

  /// 同步状态详情
  final syncMessage = signal<String>('');

  /// 同步历史记录
  final syncHistory = signal<List<SyncHistoryRecord>>([]);

  /// 备份列表
  final backups = signal<List<BackupInfo>>([]);

  /// 定时同步配置
  final autoSyncConfig = signal<AutoSyncConfig>(AutoSyncConfig());

  /// 定时器
  Timer? _syncTimer;

  /// 取消令牌
  CancelToken? _cancelToken;

  /// 数据目录名称
  static const String _dataDirName = 'data';

  /// 同步子目录名称
  static const String _syncSubDirName = 'zephyr_reader';

  /// 备份目录名称
  static const String _backupDirName = 'backups';

  /// 同步历史文件
  static const String _historyFile = 'sync_history.json';

  /// 增量同步记录文件
  static const String _incrementalFile = 'sync_incremental.json';

  /// 定时同步配置
  static const String _autoSyncConfigFile = 'auto_sync_config.json';

  /// 最大同步历史记录数
  static const int _maxHistoryRecords = 50;

  AdvancedWebDavSyncService({
    WebDavConfig? config,
    WebDavClientService? client,
  }) {
    if (config != null) {
      setConfig(config);
    }
    _client = client;
    _loadHistory();
    _loadAutoSyncConfig();
  }

  /// 设置配置
  void setConfig(WebDavConfig config) {
    _config = config;
  }

  /// 获取配置
  WebDavConfig? get config => _config;

  /// 初始化客户端
  Future<void> _initClient() async {
    if (_config == null || !_config!.isValid) {
      throw WebDavConfigInvalidException();
    }

    if (_client == null || !_client!.isInitialized) {
      _client = WebDavClientService();
      await _client!.init(
        baseUrl: _config!.baseUrl,
        username: _config!.username,
        password: _config!.password,
        debug: kDebugMode,
      );
    }
  }

  /// 发送同步事件
  void _emitEvent(SyncEvent event) {
    if (!_eventController.isClosed) {
      _eventController.add(event);
    }
  }

  /// 增量同步所有数据
  ///
  /// 只同步变更的数据，节省流量和时间
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
      await _initClient();
      await _ensureRemoteDirectory();
      syncProgress.value = 5.0;

      // 获取本地增量变更记录
      final localChanges = await _loadIncrementalChanges();

      // 获取远程文件列表
      final remoteFiles = await _listRemoteFiles();

      final dataTypes = SyncDataType.values;
      final totalSteps = dataTypes.length;
      var completedSteps = 0;

      for (final dataType in dataTypes) {
        if (_cancelToken!.isCancelled) {
          throw WebDavSyncCancelledException();
        }

        syncMessage.value = '同步${_getDataTypeName(dataType)}...';

        final localFile = await _getLocalFile(dataType);
        final remotePath = _getRemotePath(dataType);
        final remoteFile = remoteFiles.firstWhere(
          (f) => f.name == dataType.filename,
          orElse: () => null,
        );

        // 检查是否需要增量同步
        final needsSync = await _checkIncrementalSync(
          localFile,
          remoteFile,
          localChanges.where((c) => c.dataType == dataType).toList(),
        );

        if (needsSync) {
          // 执行增量同步
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

      // 清除已同步的变更记录
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

      // 记录同步历史
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

  /// 检查是否需要增量同步
  Future<bool> _checkIncrementalSync(
    File localFile,
    dynamic remoteFile,
    List<IncrementalChange> changes,
  ) async {
    // 如果有变更记录，需要增量同步
    if (changes.isNotEmpty) {
      return true;
    }

    // 检查文件是否存在
    final localExists = await localFile.exists();
    final remoteExists = remoteFile != null;

    // 一方存在一方不存在，需要同步
    if (localExists != remoteExists) {
      return true;
    }

    // 都存在，检查修改时间
    if (localExists && remoteExists) {
      final localStat = await localFile.stat();
      final remoteModified = remoteFile.modified;
      return localStat.modified.isAfter(remoteModified);
    }

    return false;
  }

  /// 增量同步指定数据类型
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
        // 上传本地变更
        if (await localFile.exists()) {
          // 如果有增量变更，只上传变更部分
          if (changes.isNotEmpty) {
            await _uploadIncrementalChanges(
              localFile,
              remotePath,
              changes,
              onProgress: onProgress,
            );
          } else {
            // 否则全量上传
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
        // 下载远程变更
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

  /// 上传增量变更
  Future<void> _uploadIncrementalChanges(
    File localFile,
    String remotePath,
    List<IncrementalChange> changes, {
    void Function(double progress)? onProgress,
  }) async {
    // 读取本地数据
    final localContent = await localFile.readAsString();
    dynamic localData;

    try {
      localData = jsonDecode(localContent);
    } catch (e) {
      localData = {};
    }

    // 应用增量变更
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

    // 上传更新后的数据
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

  /// 备份所有数据
  ///
  /// 创建本地完整备份
  Future<BackupInfo> createBackup({
    List<SyncDataType>? dataTypes,
    String? note,
  }) async {
    final appDir = await getApplicationDocumentsDirectory();
    final backupDir = Directory(p.join(appDir.path, _backupDirName));

    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }

    final timestamp = DateTime.now();
    final backupId = timestamp.millisecondsSinceEpoch.toString();
    final backupFileName =
        'backup_${timestamp.toIso8601String().replaceAll(':', '-')}.zip';
    final backupFilePath = p.join(backupDir.path, backupFileName);

    final includedTypes = dataTypes ?? SyncDataType.values;
    final backupData = <String, dynamic>{};

    for (final dataType in includedTypes) {
      final localFile = await _getLocalFile(dataType);
      if (await localFile.exists()) {
        final content = await localFile.readAsString();
        backupData[dataType.filename] = content;
      }
    }

    // 保存备份文件
    final backupFile = File(backupFilePath);
    final backupContent = jsonEncode(backupData);
    await backupFile.writeAsString(backupContent, flush: true);

    final backupInfo = BackupInfo(
      id: backupId,
      timestamp: timestamp,
      filePath: backupFilePath,
      fileSize: await backupFile.length(),
      includedDataTypes: includedTypes.map((e) => e.name).toList(),
      note: note,
    );

    // 添加到备份列表
    backups.value = [...backups.value, backupInfo];
    await _saveBackups();

    _emitEvent(SyncEvent(type: SyncEventType.completed, message: '备份创建成功'));

    return backupInfo;
  }

  /// 恢复备份
  ///
  /// 从备份文件恢复数据
  Future<bool> restoreBackup(BackupInfo backupInfo) async {
    try {
      final backupFile = File(backupInfo.filePath);
      if (!await backupFile.exists()) {
        throw Exception('备份文件不存在');
      }

      final content = await backupFile.readAsString();
      final backupData = jsonDecode(content) as Map<String, dynamic>;

      for (final entry in backupData.entries) {
        final dataType = SyncDataType.values.firstWhere(
          (e) => e.filename == entry.key,
          orElse: () => SyncDataType.settings, // 默认值
        );

        final localFile = await _getLocalFile(dataType);
        await localFile.parent.create(recursive: true);
        await localFile.writeAsString(entry.value, flush: true);
      }

      _emitEvent(SyncEvent(type: SyncEventType.completed, message: '备份恢复成功'));

      return true;
    } catch (e) {
      debugPrint('恢复备份异常：$e');
      _emitEvent(SyncEvent(type: SyncEventType.failed, message: '备份恢复失败：$e'));
      return false;
    }
  }

  /// 删除备份
  Future<bool> deleteBackup(BackupInfo backupInfo) async {
    try {
      final backupFile = File(backupInfo.filePath);
      if (await backupFile.exists()) {
        await backupFile.delete();
      }

      backups.value = backups.value
          .where((b) => b.id != backupInfo.id)
          .toList();
      await _saveBackups();

      return true;
    } catch (e) {
      debugPrint('删除备份异常：$e');
      return false;
    }
  }

  /// 获取备份列表
  List<BackupInfo> getBackups() {
    return backups.value;
  }

  /// 获取同步历史
  List<SyncHistoryRecord> getHistory({int limit = 20}) {
    final sorted = List<SyncHistoryRecord>.from(syncHistory.value)
      ..sort((a, b) => b.startTime.compareTo(a.startTime));

    if (limit > 0 && sorted.length > limit) {
      return sorted.sublist(0, limit);
    }
    return sorted;
  }

  /// 清除同步历史
  Future<void> clearHistory() async {
    syncHistory.value = [];
    await _saveHistory();
  }

  /// 启动定时同步
  void startAutoSync() {
    _stopAutoSync();

    final config = autoSyncConfig.value;
    if (!config.enabled) {
      return;
    }

    _syncTimer = Timer.periodic(config.interval, (_) async {
      await _performAutoSync();
    });

    _emitEvent(
      SyncEvent(
        type: SyncEventType.started,
        message: '定时同步已启动，间隔 ${config.interval.inMinutes} 分钟',
      ),
    );
  }

  /// 停止定时同步
  void stopAutoSync() {
    _stopAutoSync();

    _emitEvent(SyncEvent(type: SyncEventType.cancelled, message: '定时同步已停止'));
  }

  void _stopAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  /// 执行定时同步
  Future<void> _performAutoSync() async {
    final config = autoSyncConfig.value;
    if (!config.enabled || _config == null) {
      return;
    }

    // 检查网络条件
    if (config.onlyOnWifi) {
      final isWifi = await NetworkStateService().isOnWifi();
      if (!isWifi) {
        debugPrint('定时同步跳过：非 WiFi 网络');
        return;
      }
    }

    // 检查充电状态
    if (config.requireCharging) {
      final isCharging = await BatteryStateService().isCharging();
      if (!isCharging) {
        debugPrint('定时同步跳过：设备未充电');
        return;
      }
    }

    try {
      await syncIncremental(direction: config.direction);
    } catch (e) {
      // 定时同步失败时不输出日志
    }
  }

  /// 设置定时同步配置
  Future<void> setAutoSyncConfig(AutoSyncConfig config) async {
    autoSyncConfig.value = config;
    await _saveAutoSyncConfig();

    if (config.enabled) {
      startAutoSync();
    } else {
      stopAutoSync();
    }
  }

  /// 加载同步历史
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

  /// 添加同步历史记录
  Future<void> _addHistoryRecord(SyncHistoryRecord record) async {
    syncHistory.value = [...syncHistory.value, record];

    // 限制历史记录数量
    if (syncHistory.value.length > _maxHistoryRecords) {
      syncHistory.value = syncHistory.value.sublist(
        syncHistory.value.length - _maxHistoryRecords,
      );
    }

    await _saveHistory();
  }

  /// 保存同步历史
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

  /// 加载增量变更记录
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

  /// 清除增量变更记录
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

  /// 加载自动同步配置
  Future<void> _loadAutoSyncConfig() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final configFile = File(p.join(appDir.path, _autoSyncConfigFile));

      if (await configFile.exists()) {
        final content = await configFile.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        autoSyncConfig.value = AutoSyncConfig.fromJson(json);
      }
    } catch (e) {
      debugPrint('加载自动同步配置失败：$e');
    }
  }

  /// 保存自动同步配置
  Future<void> _saveAutoSyncConfig() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final configFile = File(p.join(appDir.path, _autoSyncConfigFile));

      await configFile.writeAsString(
        jsonEncode(autoSyncConfig.value.toJson()),
        flush: true,
      );
    } catch (e) {
      debugPrint('保存自动同步配置失败：$e');
    }
  }

  /// 保存备份列表
  Future<void> _saveBackups() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final backupListFile = File(
        p.join(appDir.path, _backupDirName, 'backup_list.json'),
      );

      final jsonList = backups.value.map((info) => info.toJson()).toList();
      await backupListFile.writeAsString(jsonEncode(jsonList), flush: true);
    } catch (e) {
      debugPrint('保存备份列表失败：$e');
    }
  }

  /// 获取本地文件
  Future<File> _getLocalFile(SyncDataType type) async {
    final appDir = await getApplicationDocumentsDirectory();
    return File(p.join(appDir.path, _dataDirName, type.filename));
  }

  /// 获取远程路径
  String _getRemotePath(SyncDataType type) {
    return p.join(_config!.remotePath, _syncSubDirName, type.filename);
  }

  /// 列出远程文件
  Future<List<dynamic>> _listRemoteFiles() async {
    try {
      final remoteDir = p.join(_config!.remotePath, _syncSubDirName);
      return await _client!.readDir(remoteDir);
    } catch (e) {
      return [];
    }
  }

  /// 确保远程目录存在
  Future<bool> _ensureRemoteDirectory() async {
    try {
      final remoteDir = p.join(_config!.remotePath, _syncSubDirName);
      await _client!.mkdirAll(remoteDir, cancelToken: _cancelToken);
      return true;
    } catch (e) {
      debugPrint('创建远程目录异常：$e');
      return false;
    }
  }

  /// 上传文件
  Future<bool> _uploadFile({
    required File localFile,
    required String remotePath,
    void Function(double progress)? onProgress,
  }) async {
    try {
      if (!await localFile.exists()) {
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

      return true;
    } catch (e) {
      debugPrint('文件上传失败：$e');
      return false;
    }
  }

  /// 下载文件
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

      return true;
    } catch (e) {
      return false;
    }
  }

  /// 获取数据类型名称
  String _getDataTypeName(SyncDataType type) {
    switch (type) {
      case SyncDataType.readingProgress:
        return '阅读进度';
      case SyncDataType.bookmarks:
        return '书签';
      case SyncDataType.bookshelf:
        return '书架';
      case SyncDataType.settings:
        return '设置';
    }
  }

  /// 取消当前同步
  void cancelSync() {
    if (_cancelToken != null && !_cancelToken!.isCancelled) {
      _cancelToken!.cancel('用户取消同步');
      syncMessage.value = '同步已取消';
      syncStatus.value = SyncStatus.idle;
    }
  }

  /// 释放资源
  void dispose() {
    cancelSync();
    stopAutoSync();
    _eventController.close();
    _client?.dispose();
    _client = null;
  }
}
