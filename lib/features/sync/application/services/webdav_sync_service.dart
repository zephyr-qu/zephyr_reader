library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;
import 'package:zephyr_reader/core/battery/battery_state_service.dart';
import 'package:zephyr_reader/core/network/network_state_service.dart';
import 'package:zephyr_reader/core/utils/logging.dart';

import 'webdav_connection_manager.dart';

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
  readingProgress('reading_progress.json'),
  bookmarks('bookmarks.json'),
  bookshelf('bookshelf.json'),
  settings('settings.json');

  final String filename;
  const SyncDataType(this.filename);
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

class WebDavNotInitializedException implements Exception {
  WebDavNotInitializedException();

  @override
  String toString() => 'WebDAV 客户端未初始化，请先调用 init() 方法';
}

class WebDavUnauthorizedException implements Exception {
  final String message;

  WebDavUnauthorizedException([this.message = '认证失败，请检查用户名和密码']);

  @override
  String toString() => 'WebDAV 认证失败：$message';
}

class WebDavFileNotFoundException implements Exception {
  final String path;

  WebDavFileNotFoundException(this.path);

  @override
  String toString() => 'WebDAV 文件不存在：$path';
}

class WebDavPermissionDeniedException implements Exception {
  final String path;

  WebDavPermissionDeniedException(this.path);

  @override
  String toString() => 'WebDAV 权限不足，无法访问：$path';
}

class WebDavConfigInvalidException implements Exception {
  @override
  String toString() => 'WebDAV 配置无效或未设置';
}

class WebDavSyncCancelledException implements Exception {
  @override
  String toString() => '同步操作已被取消';
}

class WebDavClientService {
  webdav.Client? _client;
  String? _baseUrl;
  String? _username;
  bool _isDebug = false;

  Future<void> init({
    required String baseUrl,
    required String username,
    required String password,
    bool debug = false,
  }) async {
    try {
      _baseUrl = baseUrl;
      _username = username;
      _isDebug = debug;

      if (!baseUrl.endsWith('/')) {
        baseUrl = '$baseUrl/';
      }

      _client = webdav.newClient(
        baseUrl,
        user: username,
        password: password,
        debug: debug,
      );

      await ping();

      if (_isDebug) {
        debugPrint('WebDAV 客户端初始化成功：$baseUrl');
      }
    } catch (e) {
      debugPrint('WebDAV 客户端初始化失败：$e');
      rethrow;
    }
  }

  Future<bool> ping() async {
    try {
      if (_client == null) {
        throw WebDavNotInitializedException();
      }
      await _client!.ping();
      return true;
    } catch (e) {
      if (_isDebug) {
        debugPrint('WebDAV ping 失败：$e');
      }
      return false;
    }
  }

  void setHeaders(Map<String, String> headers) {
    _checkInitialized();
    _client!.setHeaders(headers);
  }

  void setConnectTimeout(int milliseconds) {
    _checkInitialized();
    _client!.setConnectTimeout(milliseconds);
  }

  void setSendTimeout(int milliseconds) {
    _checkInitialized();
    _client!.setSendTimeout(milliseconds);
  }

  void setReceiveTimeout(int milliseconds) {
    _checkInitialized();
    _client!.setReceiveTimeout(milliseconds);
  }

  Future<List<dynamic>> readDir(String path) async {
    try {
      _checkInitialized();
      return await _client!.readDir(path);
    } catch (e) {
      debugPrint('WebDAV readDir 失败：$e');
      rethrow;
    }
  }

  Future<void> mkdir(String path, {CancelToken? cancelToken}) async {
    try {
      _checkInitialized();
      await _client!.mkdir(path, cancelToken);
    } catch (e) {
      debugPrint('WebDAV mkdir 失败：$e');
      rethrow;
    }
  }

  Future<void> mkdirAll(String path, {CancelToken? cancelToken}) async {
    try {
      _checkInitialized();
      await _client!.mkdirAll(path, cancelToken);
    } catch (e) {
      debugPrint('WebDAV mkdirAll 失败：$e');
      rethrow;
    }
  }

  Future<void> remove(String path, {CancelToken? cancelToken}) async {
    try {
      _checkInitialized();
      await _client!.remove(path, cancelToken);
    } catch (e) {
      debugPrint('WebDAV remove 失败：$e');
      rethrow;
    }
  }

