/// 读取或生成本地设备唯一标识。
///
/// 首次调用时生成 UUID v4 并持久化到 SharedPreferences，
/// 后续调用返回同一值。适用于 WebDAV 同步等需要匿名设备标识的场景。
library;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:zephyr_reader/core/settings/settings_keys.dart';

Future<String> getOrCreateDeviceId(SharedPreferences prefs) async {
  var id = prefs.getString(SettingsKeys.deviceId);
  if (id == null || id.isEmpty) {
    id = const Uuid().v4();
    await prefs.setString(SettingsKeys.deviceId, id);
  }
  return id;
}
