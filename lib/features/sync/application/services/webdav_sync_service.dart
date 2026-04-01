/// WebDAV 同步服务
///
/// 提供 WebDAV 服务器的数据同步功能
///
/// 功能特性:
/// - 连接测试
/// - 账号认证
/// - 文件上传/下载
/// - 数据同步（进度、书签、书架、设置）
/// - 冲突解决
/// - 进度回调
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../../core/utils/logging.dart';
import 'webdav_client_service.dart';

/// WebDAV 文件信息
class WebDavFileInfo {
  final DateTime modified;

  WebDavFileInfo({required this.modified});
}

/// WebDAV 配置
///
/// 包含连接 WebDAV 服务器所需的所有信息
class WebDavConfig {
  /// 服务器地址
  final String baseUrl;

  /// 用户名
  final String username;

  /// 密码
  final String password;

  /// 远程目录路径
  final String remotePath;

  WebDavConfig({
    required this.baseUrl,
    required this.username,
    required this.password,
    required this.remotePath,
  });

  /// 复制并修改配置
  WebDavConfig copyWith({
    String? baseUrl,
    String? username,
    String? password,
    String? remotePath,
  }) {
    return WebDavConfig(
      baseUrl: baseUrl ?? this.baseUrl,
      username: username ?? this.username,
      password: password ?? this.password,
      remotePath: remotePath ?? this.remotePath,
    );
  }

  /// 验证配置完整性
  bool get isValid {
    return baseUrl.isNotEmpty &&
        username.isNotEmpty &&
        password.isNotEmpty &&
        remotePath.isNotEmpty;
  }

  /// 获取服务器显示名称
  String get serverName {
    try {
      final uri = Uri.parse(baseUrl);
      return uri.host;
    } catch (e) {
      return baseUrl;
    }
  }
}

/// 同步状态
enum SyncStatus {
  /// 空闲
  idle,

  /// 同步中
  syncing,

  /// 同步成功
  success,

  /// 同步失败
  failed,

  /// 冲突需要解决
  conflict,
}

/// 同步数据类型
enum SyncDataType {
  /// 阅读进度
  readingProgress('reading_progress.json'),

  /// 书签
  bookmarks('bookmarks.json'),

  /// 书架
  bookshelf('bookshelf.json'),

  /// 设置
  settings('settings.json');

  final String filename;

  const SyncDataType(this.filename);
}

/// 同步方向
enum SyncDirection {
  /// 仅上传
  upload,

  /// 仅下载
  download,

  /// 双向同步
  both,
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

/// 冲突解决策略
enum ConflictResolution {
  /// 使用本地版本
  useLocal,

  /// 使用远程版本
  useRemote,

  /// 合并两个版本
  merge,
}

/// 同步数据项
class SyncDataItem {
  final SyncDataType type;
  final String filename;
  final DateTime localModified;
  final DateTime? remoteModified;
  final bool hasLocal;
  final bool hasRemote;

  SyncDataItem({
    required this.type,
    required this.filename,
    required this.localModified,
    this.remoteModified,
    this.hasLocal = true,
    this.hasRemote = true,
  });

  /// 是否需要同步
  bool get needsSync =>
      hasLocal != hasRemote || localModified != remoteModified;

  /// 获取冲突状态描述
  String get conflictDescription {
    if (!hasLocal && !hasRemote) {
      return '本地和远程均无数据';
    } else if (!hasLocal) {
      return '仅远程有数据';
    } else if (!hasRemote) {
      return '仅本地有数据';
    } else if (localModified.isAfter(remoteModified!)) {
      return '本地版本更新';
    } else if (remoteModified!.isAfter(localModified)) {
      return '远程版本更新';
    } else {
      return '数据一致';
    }
  }
}

/// 远程文件信息
class RemoteFileInfo {
  final String name;
  final int size;
  final DateTime modified;
  final bool isDirectory;

