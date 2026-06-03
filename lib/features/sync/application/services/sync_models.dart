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

enum SyncStatus { idle, syncing, success, failed }

enum SyncDataType {
  readingProgress('reading_progress.json', '阅读进度'),
  bookmarks('bookmarks.json', '书签'),
  bookshelf('bookshelf.json', '书架');

  final String filename;
  final String displayName;
  const SyncDataType(this.filename, this.displayName);
}

enum SyncDirection { upload, download, both }

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

  String get summary {
    if (!success) {
      return '同步失败：$error';
    }
    final parts = <String>[];
    if (uploadedCount > 0) parts.add('上传 $uploadedCount 项');
    if (downloadedCount > 0) parts.add('下载 $downloadedCount 项');
    return parts.isEmpty ? '同步完成，无需更新' : parts.join(', ');
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'uploadedCount': uploadedCount,
      'downloadedCount': downloadedCount,
      'error': error,
    };
  }

  factory SyncResult.fromJson(Map<String, dynamic> json) {
    return SyncResult(
      success: json['success'] as bool? ?? false,
      uploadedCount: json['uploadedCount'] as int? ?? 0,
      downloadedCount: json['downloadedCount'] as int? ?? 0,
      error: json['error'] as String?,
    );
  }
}

/// WebDAV 配置的宿主接口，允许配置对话框与任意 ViewModel 协作
abstract class WebDavConfigHost {
  Future<WebDavConfig?> getConfig();
  Future<void> saveConfig(WebDavConfig config);
  Future<void> clearConfig();
}
