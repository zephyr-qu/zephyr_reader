import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:injectable/injectable.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;

import 'sync_models.dart';

/// WebDAV 同步服务 —— 负责连接管理、文件传输和核心同步循环。
@lazySingleton
class WebDavSyncService {
  WebDavConfig? _config;
  webdav.Client? _client;
  CancelToken? _cancelToken;

  // ── 状态信号 ──

  final syncStatus = signal<SyncStatus>(SyncStatus.idle);
  final syncProgress = signal<double>(0.0);
  final syncMessage = signal<String>('');

  // ── 常量 ──

  static const String dataDirName = 'data';
  static const String syncSubDirName = 'zephyr_reader';

  // ── 构造 ──

  WebDavSyncService();

  void setConfig(WebDavConfig config) {
    _config = config;
    _invalidateConnection();
  }

  WebDavConfig? get config => _config;

  // ================================================================
  //  核心同步
  // ================================================================

  Future<SyncResult> syncAll({
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
    syncMessage.value = '开始同步...';

    final result = SyncResult();

    try {
      await _getConnectedClient();

      final remoteDir = p.join(_config!.remotePath, syncSubDirName);
      if (!await _ensureRemoteDirectory(remoteDir)) {
        syncStatus.value = SyncStatus.failed;
        return SyncResult(success: false, error: '无法创建远程目录');
      }
      syncProgress.value = 5.0;

      final dataTypes = SyncDataType.values;
      final totalSteps = dataTypes.length;

      for (var i = 0; i < totalSteps; i++) {
        if (_cancelToken != null && _cancelToken!.isCancelled) {
          syncMessage.value = '同步已取消';
          syncStatus.value = SyncStatus.idle;
          return SyncResult(success: false, error: '同步已取消');
        }

        final dataType = dataTypes[i];
        syncMessage.value = '同步${dataType.displayName}...';

        final localFile = await _getLocalFile(dataType);
        final remotePath = _getRemotePath(dataType);

        final stepProgress = (i / totalSteps) * 90;
        syncProgress.value = 5.0 + stepProgress;
        onProgress?.call(syncProgress.value / 100);

        final opResult = await _syncDataType(
          dataType,
          direction,
          localFile,
          remotePath,
        );

        if (opResult.$1) {
          if (direction == SyncDirection.upload ||
              direction == SyncDirection.both) {
            result.uploadedCount++;
          }
          if (direction == SyncDirection.download ||
              direction == SyncDirection.both) {
            result.downloadedCount++;
          }
        } else {
          result.error = opResult.$2;
        }
      }

      syncProgress.value = 100.0;
      syncStatus.value = SyncStatus.success;
      syncMessage.value = '同步完成';
      result.success = result.error == null;
      return result;
    } catch (e) {
      syncStatus.value = SyncStatus.failed;
      syncMessage.value = '同步失败';
      return SyncResult(success: false, error: '同步异常，请检查网络或服务器配置');
    }
  }

  // ================================================================
  //  单类型同步 —— 简单时间戳比对
  // ================================================================

  Future<(bool ok, String? error)> _syncDataType(
    SyncDataType type,
    SyncDirection direction,
    File localFile,
    String remotePath,
  ) async {
    try {
      final localExists = await localFile.exists();
      final remoteExists = await _fileExists(remotePath);

      if (!localExists && !remoteExists) {
        return (true, null);
      }

      if (localExists && !remoteExists) {
        // 仅本地有 → 上传
        if (direction == SyncDirection.upload ||
            direction == SyncDirection.both) {
          final ok = await _uploadFile(
            localFile: localFile,
            remotePath: remotePath,
          );
          return ok ? (true, null) : (false, '上传 ${type.displayName} 失败');
        }
        return (true, null);
      }

      if (!localExists && remoteExists) {
        // 仅远程有 → 下载
        if (direction == SyncDirection.download ||
            direction == SyncDirection.both) {
          final ok = await _downloadFile(
            remotePath: remotePath,
            localFile: localFile,
          );
          return ok ? (true, null) : (false, '下载 ${type.displayName} 失败');
        }
        return (true, null);
      }

      // 都存在 → 上传本地到远程（本地优先）
      if (direction == SyncDirection.upload ||
          direction == SyncDirection.both) {
        final ok = await _uploadFile(
          localFile: localFile,
          remotePath: remotePath,
        );
        return ok ? (true, null) : (false, '上传 ${type.displayName} 失败');
      }
      if (direction == SyncDirection.download) {
        // 仅下载方向时，远程已有且本地也有 → 跳过
        return (true, null);
      }

      return (true, null);
    } catch (e) {
      return (false, '${type.displayName} 同步异常');
    }
  }

  // ================================================================
  //  连接管理
  // ================================================================

  Future<webdav.Client> _getConnectedClient() async {
    if (_client != null) return _client!;

    final config = _config!;
    final baseUrl = config.baseUrl.endsWith('/')
        ? config.baseUrl
        : '${config.baseUrl}/';
    // Copy password into erasable buffer to minimize heap lifetime
    final passwordBytes = Uint8List.fromList(config.password.codeUnits);
    _client = webdav.newClient(
      baseUrl,
      user: config.username,
      password: String.fromCharCodes(passwordBytes),
      debug: kDebugMode,
    );
    // Clear sensitive data from native memory
    passwordBytes.fillRange(0, passwordBytes.length, 0);
    config.clearPassword();
    return _client!;
  }

  void _invalidateConnection() {
    _client = null;
  }

  // ================================================================
  //  文件操作（内联自原 webdav_file_transfer.dart）
  // ================================================================

  Future<bool> _ensureRemoteDirectory(String remoteDir) async {
    try {
      await _client!.mkdirAll(remoteDir, _cancelToken);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _uploadFile({
    required File localFile,
    required String remotePath,
  }) async {
    try {
      if (!await localFile.exists()) return false;

      await _client!.writeFromFile(
        localFile.path,
        remotePath,
        cancelToken: _cancelToken,
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _downloadFile({
    required String remotePath,
    required File localFile,
  }) async {
    try {
      await _client!.read2File(
        remotePath,
        localFile.path,
        cancelToken: _cancelToken,
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Check if remote file exists using PROPFIND on single path (not readDir).
  Future<bool> _fileExists(String remotePath) async {
    try {
      if (_client == null) return false;
      await _client!.readProps(remotePath);
      return true;
    } catch (e) {
      return false;
    }
  }

  // ================================================================
  //  取消 / 释放
  // ================================================================

  void cancelSync() {
    if (_cancelToken != null && !_cancelToken!.isCancelled) {
      _cancelToken!.cancel('用户取消同步');
      syncMessage.value = '同步已取消';
      syncStatus.value = SyncStatus.idle;
    }
  }

  void dispose() {
    cancelSync();
    _invalidateConnection();
  }

  // ================================================================
  //  内部辅助
  // ================================================================

  Future<File> _getLocalFile(SyncDataType type) async {
    final appDir = await getApplicationDocumentsDirectory();
    return File(p.join(appDir.path, dataDirName, type.filename));
  }

  String _getRemotePath(SyncDataType type) {
    return p.join(_config!.remotePath, syncSubDirName, type.filename);
  }
}
