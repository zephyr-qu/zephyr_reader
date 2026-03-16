/// WebDAV 配置存储服务
///
/// 提供 WebDAV 配置的加密存储和读取
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals_flutter/signals_flutter.dart';

import 'webdav_sync_service.dart';

/// WebDAV 配置存储服务
class WebDavConfigService {
  final SharedPreferences _prefs;
  final FlutterSecureStorage _secureStorage;

  /// WebDAV 配置是否已设�?
    final isConfigured = signal(false);

  /// 是否启用自动同步
  final autoSyncEnabled = signal(false);

  /// 自动同步间隔（分钟）
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

  /// 加载配置状�?
   void _loadConfigStatus() {
    final baseUrl = _prefs.getString(_keyBaseUrl);
    isConfigured.value = baseUrl != null && baseUrl.isNotEmpty;
    autoSyncEnabled.value = _prefs.getBool(_keyAutoSync) ?? false;
    autoSyncInterval.value = _prefs.getInt(_keySyncInterval) ?? 30;
  }

  /// 获取 WebDAV 配置
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

  /// 保存 WebDAV 配置
  Future<void> saveConfig(WebDavConfig config) async {
    await _prefs.setString(_keyBaseUrl, config.baseUrl);
    await _prefs.setString(_keyUsername, config.username);
    await _prefs.setString(_keyRemotePath, config.remotePath);
    await _secureStorage.write(key: _keyPassword, value: config.password);

    isConfigured.value = true;
    debugPrint('WebDAV 配置已保�?');
  }

  /// 清除 WebDAV 配置
  Future<void> clearConfig() async {
    await _prefs.remove(_keyBaseUrl);
    await _prefs.remove(_keyUsername);
    await _prefs.remove(_keyRemotePath);
    await _secureStorage.delete(key: _keyPassword);

    isConfigured.value = false;
    debugPrint('WebDAV 配置已清�?');
  }

  /// 设置自动同步
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
    // debugPrint('自动同步�?{enabled ? '启用' : '禁用'}');
  }

  /// 测试当前配置
  Future<bool> testCurrentConfig() async {
    final config = await getConfig();
    if (config == null) {
      return false;
    }

    final service = WebDavSyncService(config: config);
    final result = await service.testConnection();
    service.dispose();

    return result;
  }

  /// 获取最后同步时�?

   Future<DateTime?> getLastSyncTime() async {
    final timestamp = _prefs.getInt(_keyLastSyncTime);
    if (timestamp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  /// 设置最后同步时�?
   Future<void> setLastSyncTime(DateTime time) async {
    await _prefs.setInt(_keyLastSyncTime, time.millisecondsSinceEpoch);
  }

  /// 获取同步预设
  static List<WebDavPreset> getPresets() {
    return [
      WebDavPreset(
        name: '坚果�?',
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

/// WebDAV 预设配置
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
