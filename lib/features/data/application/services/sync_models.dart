/// WebDAV 服务器连接配置。
///
/// 包含服务器地址、用户名、密码和远程路径。
class WebDavConfig {
  final String baseUrl;
  final String username;
  String password;
  final String remotePath;

  WebDavConfig({
    required this.baseUrl,
    required this.username,
    required this.password,
    required this.remotePath,
  });

  Map<String, dynamic> toJson() => {
    'baseUrl': baseUrl,
    'username': username,
    'remotePath': remotePath,
  };

  factory WebDavConfig.fromJson(Map<String, dynamic> json) => WebDavConfig(
    baseUrl: json['baseUrl'] as String,
    username: json['username'] as String,
    remotePath: json['remotePath'] as String,
    password: '', // filled separately from secure storage
  );

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

  /// Minimize password lifetime in heap.
  /// Note: Dart [String] is immutable — previous value remains until GC.
  void clearPassword() {
    password = '';
  }
}

enum SyncStatus { idle, syncing, success, failed }

enum SyncDataType {
  readingProgress('reading_progress.json', '阅读进度'),
  bookmarks('bookmarks.json', '书签'),
  bookshelf('bookshelf.json', '书架');

  final String filename;
  final String displayName;
  const SyncDataType(this.filename, this.displayName);
}

/// 同步方向枚举：上传、下载、双向。

enum SyncDirection { upload, download, both }

/// 同步操作结果，表示一次同步成功/失败的状态和统计数据。

class SyncResult {
  bool success;
  int uploadedCount;
  int downloadedCount;
  String? error;

  SyncResult({
    this.success = false,
    this.uploadedCount = 0,
    this.downloadedCount = 0,
    this.error,
  });
}
