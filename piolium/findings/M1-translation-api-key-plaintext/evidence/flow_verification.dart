/// Flow verification: Translation API Key → SharedPreferences
///
/// This file demonstrates the exact call chain that causes the vulnerability.
/// It is a documentation file, not a runnable test (would require Flutter test runner).
///
/// VULNERABLE CHAIN (translation API key):
///
///   BilingualConfig constructor
///     → persistedString(prefs, 'translation.api_key', '')
///       → persisted<String>(service, key, defaultValue,
///           reader: (s, k) => s.getString(k) ?? defaultValue,
///           writer: (s, k, v) => s.setString(k, v))
///         → PersistedSignal._(initialValue, key, service, _write)
///           → _write = (s, k, v) => s.setString(k, v)
///             → SharedPreferencesService.setString(key, value)
///               → _prefs.setString(key, value)   ← PLAINTEXT XML
///
/// SECURE CHAIN (WebDAV password):
///
///   WebDavConfigService.saveConfig(config)
///     → _prefs.setString(_keyConfig, jsonEncode(config.toJson()))
///       (base URL, username, remotePath go to SharedPreferences — acceptable)
///     → _secureStorage.write(key: _keyPassword, value: config.password)
///       (password goes to FlutterSecureStorage — encrypted with Android Keystore)
///
/// EXTRACTION POINT:
///
///   Android path: /data/data/<package>/shared_prefs/FlutterSharedPreferences.xml
///   XML entry:    <string name="translation.api_key">sk-xxxx...</string>
///
/// ROOT CAUSE SUMMARY:
///
///   The `PersistedSignal<String>` type has no concept of sensitive data.
///   All `persistedString()` values flow through SharedPreferences regardless
///   of whether the data is a harmless preference (e.g., font size) or a
///   credential (API key). The API key should be stored via FlutterSecureStorage
///   like the WebDAV password already is.
///
/// FIX:
///
///   1. Add a dedicated secure-storage signal type, e.g.:
///        PersistedSignal<String> persistedSecureString(
///          FlutterSecureStorage storage, String key, String defaultValue)
///
///   2. Or refactor BilingualConfig to inject FlutterSecureStorage directly:
///        class BilingualConfig {
///          final FlutterSecureStorage _secureStorage;
///          Future<String> getApiKey() => _secureStorage.read(key: ...) ?? '';
///        }
///
///   3. Both `flutter_secure_storage` and `shared_preferences` are already in
///      pubspec.yaml dependencies. Adding secure storage for the API key would
///      add zero new dependencies.