  RemoteFileInfo({
    required this.name,
    required this.size,
    required this.modified,
    this.isDirectory = false,
  });

  /// 从 webdav.WebDavFile 创建
  factory RemoteFileInfo.fromWebDavFile(dynamic file) {
    return RemoteFileInfo(
      name: file.name ?? p.basename(file.path ?? ''),
      size: file.size ?? 0,
      modified: file.modified ?? DateTime(1970),
      isDirectory: file.type == 'directory',
    );
  }

  /// 获取格式化后的大小
  String get formattedSize {
    if (size < 1024) {
      return '$size B';
    } else if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }
}

/// 同步结果
class SyncResult {
  /// 是否成功
  bool success;

  /// 上传的项目数
  int uploadedCount;

  /// 下载的项目数
  int downloadedCount;

  /// 冲突的项目数
  int conflictCount;

  /// 错误信息
  String? error;

  /// 详细结果
  Map<SyncDataType, SyncOperationResult> details;

  SyncResult({
    this.success = false,
    this.uploadedCount = 0,
    this.downloadedCount = 0,
    this.conflictCount = 0,
    this.error,
    Map<SyncDataType, SyncOperationResult>? details,
  }) : details = details ?? {};

  /// 获取同步摘要
  String get summary {
    if (!success) {
      return '同步失败：$error';
    }
    final parts = <String>[];
    if (uploadedCount > 0) parts.add('上传 $uploadedCount 项');
    if (downloadedCount > 0) parts.add('下载 $downloadedCount 项');
    if (conflictCount > 0) parts.add('冲突 $conflictCount 项');
    return parts.isEmpty ? '同步完成，无需更新' : parts.join(', ');
  }

  SyncResult copyWith({
    bool? success,
    int? uploadedCount,
    int? downloadedCount,
    int? conflictCount,
    String? error,
    Map<SyncDataType, SyncOperationResult>? details,
  }) {
    return SyncResult(
      success: success ?? this.success,
      uploadedCount: uploadedCount ?? this.uploadedCount,
      downloadedCount: downloadedCount ?? this.downloadedCount,
      conflictCount: conflictCount ?? this.conflictCount,
      error: error ?? this.error,
      details: details ?? this.details,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'uploadedCount': uploadedCount,
      'downloadedCount': downloadedCount,
      'conflictCount': conflictCount,
      'error': error,
    };
  }

  /// 从 JSON 创建
  factory SyncResult.fromJson(Map<String, dynamic> json) {
    return SyncResult(
      success: json['success'] as bool? ?? false,
      uploadedCount: json['uploadedCount'] as int? ?? 0,
      downloadedCount: json['downloadedCount'] as int? ?? 0,
      conflictCount: json['conflictCount'] as int? ?? 0,
      error: json['error'] as String?,
    );
  }
}

/// 单个同步操作的结果
class SyncOperationResult {
  final bool success;
  final String? error;
  final DateTime? timestamp;

  SyncOperationResult({this.success = false, this.error, this.timestamp});

  factory SyncOperationResult.success() {
    return SyncOperationResult(success: true, timestamp: DateTime.now());
  }

  factory SyncOperationResult.failure(String error) {
    return SyncOperationResult(success: false, error: error);
  }
}

/// WebDAV 同步服务
///
/// 使用 WebDavClientService 进行数据同步
class WebDavSyncService {
  WebDavConfig? _config;
  WebDavClientService? _client;

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

  /// 当前上传进度
  final currentUploadProgress = signal<double>(0.0);

  /// 当前下载进度
  final currentDownloadProgress = signal<double>(0.0);

  /// 取消令牌
  dynamic _cancelToken;

  /// 数据目录名称
  static const String _dataDirName = 'data';

  /// 同步子目录名称
  static const String _syncSubDirName = 'zephyr_reader';

