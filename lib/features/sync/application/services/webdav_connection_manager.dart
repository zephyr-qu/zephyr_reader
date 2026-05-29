import 'package:flutter/foundation.dart';
import 'package:zephyr_reader/core/utils/logging.dart';

import 'sync_exceptions.dart';
import 'sync_models.dart';
import 'webdav_client_service.dart';
import 'webdav_config_service.dart';

class WebdavConnectionManager {
  final WebDavConfigService _configService;
  WebDavClientService? _client;

  WebdavConnectionManager({required WebDavConfigService configService})
    : _configService = configService;

  Future<WebDavClientService> getConnectedClient() async {
    if (_client != null && _client!.isInitialized) return _client!;

    final config = await _configService.getConfig();
    if (config == null || !config.isValid) {
      throw WebDavConfigInvalidException();
    }

    _client = WebDavClientService();
    await _client!.init(
      baseUrl: config.baseUrl,
      username: config.username,
      password: config.password,
      debug: kDebugMode,
    );
    return _client!;
  }

  Future<bool> testConnection(WebDavConfig config) async {
    try {
      final client = WebDavClientService();
      await client.init(
        baseUrl: config.baseUrl,
        username: config.username,
        password: config.password,
        debug: kDebugMode,
      );
      return await client.ping();
    } catch (e) {
      Logging.error('WebDAV 连接测试异常：$e');
      return false;
    }
  }

  void disconnect() {
    _client?.dispose();
    _client = null;
  }

  void invalidate() {
    _client = null;
  }
}
