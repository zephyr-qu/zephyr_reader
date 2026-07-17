---
id: M1
phase: Q2
slug: translation-api-key-plaintext
severity: medium
original_id: q2-001
PoC-Status: theoretical
Protocol: local
Auth-Required: no
Auth-Roles-Required: anonymous
---

# Translation API Key Stored in Plaintext SharedPreferences

## Summary

The bilingual/translation API key (`apiKey` for OpenAI or custom provider) is persisted via `SharedPreferences` (plaintext XML) instead of `FlutterSecureStorage`. The WebDAV password — which uses the same application — **is** correctly stored via `FlutterSecureStorage`, creating an inconsistency that weakens the translation key's protection.

## Affected Files

- `lib/features/bilingual/application/bilingual_config.dart` (line 44)
- `lib/core/settings/persisted_signal.dart` — `persistedString` factory uses `PreferencesService.setString/ getString`
- `lib/core/local/shared_preferences_service.dart` — backs `PreferencesService` with `SharedPreferences`

## Root Cause

`BilingualConfig` declares the API key as:

```dart
apiKey = [REDACTED:secret], SettingsKeys.translationApiKey, ''),
```

`persistedString` -> `PreferencesService.setString` -> `SharedPreferences.setString`. On Android, SharedPreferences stores data as an XML file at `/data/data/<package>/shared_prefs/` in cleartext. A rooted device, ADB backup (if `android:allowBackup=true`), or any file-read vulnerability exposes the key.

Compare with `WebDavConfigService` which correctly uses:

```dart
final _secureStorage = secureStorage ?? const FlutterSecureStorage();
await _secureStorage.write(key: _keyPassword, value: config.password);
```

## Attacker Control

- **On a rooted/jailbroken device**: the attacker reads the app's SharedPreferences XML file directly.
- **Via ADB backup**: if `android:allowBackup` is enabled in the manifest, `adb backup` extracts app data including SharedPreferences.
- **Via file-read vulnerability elsewhere in the app**: any path traversal or file-read bug that reaches the app's data directory exposes the key.

## Impact

An attacker with the API key can:
- Make translation API calls at the victim's expense (monetary cost). If the translation provider charges per-token or per-request, this leads to **financial abuse**.
- If the API key is an OpenAI key (default `gpt-4o-mini`), the attacker gains access to the LLM API, enabling broader abuse.

## Recommendation

Replace `persistedString` with `FlutterSecureStorage` for `translationApiKey`:

```dart
// Instead of:
apiKey = [REDACTED:secret], SettingsKeys.translationApiKey, '');

// Use:
final FlutterSecureStorage _secureStorage;
Future<String> get _apiKey =>
    _secureStorage.read(key: SettingsKeys.translationApiKey) ?? '';
Future<void> setApiKey(String value) =>
    _secureStorage.write(key: SettingsKeys.translationApiKey, value: value);
```

Apply the same treatment to any other credential-bearing `PersistedSignal<String>`.