  WebDavSyncService({WebDavConfig? config, WebDavClientService? client}) {
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

  /// 测试连接
  ///
  /// 返回 true 表示连接成功
  Future<bool> testConnection() async {
    if (_config == null || !_config!.isValid) {
      debugPrint('WebDAV 配置未设置或无效');
      return false;
    }

    try {
      await _initClient();
      final result = await _client!.ping();
      if (result && kDebugMode) {
        debugPrint('WebDAV 连接测试成功');
      }
      return result;
    } catch (e) {
      debugPrint('WebDAV 连接测试异常：$e');
      errorMessage.value = '连接异常：$e';
      return false;
    }
  }

  /// 同步所有数据
  ///
  /// [direction] 同步方向
  /// [onProgress] 进度回调
  /// [cancelToken] 取消令牌，用于取消同步操作
  Future<SyncResult> syncAll({
    SyncDirection direction = SyncDirection.both,
    void Function(double progress)? onProgress,
    dynamic cancelToken,
  }) async {
    if (_config == null || !_config!.isValid) {
      return SyncResult(success: false, error: 'WebDAV 配置未设置');
    }
    final CancelToken cancel = CancelToken();
    // 创建取消令牌
    _cancelToken = cancelToken ?? cancel;
    syncStatus.value = SyncStatus.syncing;
    syncProgress.value = 0.0;
    currentUploadProgress.value = 0.0;
    currentDownloadProgress.value = 0.0;
    syncMessage.value = '开始同步...';
    errorMessage.value = null;

    final result = SyncResult();

    try {
      await _initClient();

      // 确保远程目录存在
      syncMessage.value = '检查远程目录...';
      await _ensureRemoteDirectory();
      syncProgress.value = 5.0;

      // 获取所有数据类型
      final dataTypes = SyncDataType.values;
      final totalSteps = dataTypes.length * 2; // 每个类型需要上传和下载两步
      var completedSteps = 0;

      for (final dataType in dataTypes) {
        // 检查取消
        if (_cancelToken!.isCancelled) {
          throw WebDavSyncCancelledException();
        }

        // 同步当前数据类型
        syncMessage.value = '同步${_getDataTypeName(dataType)}...';
        final opResult = await _syncDataType(
          dataType,
          direction,
          onProgress: (progress) {
            final baseProgress = (completedSteps / totalSteps) * 100;
            final stepProgress = (progress / 100) * (100 / totalSteps);
            syncProgress.value = baseProgress + stepProgress;
            onProgress?.call(syncProgress.value / 100);
          },
        );

        result.details[dataType] = opResult;

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

        completedSteps += 2;
      }

      syncProgress.value = 100.0;
      syncStatus.value = SyncStatus.success;
      lastSyncTime.value = DateTime.now();
      syncMessage.value = '同步完成';

      result.success = result.conflictCount == 0 && result.error == null;
      return result;
    } catch (e) {
      debugPrint('同步异常：$e');
      syncStatus.value = SyncStatus.failed;
      errorMessage.value = '同步异常：$e';
      syncMessage.value = '同步失败';
      return SyncResult(success: false, error: e.toString());
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

  /// 同步指定数据类型
  Future<SyncOperationResult> _syncDataType(
    SyncDataType type,
    SyncDirection direction, {
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

      // 上传
      if (direction == SyncDirection.upload ||
          direction == SyncDirection.both) {
        if (await localFile.exists()) {
          final uploaded = await _uploadFile(
            localFile: localFile,
            remotePath: remotePath,
            onProgress: (progress) {
              currentUploadProgress.value = progress;
              onProgress?.call(progress * 0.5); // 上传占 50%
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
            currentDownloadProgress.value = progress;
            onProgress?.call(progress * 0.5); // 下载占 50%
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

  /// 列出远程文件
  Future<List<RemoteFileInfo>> listRemoteFiles() async {
    if (_config == null) {
      throw WebDavConfigInvalidException();
    }

    try {
      await _initClient();
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

  /// 删除远程文件
  Future<bool> deleteRemoteFile(String remoteName) async {
    if (_config == null) {
      return false;
    }

    try {
      await _initClient();
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

  /// 解决冲突
  Future<bool> resolveConflict({
    required SyncDataType type,
    required ConflictResolution resolution,
  }) async {
    try {
      switch (resolution) {
        case ConflictResolution.useLocal:
          await _uploadData(type);
          break;
        case ConflictResolution.useRemote:
          await _downloadData(type);
          break;
        case ConflictResolution.merge:
          await _mergeData(type);
          break;
      }
      return true;
    } catch (e) {
      debugPrint('解决冲突异常：$e');
      return false;
    }
  }

  Future<void> _uploadData(SyncDataType type) async {
    final appDir = await getApplicationDocumentsDirectory();
    final localFile = File(p.join(appDir.path, _dataDirName, type.filename));
    final remotePath = p.join(
      _config!.remotePath,
      _syncSubDirName,
      type.filename,
    );

    if (await localFile.exists()) {
      await _uploadFile(localFile: localFile, remotePath: remotePath);
    }
  }

  Future<void> _downloadData(SyncDataType type) async {
    final appDir = await getApplicationDocumentsDirectory();
    final localFile = File(p.join(appDir.path, _dataDirName, type.filename));
    final remotePath = p.join(
      _config!.remotePath,
      _syncSubDirName,
      type.filename,
    );

    await _downloadFile(remotePath: remotePath, localFile: localFile);
  }

  Future<void> _mergeData(SyncDataType type) async {
    // 数据合并逻辑：比较本地和远程版本的时间戳
    // 使用较新的版本覆盖较旧的版本

    final appDir = await getApplicationDocumentsDirectory();
    final localFile = File(p.join(appDir.path, _dataDirName, type.filename));
    final remotePath = p.join(
      _config!.remotePath,
      _syncSubDirName,
      type.filename,
    );

    // 检查本地和远程文件是否存在
    final localExists = await localFile.exists();
    final remoteExists = await _fileExists(remotePath);

    if (!localExists && !remoteExists) {
      // 都不存在，无需合并
      return;
    }

    if (!localExists) {
      // 仅远程存在，下载
      await _downloadFile(remotePath: remotePath, localFile: localFile);
      return;
    }

    if (!remoteExists) {
      // 仅本地存在，上传
      await _uploadData(type);
      return;
    }

    // 两个都存在，比较修改时间
    final localStat = await localFile.stat();
    final localModified = localStat.modified;

    final remoteInfo = await _getFileInfo(remotePath);
    final remoteModified = remoteInfo?.modified ?? DateTime(1970);

    if (localModified.isAfter(remoteModified)) {
      // 本地更新，上传
      await _uploadData(type);
    } else if (remoteModified.isAfter(localModified)) {
      // 远程更新，下载
      await _downloadFile(remotePath: remotePath, localFile: localFile);
    }
    // 时间相同，无需操作
  }

  /// 获取远程文件信息
  Future<WebDavFileInfo?> _getFileInfo(String remotePath) async {
    try {
      if (_client == null) return null;

      // 使用 readDir 检查文件是否存在并获取信息
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

      // 使用 readDir 检查文件是否存在
      final parentDir = p.dirname(remotePath);
      final fileName = p.basename(remotePath);

      final entries = await _client!.readDir(parentDir);
      return entries.any((entry) => entry.name == fileName);
    } catch (e) {
      return false;
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
    _client?.dispose();
    _client = null;
  }
}

/// WebDAV 配置无效异常
class WebDavConfigInvalidException implements Exception {
  @override
  String toString() => 'WebDAV 配置无效或未设置';
}

/// WebDAV 同步取消异常
class WebDavSyncCancelledException implements Exception {
  @override
  String toString() => '同步操作已被取消';
}
