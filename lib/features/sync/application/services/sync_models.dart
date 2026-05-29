import 'package:path/path.dart' as p;

class WebDavFileInfo {
  final DateTime modified;

  WebDavFileInfo({required this.modified});
}

class WebDavConfig {
  final String baseUrl;
  final String username;
  final String password;
  final String remotePath;

  WebDavConfig({
    required this.baseUrl,
    required this.username,
    required this.password,
    required this.remotePath,
  });

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

  bool get isValid {
    return baseUrl.isNotEmpty &&
        username.isNotEmpty &&
        password.isNotEmpty &&
        remotePath.isNotEmpty;
  }

  String get serverName {
    try {
      final uri = Uri.parse(baseUrl);
      return uri.host;
    } catch (e) {
      return baseUrl;
    }
  }
}

enum SyncStatus { idle, syncing, success, failed, conflict }

enum SyncDataType {
  readingProgress('reading_progress.json', '阅读进度'),
  bookmarks('bookmarks.json', '书签'),
  bookshelf('bookshelf.json', '书架'),
  settings('settings.json', '设置');

  final String filename;
  final String displayName;
  const SyncDataType(this.filename, this.displayName);
}

enum SyncDirection { upload, download, both }

enum SyncOperation { create, update, delete }

enum ConflictResolution { useLocal, useRemote, merge }

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

  bool get needsSync =>
      hasLocal != hasRemote || localModified != remoteModified;

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

  factory RemoteFileInfo.fromWebDavFile(dynamic file) {
    return RemoteFileInfo(
      name: (file.name as String?) ?? p.basename((file.path as String?) ?? ''),
      size: (file.size as int?) ?? 0,
      modified: (file.modified as DateTime?) ?? DateTime(1970),
      isDirectory: (file.type as String?) == 'directory',
    );
  }

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

class SyncResult {
  bool success;
  int uploadedCount;
  int downloadedCount;
  int conflictCount;
  String? error;
  Map<SyncDataType, SyncOperationResult> details;

  SyncResult({
    this.success = false,
    this.uploadedCount = 0,
    this.downloadedCount = 0,
    this.conflictCount = 0,
    this.error,
    Map<SyncDataType, SyncOperationResult>? details,
  }) : details = details ?? {};

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

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'uploadedCount': uploadedCount,
      'downloadedCount': downloadedCount,
      'conflictCount': conflictCount,
      'error': error,
    };
  }

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

enum SyncEventType {
  started,
  progress,
  conflict,
  conflictResolved,
  completed,
  failed,
  cancelled,
  recovered,
}

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

  String get description {
    final localTime = _formatTime(localModified);
    final remoteTime = _formatTime(remoteModified);
    return '${dataType.name}: 本地 ($localTime)  vs 远程 ($remoteTime)';
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

class SyncHistoryRecord {
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
  final String id;
  final DateTime startTime;
  final DateTime endTime;
  final SyncDirection direction;
  final SyncResult result;
  final int uploadedBytes;
  final int downloadedBytes;
  final List<String> changedFiles;
  final String? errorMessage;

  int get uploadedCount => result.uploadedCount;
  int get downloadedCount => result.downloadedCount;
  Duration get duration => endTime.difference(startTime);

  String get formattedDuration {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    if (minutes > 0) {
      return '$minutes 分 $seconds 秒';
    }
    return '$seconds 秒';
  }

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
}

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

class BackupInfo {
  BackupInfo({
    required this.id,
    required this.timestamp,
    required this.filePath,
    required this.fileSize,
    required this.includedDataTypes,
    this.note,
  });
  final String id;
  final DateTime timestamp;
  final String filePath;
  final int fileSize;
  final List<String> includedDataTypes;
  final String? note;

  String get formattedTime {
    return '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')} '
        '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
  }

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

class WebDavPreset {
  final String name;
  final String baseUrl;
  final String remotePath;
  final String helpUrl;

  WebDavPreset({
    required this.name,
    required this.baseUrl,
    required this.remotePath,
    required this.helpUrl,
  });
}
