import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:flutter/foundation.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;

import 'sync_models.dart';

/// WebDAV 配置服务。
///
/// 管理 WebDAV 服务器连接参数的持久化存储（使用 FlutterSecureStorage）。
class WebDavConfigService {
  final SharedPreferences _prefs;
  final FlutterSecureStorage _secureStorage;

  final isConfigured = signal(false);

  WebDavConfigService({
    required SharedPreferences prefs,
    FlutterSecureStorage? secureStorage,
  }) : _prefs = prefs,
       _secureStorage = secureStorage ?? const FlutterSecureStorage() {
    _loadConfigStatus();
  }
  static const String _keyConfig = 'webdav.config';
  static const String _keyPassword = 'webdav.password';
  static const String _keyLastSyncTime = 'webdav.last_sync_time';

  void _loadConfigStatus() {
    isConfigured.value = _prefs.containsKey(_keyConfig);
  }

  Future<WebDavConfig?> getConfig() async {
    final json = _prefs.getString(_keyConfig);
    if (json == null) return null;
    try {
      final config = WebDavConfig.fromJson(
        jsonDecode(json) as Map<String, dynamic>,
      );
      final password = await _secureStorage.read(key: _keyPassword) ?? '';
      if (config.baseUrl.isEmpty ||
          config.username.isEmpty ||
          password.isEmpty ||
          config.remotePath.isEmpty) {
        return null;
      }
      return WebDavConfig(
        baseUrl: config.baseUrl,
        username: config.username,
        password: password,
        remotePath: config.remotePath,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> saveConfig(WebDavConfig config) async {
    await _prefs.setString(_keyConfig, jsonEncode(config.toJson()));
    await _secureStorage.write(key: _keyPassword, value: config.password);
    isConfigured.value = true;
  }

  Future<void> clearConfig() async {
    await _prefs.remove(_keyConfig);
    await _secureStorage.delete(key: _keyPassword);
    isConfigured.value = false;
  }

  Future<bool> testCurrentConfig() async {
    final config = await getConfig();
    if (config == null) return false;

    try {
      final baseUrl = config.baseUrl.endsWith('/')
          ? config.baseUrl
          : '${config.baseUrl}/';
      final client = webdav.newClient(
        baseUrl,
        user: config.username,
        password: config.password,
        debug: kDebugMode,
      );
      await client.ping();
      return true;
    } catch (e) {
      Logging.error('WebDAV 连接测试异常：$e');
      return false;
    }
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
