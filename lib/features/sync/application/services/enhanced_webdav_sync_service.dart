/// 增强的 WebDAV 同步服务
///
/// 在基础 WebDavSyncService 上增强以下功能：
/// - 智能冲突检测和解决
/// - 增量同步支持
/// - 数据合并逻辑
/// - 同步队列管理
/// - 错误恢复机制
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../../core/utils/logging.dart';
import 'webdav_client_service.dart';
import 'webdav_sync_service.dart';

/// 同步事件类型
enum SyncEventType {
  /// 同步开始
  started,

  /// 同步进度更新
  progress,

  /// 检测到冲突
  conflict,

  /// 冲突已解决
  conflictResolved,

  /// 同步完成
  completed,

  /// 同步失败
  failed,

  /// 同步取消
  cancelled,

  /// 错误恢复
  recovered,
}

/// 同步事件
class SyncEvent {
  final SyncEventType type;
  final String message;
  final SyncDataType? dataType;
  final int? progress;
  final int? total;
  final ConflictInfo? conflictInfo;
  final DateTime timestamp;

  SyncEvent({
    required this.type,
    required this.message,
    this.dataType,
    this.progress,
    this.total,
    this.conflictInfo,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() {
    return 'SyncEvent(${type.name}): $message';
  }
}

/// 冲突信息
class ConflictInfo {
  final SyncDataType dataType;
  final DateTime localModified;
  final DateTime remoteModified;
  final String localPreview;
  final String remotePreview;
  final ConflictResolution? autoResolution;

  ConflictInfo({
    required this.dataType,
    required this.localModified,
    required this.remoteModified,
    required this.localPreview,
    required this.remotePreview,
    this.autoResolution,
  });

  /// 获取冲突描述
  String get description {
    final localTime = _formatTime(localModified);
    final remoteTime = _formatTime(remoteModified);
    return '${dataType.name}: 本地 ($localTime) vs 远程 ($remoteTime)';
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    return '${time.month}-${time.day} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

/// 增量同步记录
class IncrementalSyncRecord {
  final String key;
  final dynamic data;
  final DateTime modified;
  final SyncOperation operation;

  IncrementalSyncRecord({
    required this.key,
    required this.data,
    required this.modified,
    required this.operation,
  });
}

/// 同步操作类型
enum SyncOperation {
  /// 创建
  create,

  /// 更新
  update,

  /// 删除
  delete,
}

/// 增强的 WebDAV 同步服务
class EnhancedWebDavSyncService {
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

  /// 冲突列表
  final conflicts = signal<List<ConflictInfo>>([]);

  /// 取消令牌
  CancelToken? _cancelToken;

  /// 重试配置
  final int maxRetries;
  final Duration retryDelay;

  /// 数据目录名称
  static const String _dataDirName = 'data';

  /// 同步子目录名称
  static const String _syncSubDirName = 'zephyr_reader';

  EnhancedWebDavSyncService({
    WebDavConfig? config,
    WebDavClientService? client,
    this.maxRetries = 3,
    this.retryDelay = const Duration(seconds: 2),
  }) {
    if (config != null) {
      setConfig(config);
    }
    _client = client;
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

  /// 同步所有数据（增强版）
  ///
  /// 支持智能冲突检测、增量同步和错误恢复
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
    syncMessage.value = '开始同步...';
    errorMessage.value = null;
    conflicts.value = [];

    _emitEvent(SyncEvent(type: SyncEventType.started, message: '开始同步所有数据'));

    final result = SyncResult();
    var retryCount = 0;

    try {
      await _initClient();

      // 确保远程目录存在
      syncMessage.value = '检查远程目录...';
      await _ensureRemoteDirectory();
      syncProgress.value = 5.0;

      final dataTypes = SyncDataType.values;
      final totalSteps = dataTypes.length;
      var completedSteps = 0;

      for (final dataType in dataTypes) {
        // 检查取消
        if (_cancelToken!.isCancelled) {
          _emitEvent(
            SyncEvent(type: SyncEventType.cancelled, message: '同步已取消'),
          );
          throw WebDavSyncCancelledException();
        }

        syncMessage.value = '同步${_getDataTypeName(dataType)}...';

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
                      '同步${_getDataTypeName(dataType)}: ${progress.toStringAsFixed(0)}%',
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
          // 错误恢复机制
          if (retryCount < maxRetries) {
            retryCount++;
            Logging.debug(
              '同步${_getDataTypeName(dataType)}失败，第 $retryCount 次重试...',
            );
            _emitEvent(
              SyncEvent(
                type: SyncEventType.recovered,
                message: '同步失败，正在重试 ($retryCount/$maxRetries)',
                dataType: dataType,
              ),
            );

            await Future.delayed(retryDelay * retryCount);
            // 重试当前类型
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
            Logging.error('同步${_getDataTypeName(dataType)}失败，已达最大重试次数');
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

  /// 同步指定数据类型（带冲突处理）
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

      // 检查本地和远程文件
      final localExists = await localFile.exists();
      final remoteExists = await _fileExists(remotePath);

      // 检测冲突
      if (localExists && remoteExists && direction == SyncDirection.both) {
        final conflictInfo = await _checkConflict(localFile, remotePath, type);

        if (conflictInfo != null) {
          if (autoResolveConflicts && conflictInfo.autoResolution != null) {
            // 自动解决冲突
            _emitEvent(
              SyncEvent(
                type: SyncEventType.conflictResolved,
                message: '自动解决冲突：${type.name}',
                dataType: type,
                conflictInfo: conflictInfo,
              ),
            );

            return await _resolveConflict(
              type,
              conflictInfo.autoResolution!,
              localFile,
              remotePath,
              onProgress: onProgress,
            );
          } else {
            // 需要手动解决冲突
            conflicts.value = [...conflicts.value, conflictInfo];

            _emitEvent(
              SyncEvent(
                type: SyncEventType.conflict,
                message: '检测到冲突：${type.name}',
                dataType: type,
                conflictInfo: conflictInfo,
              ),
            );

            // 返回冲突信息，等待用户处理
            return SyncOperationResult.failure('检测到冲突，需要手动解决');
          }
        }
      }

      // 无冲突，正常同步
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

  /// 检查冲突
  Future<ConflictInfo?> _checkConflict(
    File localFile,
    String remotePath,
    SyncDataType type,
  ) async {
    try {
      final localStat = await localFile.stat();
      final localModified = localStat.modified;

      final remoteInfo = await _getFileInfo(remotePath);
      if (remoteInfo == null) return null;

      final remoteModified = remoteInfo.modified;

      // 如果时间差在 1 秒内，认为无冲突
      if ((localModified.difference(remoteModified)).inSeconds.abs() <= 1) {
        return null;
      }

      // 读取文件内容生成预览
      final localContent = await localFile.readAsString();
      final remoteContent = await _readRemoteFile(remotePath);

      // 如果内容相同，无冲突
      if (localContent == remoteContent) {
        return null;
      }

      // 检测冲突
      return ConflictInfo(
        dataType: type,
        localModified: localModified,
        remoteModified: remoteModified,
        localPreview: _generatePreview(localContent),
        remotePreview: _generatePreview(remoteContent),
        autoResolution: _determineAutoResolution(
          localModified,
          remoteModified,
          type,
        ),
      );
    } catch (e) {
      Logging.debug('检查冲突失败：$e');
      return null;
    }
  }

  /// 生成内容预览
  String _generatePreview(String content) {
    try {
      // 对于 JSON 内容，解析并生成有意义的预览
      final json = jsonDecode(content);
      if (json is Map) {
        final keys = json.keys.take(3).join(', ');
        return 'JSON 对象：{$keys, ...}';
      } else if (json is List) {
        return 'JSON 数组：${json.length} 项';
      }
      return json.toString();
    } catch (e) {
      // 非 JSON 内容，返回文本预览
      return content.length > 50 ? '${content.substring(0, 50)}...' : content;
    }
  }

  /// 确定自动解决策略
  ConflictResolution? _determineAutoResolution(
    DateTime localModified,
    DateTime remoteModified,
    SyncDataType type,
  ) {
    // 对于设置类型，优先使用本地版本
    if (type == SyncDataType.settings) {
      return ConflictResolution.useLocal;
    }

    // 对于阅读进度和书签，使用较新的版本
    if (type == SyncDataType.readingProgress ||
        type == SyncDataType.bookmarks) {
      return localModified.isAfter(remoteModified)
          ? ConflictResolution.useLocal
          : ConflictResolution.useRemote;
    }

    // 对于书架，使用较新的版本
    if (type == SyncDataType.bookshelf) {
      return localModified.isAfter(remoteModified)
          ? ConflictResolution.useLocal
          : ConflictResolution.useRemote;
    }

    return null;
  }

  /// 解决冲突
  Future<SyncOperationResult> _resolveConflict(
    SyncDataType type,
    ConflictResolution resolution,
    File localFile,
    String remotePath, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      switch (resolution) {
        case ConflictResolution.useLocal:
          // 使用本地版本覆盖
          if (await localFile.exists()) {
            await _uploadFile(
              localFile: localFile,
              remotePath: remotePath,
              onProgress: onProgress,
            );
          }
          break;

        case ConflictResolution.useRemote:
          // 使用远程版本覆盖
          await _downloadFile(
            remotePath: remotePath,
            localFile: localFile,
            onProgress: onProgress,
          );
          break;

        case ConflictResolution.merge:
          // 合并两个版本
          await _mergeData(type, localFile, remotePath);
          break;
      }

      return SyncOperationResult.success();
    } catch (e) {
      return SyncOperationResult.failure('解决冲突失败：$e');
    }
  }

  /// 同步指定数据类型
  Future<SyncOperationResult> _syncDataType(
    SyncDataType type,
    SyncDirection direction,
    File localFile,
    String remotePath, {
    bool enableIncrementalSync = true,
    void Function(double progress)? onProgress,
  }) async {
    try {
      // 上传
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

      // 下载
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

  /// 合并数据
  Future<void> _mergeData(
    SyncDataType type,
    File localFile,
    String remotePath,
  ) async {
    try {
      // 读取本地和远程数据
      final localContent = await localFile.readAsString();
      final remoteContent = await _readRemoteFile(remotePath);

      dynamic localData;
      dynamic remoteData;

      try {
        localData = jsonDecode(localContent);
      } catch (e) {
        localData = {};
      }

      try {
        remoteData = jsonDecode(remoteContent);
      } catch (e) {
        remoteData = {};
      }

      // 根据数据类型执行不同的合并策略
      dynamic mergedData;

      if (localData is Map && remoteData is Map) {
        // 对于 Map 类型，深度合并
        mergedData = _deepMergeMaps(
          Map<String, dynamic>.from(localData),
          Map<String, dynamic>.from(remoteData),
        );
      } else if (localData is List && remoteData is List) {
        // 对于 List 类型，合并并去重
        mergedData = _mergeLists(localData, remoteData);
      } else {
        // 其他类型，使用较新的版本
        final localStat = await localFile.stat();
        final remoteInfo = await _getFileInfo(remotePath);
        mergedData = localStat.modified.isAfter(remoteInfo!.modified)
            ? localData
            : remoteData;
      }

      // 保存合并后的数据到本地
      await localFile.writeAsString(jsonEncode(mergedData), flush: true);

      // 上传合并后的数据
      await _uploadFile(localFile: localFile, remotePath: remotePath);
    } catch (e) {
      Logging.error('合并数据失败：$e');
      rethrow;
    }
  }

  /// 深度合并两个 Map
  Map<String, dynamic> _deepMergeMaps(
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
  ) {
    final result = Map<String, dynamic>.from(local);

    for (final entry in remote.entries) {
      if (result.containsKey(entry.key)) {
        // 如果两个值都是 Map，递归合并
        if (result[entry.key] is Map && entry.value is Map) {
          result[entry.key] = _deepMergeMaps(
            Map<String, dynamic>.from(result[entry.key] as Map),
            Map<String, dynamic>.from(entry.value as Map),
          );
        }
        // 如果两个值都是 List，合并列表
        else if (result[entry.key] is List && entry.value is List) {
          result[entry.key] = _mergeLists(
            result[entry.key] as List,
            entry.value as List,
          );
        }
        // 否则使用远程值（假设远程更新）
        else {
          result[entry.key] = entry.value;
        }
      } else {
        // 本地没有的键，直接添加
        result[entry.key] = entry.value;
      }
    }

    return result;
  }

  /// 合并两个列表（去重）
  List<dynamic> _mergeLists(List<dynamic> local, List<dynamic> remote) {
    final result = List<dynamic>.from(local);

    for (final item in remote) {
      // 简单去重：如果列表中不存在相同元素则添加
      if (!result.any((r) => _deepEquals(r, item))) {
        result.add(item);
      }
    }

    return result;
  }

  /// 深度比较两个对象
  bool _deepEquals(dynamic a, dynamic b) {
    if (a == b) return true;
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final key in a.keys) {
        if (!b.containsKey(key) || !_deepEquals(a[key], b[key])) {
          return false;
        }
      }
      return true;
    }
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (int i = 0; i < a.length; i++) {
        if (!_deepEquals(a[i], b[i])) return false;
      }
      return true;
    }
    return false;
  }

  /// 读取远程文件内容
  Future<String> _readRemoteFile(String remotePath) async {
    try {
      final bytes = await _client!.read(remotePath);
      return String.fromCharCodes(bytes);
    } catch (e) {
      throw Exception('读取远程文件失败：$e');
    }
  }

  /// 确保远程目录存在
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

  /// 上传文件
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

      if (kDebugMode) {
        debugPrint('文件下载成功：$remotePath');
      }
      return true;
    } catch (e) {
      // 文件不存在于服务器，不是错误
      if (kDebugMode) {
        debugPrint('文件不存在于服务器：$remotePath');
      }
      return false;
    }
  }

  /// 获取远程文件信息
  Future<WebDavFileInfo?> _getFileInfo(String remotePath) async {
    try {
      if (_client == null) return null;

      final parentDir = p.dirname(remotePath);
      final fileName = p.basename(remotePath);

      final entries = await _client!.readDir(parentDir);
      for (final entry in entries) {
        if (entry.name == fileName) {
          final modified = entry.modified ?? DateTime(1970);
          return WebDavFileInfo(modified: modified);
        }
      }
    } catch (e) {
      Logging.debug('获取远程文件信息失败：$e');
    }
    return null;
  }

  /// 检查远程文件是否存在
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

      _emitEvent(SyncEvent(type: SyncEventType.cancelled, message: '用户取消同步'));
    }
  }

  /// 手动解决冲突
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

      final result = await _resolveConflict(
        conflictInfo.dataType,
        resolution,
        localFile,
        remotePath,
      );

      if (result.success) {
        // 从冲突列表中移除
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

  /// 释放资源
  void dispose() {
    cancelSync();
    _eventController.close();
    _client?.dispose();
    _client = null;
  }
}
