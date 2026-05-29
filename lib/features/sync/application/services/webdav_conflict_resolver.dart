import 'dart:convert';
import 'dart:io';

import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/features/sync/application/services/webdav_client_service.dart';

import 'sync_models.dart';

class WebdavConflictResolver {
  final WebDavClientService Function() getClient;
  final String Function() getRemotePath;
  final void Function(SyncEvent) emitEvent;
  final Signal<List<ConflictInfo>> conflicts;
  final Future<bool> Function({
    required File localFile,
    required String remotePath,
    void Function(double progress)? onProgress,
  })
  uploadFile;
  final Future<bool> Function({
    required String remotePath,
    required File localFile,
    void Function(double progress)? onProgress,
  })
  downloadFile;
  final Future<WebDavFileInfo?> Function(String remotePath) getFileInfo;
  final Future<bool> Function(String remotePath) fileExists;

  WebdavConflictResolver({
    required this.getClient,
    required this.getRemotePath,
    required this.emitEvent,
    required this.conflicts,
    required this.uploadFile,
    required this.downloadFile,
    required this.getFileInfo,
    required this.fileExists,
  });

  Future<ConflictInfo?> checkConflict(
    File localFile,
    String remotePath,
    SyncDataType type,
  ) async {
    try {
      final localStat = await localFile.stat();
      final localModified = localStat.modified;

      final remoteInfo = await getFileInfo(remotePath);
      if (remoteInfo == null) return null;

      final remoteModified = remoteInfo.modified;

      if ((localModified.difference(remoteModified)).inSeconds.abs() <= 1) {
        return null;
      }

      final localContent = await localFile.readAsString();
      final remoteContent = await _readRemoteFile(remotePath);

      if (localContent == remoteContent) {
        return null;
      }

      return ConflictInfo(
        dataType: type,
        localModified: localModified,
        remoteModified: remoteModified,
        localPreview: generatePreview(localContent),
        remotePreview: generatePreview(remoteContent),
        autoResolution: determineAutoResolution(
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

  Future<SyncOperationResult> resolveConflict(
    SyncDataType type,
    ConflictResolution resolution,
    File localFile,
    String remotePath, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      switch (resolution) {
        case ConflictResolution.useLocal:
          if (await localFile.exists()) {
            await uploadFile(
              localFile: localFile,
              remotePath: remotePath,
              onProgress: onProgress,
            );
          }
        case ConflictResolution.useRemote:
          await downloadFile(
            remotePath: remotePath,
            localFile: localFile,
            onProgress: onProgress,
          );
        case ConflictResolution.merge:
          await _mergeData(type, localFile, remotePath);
      }

      return SyncOperationResult.success();
    } catch (e) {
      return SyncOperationResult.failure('解决冲突失败：$e');
    }
  }

  static String generatePreview(String content) {
    try {
      final json = jsonDecode(content);
      if (json is Map) {
        final keys = json.keys.take(3).join(', ');
        return 'JSON 对象：{$keys, ...}';
      } else if (json is List) {
        return 'JSON 数组：${json.length} 项';
      }
      return json.toString();
    } catch (e) {
      return content.length > 50 ? '${content.substring(0, 50)}...' : content;
    }
  }

  static ConflictResolution? determineAutoResolution(
    DateTime localModified,
    DateTime remoteModified,
    SyncDataType type,
  ) {
    if (type == SyncDataType.settings) {
      return ConflictResolution.useLocal;
    }

    if (type == SyncDataType.readingProgress ||
        type == SyncDataType.bookmarks) {
      return localModified.isAfter(remoteModified)
          ? ConflictResolution.useLocal
          : ConflictResolution.useRemote;
    }

    if (type == SyncDataType.bookshelf) {
      return localModified.isAfter(remoteModified)
          ? ConflictResolution.useLocal
          : ConflictResolution.useRemote;
    }

    return null;
  }

  static Map<String, dynamic> deepMergeMaps(
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
  ) {
    final result = Map<String, dynamic>.from(local);

    for (final entry in remote.entries) {
      if (result.containsKey(entry.key)) {
        if (result[entry.key] is Map && entry.value is Map) {
          result[entry.key] = deepMergeMaps(
            Map<String, dynamic>.from(result[entry.key] as Map),
            Map<String, dynamic>.from(entry.value as Map),
          );
        } else if (result[entry.key] is List && entry.value is List) {
          result[entry.key] = mergeLists(
            result[entry.key] as List,
            entry.value as List,
          );
        } else {
          result[entry.key] = entry.value;
        }
      } else {
        result[entry.key] = entry.value;
      }
    }

    return result;
  }

  static List<dynamic> mergeLists(List<dynamic> local, List<dynamic> remote) {
    final result = List<dynamic>.from(local);

    for (final item in remote) {
      if (!result.any((r) => _deepEquals(r, item))) {
        result.add(item);
      }
    }

    return result;
  }

  static bool _deepEquals(dynamic a, dynamic b) {
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

  Future<void> _mergeData(
    SyncDataType type,
    File localFile,
    String remotePath,
  ) async {
    try {
      final localContent = await localFile.readAsString();
      final remoteContent = await _readRemoteFile(remotePath);

      dynamic localData;
      dynamic remoteData;

      try {
        localData = jsonDecode(localContent);
      } catch (e) {
        localData = <String, dynamic>{};
      }

      try {
        remoteData = jsonDecode(remoteContent);
      } catch (e) {
        remoteData = <String, dynamic>{};
      }

      dynamic mergedData;

      if (localData is Map && remoteData is Map) {
        mergedData = deepMergeMaps(
          Map<String, dynamic>.from(localData),
          Map<String, dynamic>.from(remoteData),
        );
      } else if (localData is List && remoteData is List) {
        mergedData = mergeLists(localData, remoteData);
      } else {
        final localStat = await localFile.stat();
        final remoteInfo = await getFileInfo(remotePath);
        mergedData = localStat.modified.isAfter(remoteInfo!.modified)
            ? localData
            : remoteData;
      }

      await localFile.writeAsString(jsonEncode(mergedData), flush: true);
      await uploadFile(localFile: localFile, remotePath: remotePath);
    } catch (e) {
      Logging.error('合并数据失败：$e');
      rethrow;
    }
  }

  Future<String> _readRemoteFile(String remotePath) async {
    try {
      final bytes = await getClient().read(remotePath);
      return String.fromCharCodes(bytes);
    } catch (e) {
      throw Exception('读取远程文件失败：$e');
    }
  }
}
