/// WebDAV 同步服务
///
/// 提供WebDAV 服务器的数据同步功能
///
/// 功能/// - 连接测试
/// - 账号认证
/// - 文件上传/下载
/// - 数据同步（进度、书签、书架）
/// - 冲突解决
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:signals_flutter/signals_flutter.dart';

/// WebDAV 配置
class WebDavConfig {
  /// 服务器地址
  final String baseUrl;

  /// 用户
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

  /// 获取基础认证
  String get authHeader {
    final credentials = base64Encode(utf8.encode('$username:$password'));
    return 'Basic $credentials';
  }

  /// 复制并修改配
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

  /// 验证配置完整
  bool get isValid {
    return baseUrl.isNotEmpty &&
        username.isNotEmpty &&
        password.isNotEmpty &&
        remotePath.isNotEmpty;
  }
}

/// 同步状
enum SyncStatus {
  /// 空闲
  idle,

  /// 同步
  syncing,

  /// 同步成功
  success,

  /// 同步失败
  failed,

  /// 冲突需要解
  conflict,
}

/// 同步数据类型
enum SyncDataType {
  /// 阅读进度
  readingProgress,

  /// 书签
  bookmarks,

  /// 书架
  bookshelf,

  /// 设置
  settings,
}

/// 同步方向
enum SyncDirection {
  /// 仅上
  upload,

  /// 仅下
  download,

  /// 双向同步
  both,
}

/// 数据同步
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
}

/// WebDAV 同步服务
class WebDavSyncService {
  WebDavConfig? _config;
  final http.Client _client;

  /// 当前同步状
  final syncStatus = signal<SyncStatus>(SyncStatus.idle);

  /// 同步进度-100
  final syncProgress = signal<double>(0.0);

  /// 最后同步时
  final lastSyncTime = signal<DateTime?>(null);

  /// 错误信息
  final errorMessage = signal<String?>(null);

  /// 同步状态详
  final syncMessage = signal<String>('');

  WebDavSyncService({WebDavConfig? config, http.Client? client})
    : _config = config,
      _client = client ?? http.Client();

  /// 设置配置
  void setConfig(WebDavConfig config) {
    _config = config;
  }

  /// 获取配置
  WebDavConfig? get config => _config;

