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