  Future<void> rename(
    String oldPath,
    String newPath,
    bool overwrite, {
    CancelToken? cancelToken,
  }) async {
    try {
      _checkInitialized();
      await _client!.rename(oldPath, newPath, overwrite, cancelToken);
    } catch (e) {
      debugPrint('WebDAV rename 失败：$e');
      rethrow;
    }
  }

  Future<void> copy(
    String sourcePath,
    String destPath,
    bool overwrite, {
    CancelToken? cancelToken,
  }) async {
    try {
      _checkInitialized();
      await _client!.copy(sourcePath, destPath, overwrite, cancelToken);
    } catch (e) {
      debugPrint('WebDAV copy 失败：$e');
      rethrow;
    }
  }

  Future<List<int>> read(
    String path, {
    void Function(int, int)? onProgress,
    CancelToken? cancelToken,
  }) async {
    try {
      _checkInitialized();
      return await _client!.read(
        path,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );
    } catch (e) {
      debugPrint('WebDAV read 失败：$e');
      rethrow;
    }
  }

  Future<void> read2File(
    String remotePath,
    String localPath, {
    void Function(int, int)? onProgress,
    CancelToken? cancelToken,
  }) async {
    try {
      _checkInitialized();
      await _client!.read2File(
        remotePath,
        localPath,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );
    } catch (e) {
      debugPrint('WebDAV read2File 失败：$e');
      rethrow;
    }
  }

  Future<void> writeFromFile(
    String localPath,
    String remotePath, {
    void Function(int, int)? onProgress,
    CancelToken? cancelToken,
  }) async {
    try {
      _checkInitialized();
      await _client!.writeFromFile(
        localPath,
        remotePath,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );
    } catch (e) {
      debugPrint('WebDAV writeFromFile 失败：$e');
      rethrow;
    }
  }

  Future<void> write(
    String remotePath,
    Uint8List data, {
    void Function(int, int)? onProgress,
    CancelToken? cancelToken,
  }) async {
    try {
      _checkInitialized();
      await _client!.write(
        remotePath,
        data,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );
    } catch (e) {
      debugPrint('WebDAV write 失败：$e');
      rethrow;
    }
  }

  bool get isInitialized => _client != null;

  webdav.Client? get client => _client;

  String? get baseUrl => _baseUrl;

  String? get username => _username;

  bool get isDebug => _isDebug;

  void dispose() {
    _client = null;
    _baseUrl = null;
    _username = null;
    _isDebug = false;
    if (kDebugMode) {
      debugPrint('WebDAV 客户端已断开连接');
    }
  }

  void _checkInitialized() {
    if (_client == null) {
      throw WebDavNotInitializedException();
    }
  }
}

class WebDavConfigService {
  final SharedPreferences _prefs;
  final FlutterSecureStorage _secureStorage;

  final isConfigured = signal(false);
  final autoSyncEnabled = signal(false);
  final autoSyncInterval = signal(30);

  WebDavConfigService({
    required SharedPreferences prefs,
    FlutterSecureStorage? secureStorage,
  }) : _prefs = prefs,
       _secureStorage = secureStorage ?? const FlutterSecureStorage() {
    _loadConfigStatus();
  }

  static const String _keyBaseUrl = 'webdav.base_url';
  static const String _keyUsername = 'webdav.username';
  static const String _keyPassword = 'webdav.password';
  static const String _keyRemotePath = 'webdav.remote_path';
  static const String _keyAutoSync = 'webdav.auto_sync';
  static const String _keySyncInterval = 'webdav.sync_interval';
  static const String _keyLastSyncTime = 'webdav.last_sync_time';

  void _loadConfigStatus() {
    final baseUrl = _prefs.getString(_keyBaseUrl);
    isConfigured.value = baseUrl != null && baseUrl.isNotEmpty;
    autoSyncEnabled.value = _prefs.getBool(_keyAutoSync) ?? false;
    autoSyncInterval.value = _prefs.getInt(_keySyncInterval) ?? 30;
  }

  Future<WebDavConfig?> getConfig() async {
    final baseUrl = _prefs.getString(_keyBaseUrl);
    final username = _prefs.getString(_keyUsername);
    final password = await _secureStorage.read(key: _keyPassword);
    final remotePath = _prefs.getString(_keyRemotePath);

    if (baseUrl == null ||
        baseUrl.isEmpty ||
        username == null ||
        username.isEmpty ||
        password == null ||
        password.isEmpty ||
        remotePath == null ||
        remotePath.isEmpty) {
      return null;
    }

    return WebDavConfig(
      baseUrl: baseUrl,
      username: username,
      password: password,
      remotePath: remotePath,
    );
  }