  /// 测试连接
  Future<bool> testConnection() async {
    if (_config == null || !_config!.isValid) {
      debugPrint('WebDAV 配置未设置或无效');
      return false;
    }

    try {
      final url = Uri.parse('${_config!.baseUrl}${_config!.remotePath}');
      final response = await _client
          .get(url, headers: {'Authorization': _config!.authHeader})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 ||
          response.statusCode == 404 ||
          response.statusCode == 207) {
        debugPrint('WebDAV 连接测试成功');
        return true;
      } else if (response.statusCode == 401) {
        debugPrint('WebDAV 认证失败：请检查用户名和密');
        errorMessage.value = '认证失败：请检查用户名和密';
        return false;
      } else {
        debugPrint('WebDAV 连接测试失败{response.statusCode}');
        errorMessage.value = '连接失败{response.statusCode}';
        return false;
      }
    } catch (e) {
      debugPrint('WebDAV 连接测试异常e');
      errorMessage.value = '连接异常e';
      return false;
    }
  }

  /// 同步所有数
  Future<SyncResult> syncAll({
    SyncDirection direction = SyncDirection.both,
  }) async {
    if (_config == null || !_config!.isValid) {
      return SyncResult(success: false, error: 'WebDAV 配置未设');
    }

    syncStatus.value = SyncStatus.syncing;
    syncProgress.value = 0.0;
    syncMessage.value = '开始同..';

    final result = SyncResult();

    try {
      // 确保远程目录存在
      await _ensureRemoteDirectory();

      // 同步阅读进度
      syncMessage.value = '同步阅读进度...';
      final progressResult = await _syncReadingProgress(direction);
      result.uploadedCount += progressResult.uploadedCount;
      result.downloadedCount += progressResult.downloadedCount;
      result.conflictCount += progressResult.conflictCount;
      syncProgress.value = 25.0;

      // 同步书签
      syncMessage.value = '同步书签...';
      final bookmarkResult = await _syncBookmarks(direction);
      result.uploadedCount += bookmarkResult.uploadedCount;
      result.downloadedCount += bookmarkResult.downloadedCount;
      result.conflictCount += bookmarkResult.conflictCount;
      syncProgress.value = 50.0;

      // 同步书架
      syncMessage.value = '同步书架...';
      final bookshelfResult = await _syncBookshelf(direction);
      result.uploadedCount += bookshelfResult.uploadedCount;
      result.downloadedCount += bookshelfResult.downloadedCount;
      result.conflictCount += bookshelfResult.conflictCount;
      syncProgress.value = 75.0;

      // 同步设置
      syncMessage.value = '同步设置...';
      final settingsResult = await _syncSettings(direction);
      result.uploadedCount += settingsResult.uploadedCount;
      result.downloadedCount += settingsResult.downloadedCount;
      result.conflictCount += settingsResult.conflictCount;
      syncProgress.value = 100.0;

      syncStatus.value = SyncStatus.success;
      lastSyncTime.value = DateTime.now();
      syncMessage.value = '同步完成';

      result.success = result.conflictCount == 0;
      return result;
    } catch (e) {
      debugPrint('同步异常e');
      syncStatus.value = SyncStatus.failed;
      errorMessage.value = '同步异常e';
      syncMessage.value = '同步失败';
      return SyncResult(success: false, error: e.toString());
    }
  }

  /// 确保远程目录存在
  Future<bool> _ensureRemoteDirectory() async {
    try {
      final url = Uri.parse('${_config!.baseUrl}${_config!.remotePath}');
      final response = await _client.get(
        url,
        headers: {'Authorization': _config!.authHeader},
      );

      // 如果目录不存在（404），尝试创建
      if (response.statusCode == 404) {
        final createResponse = await _client.put(
          url,
          headers: {'Authorization': _config!.authHeader},
        );

        if (createResponse.statusCode == 200 ||
            createResponse.statusCode == 201) {
          debugPrint('远程目录创建成功');
          return true;
        } else {
          debugPrint('远程目录创建失败{createResponse.statusCode}');
          return false;
        }
      }

      return response.statusCode == 200 || response.statusCode == 207;
    } catch (e) {
      debugPrint('检查远程目录异常：$e');
      return false;
    }
  }

  /// 同步阅读进度
  Future<SyncResult> _syncReadingProgress(SyncDirection direction) async {
    final result = SyncResult();
    final appDir = await getApplicationDocumentsDirectory();
    final localFile = File(
      p.join(appDir.path, 'data', 'reading_progress.json'),
    );

    try {
      if (direction == SyncDirection.upload ||
          direction == SyncDirection.both) {
        if (await localFile.exists()) {
          final remoteName = 'reading_progress.json';
          if (await uploadFile(
            localPath: localFile.path,
            remoteName: remoteName,
          )) {
            result.uploadedCount++;
          }
        }
      }

      if (direction == SyncDirection.download ||
          direction == SyncDirection.both) {
        final remoteName = 'reading_progress.json';
        if (await downloadFile(
          remoteName: remoteName,
          localPath: localFile.path,
        )) {
          result.downloadedCount++;
        }
      }
    } catch (e) {
      debugPrint('同步阅读进度异常e');
    }

    return result;
  }

  /// 同步书签
  Future<SyncResult> _syncBookmarks(SyncDirection direction) async {
    final result = SyncResult();
    final appDir = await getApplicationDocumentsDirectory();
    final localFile = File(p.join(appDir.path, 'data', 'bookmarks.json'));

    try {
      if (direction == SyncDirection.upload ||
          direction == SyncDirection.both) {
        if (await localFile.exists()) {
          final remoteName = 'bookmarks.json';
          if (await uploadFile(
            localPath: localFile.path,
            remoteName: remoteName,
          )) {
            result.uploadedCount++;
          }
        }
      }

      if (direction == SyncDirection.download ||
          direction == SyncDirection.both) {
        final remoteName = 'bookmarks.json';
        if (await downloadFile(
          remoteName: remoteName,
          localPath: localFile.path,
        )) {
          result.downloadedCount++;
        }
      }
    } catch (e) {
      debugPrint('同步书签异常e');
    }

    return result;
  }

  /// 同步书架
  Future<SyncResult> _syncBookshelf(SyncDirection direction) async {
    final result = SyncResult();
    final appDir = await getApplicationDocumentsDirectory();
    final localFile = File(p.join(appDir.path, 'data', 'bookshelf.json'));

    try {
      if (direction == SyncDirection.upload ||
          direction == SyncDirection.both) {
        if (await localFile.exists()) {
          final remoteName = 'bookshelf.json';
          if (await uploadFile(
            localPath: localFile.path,
            remoteName: remoteName,
          )) {
            result.uploadedCount++;
          }
        }
      }

      if (direction == SyncDirection.download ||
          direction == SyncDirection.both) {
        final remoteName = 'bookshelf.json';
        if (await downloadFile(
          remoteName: remoteName,
          localPath: localFile.path,
        )) {
          result.downloadedCount++;
        }
      }
    } catch (e) {
      debugPrint('同步书架异常e');
    }

    return result;
  }

  /// 同步设置
  Future<SyncResult> _syncSettings(SyncDirection direction) async {
    final result = SyncResult();
    final appDir = await getApplicationDocumentsDirectory();
    final localFile = File(p.join(appDir.path, 'data', 'settings.json'));

    try {
      if (direction == SyncDirection.upload ||
          direction == SyncDirection.both) {
        if (await localFile.exists()) {
          final remoteName = 'settings.json';
          if (await uploadFile(
            localPath: localFile.path,
            remoteName: remoteName,
          )) {
            result.uploadedCount++;
          }
        }
      }

      if (direction == SyncDirection.download ||
          direction == SyncDirection.both) {
        final remoteName = 'settings.json';
        if (await downloadFile(
          remoteName: remoteName,
          localPath: localFile.path,
        )) {
          result.downloadedCount++;
        }
      }
    } catch (e) {
      debugPrint('同步设置异常e');
    }

    return result;
  }

  /// 上传文件
  Future<bool> uploadFile({
    required String localPath,
    required String remoteName,
  }) async {
    if (_config == null) {
      debugPrint('WebDAV 配置未设');
      return false;
    }

    try {
      final file = File(localPath);
      if (!await file.exists()) {
        debugPrint('文件不存在：$localPath');
        return false;
      }

      final fileBytes = await file.readAsBytes();
      final url = Uri.parse(
        '${_config!.baseUrl}${_config!.remotePath}/$remoteName',
      );

      final response = await _client.put(
        url,
        headers: {
          'Authorization': _config!.authHeader,
          'Content-Type': 'application/octet-stream',
        },
        body: fileBytes,
      );

      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 204) {
        debugPrint('文件上传成功remoteName');
        return true;
      } else {
        debugPrint('文件上传失败{response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('文件上传异常e');
      return false;
    }
  }

  /// 下载文件
  Future<bool> downloadFile({
    required String remoteName,
    required String localPath,
  }) async {
    if (_config == null) {
      debugPrint('WebDAV 配置未设');
      return false;
    }

    try {
      final url = Uri.parse(
        '${_config!.baseUrl}${_config!.remotePath}/$remoteName',
      );

      final response = await _client.get(
        url,
        headers: {'Authorization': _config!.authHeader},
      );

      if (response.statusCode == 200) {
        final file = File(localPath);
        await file.parent.create(recursive: true);
        await file.writeAsBytes(response.bodyBytes);

        debugPrint('文件下载成功remoteName');
        return true;
      } else if (response.statusCode == 404) {
        debugPrint('文件不存在于服务器：$remoteName');
        return false;
      } else {
        debugPrint('文件下载失败{response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('文件下载异常e');
      return false;
    }
  }

  /// 列出远程文件
  Future<List<RemoteFileInfo>> listRemoteFiles() async {
    if (_config == null) {
      debugPrint('WebDAV 配置未设');
      return [];
    }

    try {
      final url = Uri.parse('${_config!.baseUrl}${_config!.remotePath}');

      final response = await _client.get(
        url,
        headers: {'Authorization': _config!.authHeader},
      );

      if (response.statusCode == 200) {
        // 简单解析响
        final files = <RemoteFileInfo>[];
        // TODO: 解析 XML 响应获取文件列表
        return files;
      } else {
        debugPrint('列出文件失败{response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('列出文件异常e');
      return [];
    }
  }

  /// 删除远程文件
  Future<bool> deleteRemoteFile(String remoteName) async {
    if (_config == null) {
      return false;
    }

    try {
      final url = Uri.parse(
        '${_config!.baseUrl}${_config!.remotePath}/$remoteName',
      );

      final response = await _client.delete(
        url,
        headers: {'Authorization': _config!.authHeader},
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        debugPrint('文件删除成功remoteName');
        return true;
      } else {
        debugPrint('文件删除失败{response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('文件删除异常e');
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
          // 使用本地版本覆盖远程
          await _uploadData(type);
          break;
        case ConflictResolution.useRemote:
          // 使用远程版本覆盖本地
          await _downloadData(type);
          break;
        case ConflictResolution.merge:
          // 合并两个版本（需要实现合并逻辑
          await _mergeData(type);
          break;
      }
      return true;
    } catch (e) {
      debugPrint('解决冲突异常e');
      return false;
    }
  }

  Future<void> _uploadData(SyncDataType type) async {
    // 实现数据上传逻辑
  }

  Future<void> _downloadData(SyncDataType type) async {
    // 实现数据下载逻辑
  }

  Future<void> _mergeData(SyncDataType type) async {
    // 实现数据合并逻辑
  }

  /// 释放资源
  void dispose() {
    _client.close();
  }
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

  SyncResult({
    this.success = false,
    this.uploadedCount = 0,
    this.downloadedCount = 0,
    this.conflictCount = 0,
    this.error,
  });

  SyncResult copyWith({
    bool? success,
    int? uploadedCount,
    int? downloadedCount,
    int? conflictCount,
    String? error,
  }) {
    return SyncResult(
      success: success ?? this.success,
      uploadedCount: uploadedCount ?? this.uploadedCount,
      downloadedCount: downloadedCount ?? this.downloadedCount,
      conflictCount: conflictCount ?? this.conflictCount,
      error: error ?? this.error,
    );
  }
}
