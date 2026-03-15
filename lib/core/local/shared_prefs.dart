// import 'package:injectable/injectable.dart';
// import 'package:shared_preferences/shared_preferences.dart';

// @Singleton()
// class SharedPrefs {
//   final SharedPreferences _sp;
//   SharedPrefs(this._sp);

//   // Int operations
//   int getInt(String key, [int def = 0]) => _sp.getInt(key) ?? def;
//   Future<bool> setInt(String key, int value) => _sp.setInt(key, value);
//   Future<bool> removeInt(String key) => _sp.remove(key);

//   // String operations
//   String getString(String key, [String def = '']) => _sp.getString(key) ?? def;
//   Future<bool> setString(String key, String value) => _sp.setString(key, value);
//   Future<bool> removeString(String key) => _sp.remove(key);

//   // Bool operations
//   bool getBool(String key, [bool def = false]) => _sp.getBool(key) ?? def;
//   Future<bool> setBool(String key, bool value) => _sp.setBool(key, value);
//   Future<bool> removeBool(String key) => _sp.remove(key);

//   // Double operations
//   double getDouble(String key, [double def = 0.0]) => _sp.getDouble(key) ?? def;
//   Future<bool> setDouble(String key, double value) => _sp.setDouble(key, value);
//   Future<bool> removeDouble(String key) => _sp.remove(key);

//   // StringList operations
//   List<String> getStringList(String key, [List<String> def = const []]) =>
//       _sp.getStringList(key) ?? def;
//   Future<bool> setStringList(String key, List<String> value) =>
//       _sp.setStringList(key, value);
//   Future<bool> removeStringList(String key) => _sp.remove(key);

//   // General operations
//   bool containsKey(String key) => _sp.containsKey(key);
//   Future<bool> remove(String key) => _sp.remove(key);
//   Future<void> clear() => _sp.clear();
//   Set<String> getKeys() => _sp.getKeys();
// }
