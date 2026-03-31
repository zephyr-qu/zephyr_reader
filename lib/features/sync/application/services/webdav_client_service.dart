/// WebDAV 客户端封装服务
///
/// 基于 webdav_client 库封装的 WebDAV 客户端
/// 提供常用的 WebDAV 操作接口
///
/// 功能特性:
/// - 支持 Basic/Digest 认证
/// - 目录读取、创建、删除
/// - 文件上传、下载
/// - 文件/文件夹重命名、复制
/// - 取消请求支持 (使用 CancelToken)
/// - 进度回调
library;

import 'package:flutter/foundation.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;

/// WebDAV 客户端封装
///
/// 提供高级 WebDAV 操作接口，封装底层细节
class WebDavClientService {
  webdav.Client? _client;
  String? _baseUrl;
  String? _username;
  bool _isDebug = false;

  /// 初始化 WebDAV 客户端
  ///
  /// [baseUrl] WebDAV 服务器地址，必须以 / 结尾
  /// [username] 用户名
  /// [password] 密码
  /// [debug] 是否启用调试模式
  ///
  /// 示例:
  /// ```dart
  /// final client = WebDavClientService();
  /// await client.init(
  ///   baseUrl: 'https://dav.jianguoyun.com/dav/',
  ///   username: 'your_username',
  ///   password: 'your_password',
  ///   debug: kDebugMode,
  /// );
  /// ```
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

      // 确保 baseUrl 以 / 结尾
      if (!baseUrl.endsWith('/')) {
        baseUrl = '$baseUrl/';
      }

      // 创建客户端实例
      _client = webdav.newClient(
        baseUrl,
        user: username,
        password: password,
        debug: debug,
      );

      // 测试连接
      await ping();

      if (_isDebug) {
        debugPrint('WebDAV 客户端初始化成功：$baseUrl');
      }
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

  /// 设置公共请求头
  ///
  /// 可用于设置自定义 HTTP 头
  void setHeaders(Map<String, String> headers) {
    _checkInitialized();
    _client!.setHeaders(headers);
  }

  /// 设置连接超时（毫秒）
  void setConnectTimeout(int milliseconds) {
    _checkInitialized();
    _client!.setConnectTimeout(milliseconds);
  }

  /// 设置发送超时（毫秒）
  void setSendTimeout(int milliseconds) {
    _checkInitialized();
    _client!.setSendTimeout(milliseconds);
  }

  /// 设置接收超时（毫秒）
  void setReceiveTimeout(int milliseconds) {
    _checkInitialized();
    _client!.setReceiveTimeout(milliseconds);
  }

  /// 读取目录
  ///
  /// 返回目录中的文件和文件夹列表
  ///
  /// [path] 目录路径，相对于 WebDAV 根目录
  ///
  /// 示例:
  /// ```dart
  /// final files = await client.readDir('/');
  /// for (final file in files) {
  ///   print('${file.name} - ${file.size} bytes');
  /// }
  /// ```
  Future<List<dynamic>> readDir(String path) async {
    try {
      _checkInitialized();
      return await _client!.readDir(path);
    } catch (e) {
      debugPrint('WebDAV readDir 失败：$e');
      rethrow;
    }
  }

  /// 创建文件夹
  ///
  /// [path] 要创建的文件夹路径
  /// [cancelToken] 取消令牌，用于取消请求
  Future<void> mkdir(String path, {dynamic cancelToken}) async {
    try {
      _checkInitialized();
      await _client!.mkdir(path, cancelToken);
    } catch (e) {
      debugPrint('WebDAV mkdir 失败：$e');
      rethrow;
    }
  }

  /// 递归创建文件夹
  ///
  /// [path] 要创建的文件夹路径
  /// [cancelToken] 取消令牌，用于取消请求
  ///
  /// 示例：`mkdirAll('/folder1/folder2/folder3')` 会创建所有中间目录
  Future<void> mkdirAll(String path, {dynamic cancelToken}) async {
    try {
      _checkInitialized();
      await _client!.mkdirAll(path, cancelToken);
    } catch (e) {
      debugPrint('WebDAV mkdirAll 失败：$e');
      rethrow;
    }
  }

