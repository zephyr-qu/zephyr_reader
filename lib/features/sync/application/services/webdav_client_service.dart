import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;
import 'package:zephyr_reader/core/utils/logging.dart';

import 'sync_exceptions.dart';

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
        Logging.warning('WebDAV 客户端初始化成功：$baseUrl');
      }
    } catch (e) {
      Logging.error('WebDAV 客户端初始化失败：$e');
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
        Logging.error('WebDAV ping 失败：$e');
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
      Logging.error('WebDAV readDir 失败：$e');
      rethrow;
    }
  }

  Future<void> mkdir(String path, {CancelToken? cancelToken}) async {
    try {
      _checkInitialized();
      await _client!.mkdir(path, cancelToken);
    } catch (e) {
      Logging.error('WebDAV mkdir 失败：$e');
      rethrow;
    }
  }

  Future<void> mkdirAll(String path, {CancelToken? cancelToken}) async {
    try {
      _checkInitialized();
      await _client!.mkdirAll(path, cancelToken);
    } catch (e) {
      Logging.error('WebDAV mkdirAll 失败：$e');
      rethrow;
    }
  }

  Future<void> remove(String path, {CancelToken? cancelToken}) async {
    try {
      _checkInitialized();
      await _client!.remove(path, cancelToken);
    } catch (e) {
      Logging.error('WebDAV remove 失败：$e');
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
      Logging.error('WebDAV rename 失败：$e');
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
      Logging.error('WebDAV copy 失败：$e');
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
      Logging.error('WebDAV read 失败：$e');
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
      Logging.error('WebDAV read2File 失败：$e');
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
      Logging.error('WebDAV writeFromFile 失败：$e');
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
      Logging.error('WebDAV write 失败：$e');
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
      Logging.error('WebDAV 客户端已断开连接');
    }
  }

  void _checkInitialized() {
    if (_client == null) {
      throw WebDavNotInitializedException();
    }
  }
}
