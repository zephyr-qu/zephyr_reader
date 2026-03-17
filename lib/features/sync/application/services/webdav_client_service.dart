/// WebDAV 客户端封装服务
///
/// 基于 webdav_client 库封装的 WebDAV 客户端
/// 提供常用的 WebDAV 操作接口
library;

import 'package:flutter/foundation.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;

/// WebDAV 客户端封装
class WebDavClientService {
  webdav.Client? _client;
  String? _baseUrl;
  String? _username;

  /// 初始化 WebDAV 客户端
  ///
  /// [baseUrl] WebDAV 服务器地址
  /// [username] 用户名
  /// [password] 密码
  /// [debug] 是否启用调试模式
  Future<void> init({
    required String baseUrl,
    required String username,
    required String password,
    bool debug = false,
  }) async {
    try {
      _baseUrl = baseUrl;
      _username = username;

      // 创建客户端实例
      _client = webdav.newClient(
        baseUrl,
        user: username,
        password: password,
        debug: debug,
      );

      // 测试连接
      await ping();

      debugPrint('WebDAV 客户端初始化成功：$baseUrl');
    } catch (e) {
      debugPrint('WebDAV 客户端初始化失败：$e');
      rethrow;
    }
  }

  /// 测试连接
  ///
  /// 返回 true 表示连接成功
  Future<bool> ping() async {
    try {
      if (_client == null) {
        throw Exception('WebDAV 客户端未初始化');
      }
      await _client!.ping();
      return true;
    } catch (e) {
      debugPrint('WebDAV ping 失败：$e');
      return false;
    }
  }

  /// 设置公共请求头
  void setHeaders(Map<String, String> headers) {
    _client?.setHeaders(headers);
  }

  /// 设置连接超时（毫秒）
  void setConnectTimeout(int milliseconds) {
    _client?.setConnectTimeout(milliseconds);
  }

  /// 设置发送超时（毫秒）
  void setSendTimeout(int milliseconds) {
    _client?.setSendTimeout(milliseconds);
  }

  /// 设置接收超时（毫秒）
  void setReceiveTimeout(int milliseconds) {
    _client?.setReceiveTimeout(milliseconds);
  }

  /// 读取目录
  ///
  /// 返回目录中的文件和文件夹列表
  Future<List<dynamic>> readDir(String path) async {
    try {
      if (_client == null) {
        throw Exception('WebDAV 客户端未初始化');
      }
      return await _client!.readDir(path);
    } catch (e) {
      debugPrint('WebDAV readDir 失败：$e');
      rethrow;
    }
  }

  /// 创建文件夹
  Future<void> mkdir(String path) async {
    try {
      if (_client == null) {
        throw Exception('WebDAV 客户端未初始化');
      }
      await _client!.mkdir(path);
    } catch (e) {
      debugPrint('WebDAV mkdir 失败：$e');
      rethrow;
    }
  }

  /// 递归创建文件夹
  Future<void> mkdirAll(String path) async {
    try {
      if (_client == null) {
        throw Exception('WebDAV 客户端未初始化');
      }
      await _client!.mkdirAll(path);
    } catch (e) {
      debugPrint('WebDAV mkdirAll 失败：$e');
      rethrow;
    }
  }

  /// 删除文件或文件夹
  Future<void> remove(String path) async {
    try {
      if (_client == null) {
        throw Exception('WebDAV 客户端未初始化');
      }
      await _client!.remove(path);
    } catch (e) {
      debugPrint('WebDAV remove 失败：$e');
      rethrow;
    }
  }

  /// 重命名文件或文件夹
  ///
  /// [oldPath] 旧路径
  /// [newPath] 新路径
  /// [overwrite] 是否覆盖已存在的文件
  Future<void> rename(String oldPath, String newPath, bool overwrite) async {
    try {
      if (_client == null) {
        throw Exception('WebDAV 客户端未初始化');
      }
      await _client!.rename(oldPath, newPath, overwrite);
    } catch (e) {
      debugPrint('WebDAV rename 失败：$e');
      rethrow;
    }
  }

  /// 复制文件或文件夹
  ///
  /// [sourcePath] 源路径
  /// [destPath] 目标路径
  /// [overwrite] 是否覆盖已存在的文件
  Future<void> copy(String sourcePath, String destPath, bool overwrite) async {
    try {
      if (_client == null) {
        throw Exception('WebDAV 客户端未初始化');
      }
      await _client!.copy(sourcePath, destPath, overwrite);
    } catch (e) {
      debugPrint('WebDAV copy 失败：$e');
      rethrow;
    }
  }

  /// 下载文件（返回字节）
  Future<List<int>> read(String path, {void Function(int, int)? onProgress}) async {
    try {
      if (_client == null) {
        throw Exception('WebDAV 客户端未初始化');
      }
      return await _client!.read(path, onProgress: onProgress);
    } catch (e) {
      debugPrint('WebDAV read 失败：$e');
      rethrow;
    }
  }

  /// 下载文件到本地
  ///
  /// [remotePath] 远程文件路径
  /// [localPath] 本地文件路径
  /// [onProgress] 进度回调
  Future<void> read2File(
    String remotePath,
    String localPath, {
    void Function(int, int)? onProgress,
  }) async {
    try {
      if (_client == null) {
        throw Exception('WebDAV 客户端未初始化');
      }
      await _client!.read2File(remotePath, localPath, onProgress: onProgress);
    } catch (e) {
      debugPrint('WebDAV read2File 失败：$e');
      rethrow;
    }
  }

  /// 上传文件
  ///
  /// [localPath] 本地文件路径
  /// [remotePath] 远程文件路径
  /// [onProgress] 进度回调
  /// [cancelToken] 取消令牌
  Future<void> writeFromFile(
    String localPath,
    String remotePath, {
    void Function(int, int)? onProgress,
    dynamic cancelToken,
  }) async {
    try {
      if (_client == null) {
        throw Exception('WebDAV 客户端未初始化');
      }
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

  /// 上传文件（从字节）
  Future<void> write(String remotePath, List<int> data, {void Function(int, int)? onProgress}) async {
    try {
      if (_client == null) {
        throw Exception('WebDAV 客户端未初始化');
      }
      await _client!.write(remotePath, Uint8List.fromList(data), onProgress: onProgress);
    } catch (e) {
      debugPrint('WebDAV write 失败：$e');
      rethrow;
    }
  }

  /// 检查客户端是否已初始化
  bool get isInitialized => _client != null;

  /// 获取客户端实例（高级用法）
  webdav.Client? get client => _client;

  /// 获取基础 URL
  String? get baseUrl => _baseUrl;

  /// 获取用户名
  String? get username => _username;

  /// 断开连接
  void dispose() {
    _client = null;
    _baseUrl = null;
    _username = null;
    debugPrint('WebDAV 客户端已断开连接');
  }
}