  /// 删除文件或文件夹
  ///
  /// [path] 要删除的文件或文件夹路径
  /// [cancelToken] 取消令牌，用于取消请求
  ///
  /// 注意：删除文件夹时，某些 WebDAV 服务要求路径以 / 结尾
  Future<void> remove(String path, {dynamic cancelToken}) async {
    try {
      _checkInitialized();
      await _client!.remove(path, cancelToken);
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
  /// [cancelToken] 取消令牌，用于取消请求
  ///
  /// 注意：重命名文件夹时，某些 WebDAV 服务要求路径以 / 结尾
  Future<void> rename(
    String oldPath,
    String newPath,
    bool overwrite, {
    dynamic cancelToken,
  }) async {
    try {
      _checkInitialized();
      await _client!.rename(oldPath, newPath, overwrite, cancelToken);
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
  /// [cancelToken] 取消令牌，用于取消请求
  ///
  /// 注意：复制文件夹会将源文件夹的所有内容复制到目标位置
  /// 某些 WebDAV 服务可能会删除目标文件夹的原始内容
  Future<void> copy(
    String sourcePath,
    String destPath,
    bool overwrite, {
    dynamic cancelToken,
  }) async {
    try {
      _checkInitialized();
      await _client!.copy(sourcePath, destPath, overwrite, cancelToken);
    } catch (e) {
      debugPrint('WebDAV copy 失败：$e');
      rethrow;
    }
  }

  /// 下载文件（返回字节）
  ///
  /// [path] 远程文件路径
  /// [onProgress] 进度回调 (已下载字节数，总字节数)
  /// [cancelToken] 取消令牌，用于取消请求
  ///
  /// 示例:
  /// ```dart
  /// final data = await client.read(
  ///   '/backup/data.json',
  ///   onProgress: (current, total) {
  ///     print('下载进度：${current / total * 100}%');
  ///   },
  /// );
  /// ```
  Future<List<int>> read(
    String path, {
    void Function(int, int)? onProgress,
    dynamic cancelToken,
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

  /// 下载文件到本地
  ///
  /// [remotePath] 远程文件路径
  /// [localPath] 本地文件路径
  /// [onProgress] 进度回调 (已下载字节数，总字节数)
  /// [cancelToken] 取消令牌，用于取消请求
  ///
  /// 示例:
  /// ```dart
  /// await client.read2File(
  ///   '/backup/data.json',
  ///   '/storage/emulated/0/data.json',
  ///   onProgress: (current, total) {
  ///     print('下载进度：${current / total * 100}%');
  ///   },
  /// );
  /// ```
  Future<void> read2File(
    String remotePath,
    String localPath, {
    void Function(int, int)? onProgress,
    dynamic cancelToken,
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

  /// 上传文件
  ///
  /// [localPath] 本地文件路径
  /// [remotePath] 远程文件路径
  /// [onProgress] 进度回调 (已上传字节数，总字节数)
  /// [cancelToken] 取消令牌，用于取消请求
  ///
  /// 示例:
  /// ```dart
  /// final cancelToken = CancelToken();
  /// await client.writeFromFile(
  ///   '/storage/emulated/0/data.json',
  ///   '/backup/data.json',
  ///   onProgress: (current, total) {
  ///     print('上传进度：${current / total * 100}%');
  ///   },
  ///   cancelToken: cancelToken,
  /// );
  /// ```
  Future<void> writeFromFile(
    String localPath,
    String remotePath, {
    void Function(int, int)? onProgress,
    dynamic cancelToken,
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

  /// 上传文件（从字节）
  ///
  /// [remotePath] 远程文件路径
  /// [data] 要上传的数据
  /// [onProgress] 进度回调 (已上传字节数，总字节数)
  /// [cancelToken] 取消令牌，用于取消请求
  Future<void> write(
    String remotePath,
    Uint8List data, {
    void Function(int, int)? onProgress,
    dynamic cancelToken,
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

  /// 检查客户端是否已初始化
  bool get isInitialized => _client != null;

  /// 获取客户端实例（高级用法）
  webdav.Client? get client => _client;

  /// 获取基础 URL
  String? get baseUrl => _baseUrl;

  /// 获取用户名
  String? get username => _username;

  /// 获取调试模式状态
  bool get isDebug => _isDebug;

  /// 断开连接
  ///
  /// 释放客户端资源，调用后需要重新初始化才能使用
  void dispose() {
    _client = null;
    _baseUrl = null;
    _username = null;
    _isDebug = false;
    if (kDebugMode) {
      debugPrint('WebDAV 客户端已断开连接');
    }
  }

  /// 检查客户端是否已初始化
  void _checkInitialized() {
    if (_client == null) {
      throw WebDavNotInitializedException();
    }
  }
}

/// WebDAV 未初始化异常
class WebDavNotInitializedException implements Exception {
  WebDavNotInitializedException();

  @override
  String toString() => 'WebDAV 客户端未初始化，请先调用 init() 方法';
}

/// WebDAV 认证异常
class WebDavUnauthorizedException implements Exception {
  final String message;

  WebDavUnauthorizedException([this.message = '认证失败，请检查用户名和密码']);

  @override
  String toString() => 'WebDAV 认证失败：$message';
}

/// WebDAV 文件不存在异常
class WebDavFileNotFoundException implements Exception {
  final String path;

  WebDavFileNotFoundException(this.path);

  @override
  String toString() => 'WebDAV 文件不存在：$path';
}

/// WebDAV 权限不足异常
class WebDavPermissionDeniedException implements Exception {
  final String path;

  WebDavPermissionDeniedException(this.path);

  @override
  String toString() => 'WebDAV 权限不足，无法访问：$path';
}