  Future<void> saveConfig(WebDavConfig config) async {
    await _prefs.setString(_keyBaseUrl, config.baseUrl);
    await _prefs.setString(_keyUsername, config.username);
    await _prefs.setString(_keyRemotePath, config.remotePath);
    await _secureStorage.write(key: _keyPassword, value: config.password);

    isConfigured.value = true;
    debugPrint('WebDAV 配置已保存');
  }

  Future<void> clearConfig() async {
    await _prefs.remove(_keyBaseUrl);
    await _prefs.remove(_keyUsername);
    await _prefs.remove(_keyRemotePath);
    await _secureStorage.delete(key: _keyPassword);

    isConfigured.value = false;
    debugPrint('WebDAV 配置已清除');
  }

  Future<void> setAutoSync({
    required bool enabled,
    int? intervalMinutes,
  }) async {
    await _prefs.setBool(_keyAutoSync, enabled);
    if (intervalMinutes != null) {
      await _prefs.setInt(_keySyncInterval, intervalMinutes);
      autoSyncInterval.value = intervalMinutes;
    }
    autoSyncEnabled.value = enabled;
  }

  Future<bool> testCurrentConfig() async {
    final config = await getConfig();
    if (config == null) return false;

    final connectionManager = WebdavConnectionManager(configService: this);
    return await connectionManager.testConnection(config);
  }

