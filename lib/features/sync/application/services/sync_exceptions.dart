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
