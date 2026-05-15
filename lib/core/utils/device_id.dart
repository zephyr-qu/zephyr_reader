library;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

const _keyDeviceId = 'app.device.id';

Future<String> getOrCreateDeviceId() async {
  final prefs = await SharedPreferences.getInstance();
  var id = prefs.getString(_keyDeviceId);
  if (id == null || id.isEmpty) {
    id = const Uuid().v4();
    await prefs.setString(_keyDeviceId, id);
  }
  return id;
}