  Future<DateTime?> getLastSyncTime() async {
    final timestamp = _prefs.getInt(_keyLastSyncTime);
    if (timestamp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  Future<void> setLastSyncTime(DateTime time) async {
    await _prefs.setInt(_keyLastSyncTime, time.millisecondsSinceEpoch);
  }

  static List<WebDavPreset> getPresets() {
    return [
      WebDavPreset(
        name: '坚果云',
        baseUrl: 'https://dav.jianguoyun.com/dav',
        remotePath: '/zephyr_reader',
        helpUrl: 'https://help.jianguoyun.com',
      ),
      WebDavPreset(
        name: 'Nextcloud',
        baseUrl: 'https://your-domain.com/remote.php/dav/files',
        remotePath: '/zephyr_reader',
        helpUrl: 'https://nextcloud.com',
      ),
      WebDavPreset(
        name: 'ownCloud',
        baseUrl: 'https://your-domain.com/remote.php/dav/files',
        remotePath: '/zephyr_reader',
        helpUrl: 'https://owncloud.com',
      ),
      WebDavPreset(
        name: 'Seafile',
        baseUrl: 'https://your-domain.com/seafhttp',
        remotePath: '/zephyr_reader',
        helpUrl: 'https://www.seafile.com',
      ),
      WebDavPreset(
        name: '其他',
        baseUrl: '',
        remotePath: '/zephyr_reader',
        helpUrl: '',
      ),
    ];
  }
}

class WebDavSyncService {
  WebDavConfig? _config;
  WebdavConnectionManager? _connectionManagerParam;

  WebdavConnectionManager get _connectionManager =>
      _connectionManagerParam ??= WebdavConnectionManager(
        configService:
            WebDavConfigService(prefs: GetIt.I<SharedPreferences>()),
      );

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
  Timer? _syncTimer;

  static const String _dataDirName = 'data';
  static const String _syncSubDirName = 'zephyr_reader';
  static const String _backupDirName = 'backups';
  static const String _historyFile = 'sync_history.json';
  static const String _incrementalFile = 'sync_incremental.json';
  static const String _autoSyncConfigFile = 'auto_sync_config.json';
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
    _loadHistory();
    _loadAutoSyncConfig();
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
        final conflictInfo = await _checkConflict(localFile, remotePath, type);

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

            return await _resolveConflict(
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

  String _generatePreview(String content) {
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

  ConflictResolution? _determineAutoResolution(
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
          if (await localFile.exists()) {
            await _uploadFile(
              localFile: localFile,
              remotePath: remotePath,
              onProgress: onProgress,
            );
          }
          break;

        case ConflictResolution.useRemote:
          await _downloadFile(
            remotePath: remotePath,
            localFile: localFile,
            onProgress: onProgress,
          );
          break;

        case ConflictResolution.merge:
          await _mergeData(type, localFile, remotePath);
          break;
      }

      return SyncOperationResult.success();
    } catch (e) {
      return SyncOperationResult.failure('解决冲突失败：$e');
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
        mergedData = _deepMergeMaps(
          Map<String, dynamic>.from(localData),
          Map<String, dynamic>.from(remoteData),
        );
      } else if (localData is List && remoteData is List) {
        mergedData = _mergeLists(localData, remoteData);
      } else {
        final localStat = await localFile.stat();
        final remoteInfo = await _getFileInfo(remotePath);
        mergedData = localStat.modified.isAfter(remoteInfo!.modified)
            ? localData
            : remoteData;
      }

      await localFile.writeAsString(jsonEncode(mergedData), flush: true);
      await _uploadFile(localFile: localFile, remotePath: remotePath);
    } catch (e) {
      Logging.error('合并数据失败：$e');
      rethrow;
    }
  }

  Map<String, dynamic> _deepMergeMaps(
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
  ) {
    final result = Map<String, dynamic>.from(local);

    for (final entry in remote.entries) {
      if (result.containsKey(entry.key)) {
        if (result[entry.key] is Map && entry.value is Map) {
          result[entry.key] = _deepMergeMaps(
            Map<String, dynamic>.from(result[entry.key] as Map),
            Map<String, dynamic>.from(entry.value as Map),
          );
        } else if (result[entry.key] is List && entry.value is List) {
          result[entry.key] = _mergeLists(
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

  List<dynamic> _mergeLists(List<dynamic> local, List<dynamic> remote) {
    final result = List<dynamic>.from(local);

    for (final item in remote) {
      if (!result.any((r) => _deepEquals(r, item))) {
        result.add(item);
      }
    }

    return result;
  }

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

  Future<String> _readRemoteFile(String remotePath) async {
    try {
      final bytes = await _client!.read(remotePath);
      return String.fromCharCodes(bytes);
    } catch (e) {
      throw Exception('读取远程文件失败：$e');
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

        syncMessage.value = '同步${_getDataTypeName(dataType)}...';

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

    backups.value = [...backups.value, backupInfo];
    await _saveBackups();

    _emitEvent(SyncEvent(type: SyncEventType.completed, message: '备份创建成功'));

    return backupInfo;
  }

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
          orElse: () => SyncDataType.settings,
        );

        final localFile = await _getLocalFile(dataType);
        await localFile.parent.create(recursive: true);
        await localFile.writeAsString(entry.value as String, flush: true);
      }

      _emitEvent(SyncEvent(type: SyncEventType.completed, message: '备份恢复成功'));

      return true;
    } catch (e) {
      debugPrint('恢复备份异常：$e');
      _emitEvent(SyncEvent(type: SyncEventType.failed, message: '备份恢复失败：$e'));
      return false;
    }
  }

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

  void stopAutoSync() {
    _stopAutoSync();

    _emitEvent(SyncEvent(type: SyncEventType.cancelled, message: '定时同步已停止'));
  }

  void _stopAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  Future<void> _performAutoSync() async {
    final config = autoSyncConfig.value;
    if (!config.enabled || _config == null) {
      return;
    }

    if (config.onlyOnWifi) {
      final isWifi = await NetworkStateService().isOnWifi();
      if (!isWifi) {
        debugPrint('定时同步跳过：非 WiFi 网络');
        return;
      }
    }

    if (config.requireCharging) {
      final isCharging = await BatteryStateService().isCharging();
      if (!isCharging) {
        debugPrint('定时同步跳过：设备未充电');
        return;
      }
    }

    await syncIncremental(direction: config.direction);
  }

  Future<void> setAutoSyncConfig(AutoSyncConfig config) async {
    autoSyncConfig.value = config;
    await _saveAutoSyncConfig();

    if (config.enabled) {
      startAutoSync();
    } else {
      stopAutoSync();
    }
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

      final result = await _resolveConflict(
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
    _eventController.close();
    _connectionManager.disconnect();
    _client = null;
  }

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

class EnhancedWebDavSyncService extends WebDavSyncService {
  EnhancedWebDavSyncService({
    super.config,
    super.connectionManager,
    super.maxRetries,
    super.retryDelay,
  });
}

class AdvancedWebDavSyncService extends WebDavSyncService {
  AdvancedWebDavSyncService({super.config, super.connectionManager});
}
