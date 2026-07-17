# Translation API Key Stored in Plaintext via SharedPreferences

- **Severity:** MEDIUM  
- **Vulnerability Class:** Sensitive Data Exposure (CWE-312: Cleartext Storage of Sensitive Information)  
- **PoC Status:** Theoretical (code-path evidence confirms vulnerability; physical device access required for extraction)  

---

## Summary

The translation/bilingual feature persists the third-party API key (`apiKey` for OpenAI or a compatible provider) through the standard `PersistedSignal` → `PreferencesService` → `SharedPreferences` pipeline, which stores data in an unencrypted XML file on disk. The WebDAV password in the same application is correctly stored via `FlutterSecureStorage` (backed by Android Keystore / iOS Keychain), making this an inconsistent hardening gap that leaves the translation API key unprotected at rest. An attacker with rooted-device access, ADB backup extraction, or a file-read vulnerability elsewhere in the app can retrieve the key in cleartext.

---

## Details

### Affected Files

| File | Role |
|------|------|
| [`lib/features/bilingual/application/bilingual_config.dart`](https://github.com/2084035767/zephyr_reader/blob/23e2192cd8c9f64996dc344a8c2b7bb3067cddb6/lib/features/bilingual/application/bilingual_config.dart) (line 44) | Declares `apiKey` as a `PersistedSignal<String>` via `persistedString()` |
| [`lib/core/settings/persisted_signal.dart`](https://github.com/2084035767/zephyr_reader/blob/23e2192cd8c9f64996dc344a8c2b7bb3067cddb6/lib/core/settings/persisted_signal.dart) (line 138–152) | `persistedString()` factory that wires reads/writes through `PreferencesService` |
| [`lib/core/local/shared_preferences_service.dart`](https://github.com/2084035767/zephyr_reader/blob/23e2192cd8c9f64996dc344a8c2b7bb3067cddb6/lib/core/local/shared_preferences_service.dart) (line 17–20) | `setString`/`getString` delegated to `SharedPreferences` (plaintext XML) |

### The Vulnerable Data Flow

The complete call chain from user input to persistent storage is:

```
BilingualConfig constructor
  → persistedString(prefs, 'translation.api_key', '')
    → persisted<String>(service, key, defaultValue,
        reader: (s, k) => s.getString(k) ?? defaultValue,
        writer: (s, k, v) => s.setString(k, v))
      → PersistedSignal._(initialValue, key, service, _write)
        → _write = (s, k, v) => s.setString(k, v)
          → SharedPreferencesService.setString(key, value)
            → _prefs.setString(key, value)       ← PLAINTEXT XML
```

The resulting data lands in an XML file at `/data/data/<package>/shared_prefs/FlutterSharedPreferences.xml` on Android. A simulated extraction shows the exact content an attacker would see:

```xml
<?xml version='1.0' encoding='utf-8' standalone='yes' ?>
<map>
    <string name="flutter.reading_font_size">18</string>
    <string name="translation.api_url">https://api.openai.com</string>
    <string name="translation.api_key">[REDACTED:openai-token]</string>
    <string name="translation.model">gpt-4o-mini</string>
    <string name="translation.provider">openai</string>
    ...
</map>
```

The API key is stored alongside innocuous preferences such as font size and dark mode, with no encryption or access control beyond what the filesystem provides.

### Contrast with WebDAV Password Handling

The WebDAV configuration service in the same codebase correctly uses `FlutterSecureStorage` for the credential:

```dart
// lib/features/data/application/services/webdav_config_service.dart
final _secureStorage = secureStorage ?? const FlutterSecureStorage();
await _secureStorage.write(key: _keyPassword, value: config.password);
```

This stores the password in the Android Keystore / iOS Keychain, which encrypts the value at rest using hardware-backed keys. The inconsistency is notable because both `shared_preferences` and `flutter_secure_storage` are already declared dependencies in `pubspec.yaml` — adopting secure storage for the translation API key would add **zero new dependencies**.

---

## Root Cause

[`BilingualConfig`](https://github.com/2084035767/zephyr_reader/blob/23e2192cd8c9f64996dc344a8c2b7bb3067cddb6/lib/features/bilingual/application/bilingual_config.dart) declares the API key on line 44 as:

```dart
apiKey = [REDACTED:secret], SettingsKeys.translationApiKey, ''),
```

The `PersistedSignal<String>` type has no concept of sensitive data. Every `persistedString()` call — whether for font size or for an API key — flows through the same `SharedPreferencesService.setString()` → `SharedPreferences.setString()` path. No encryption is applied, and no distinction is made between benign preferences and credentials.

The root cause is an **absent credential classification layer**: the `PersistedSignal` abstraction treats all string values identically, and the `BilingualConfig` module does not route the API key through a secure storage backend.

---

## Proof of Concept

**PoC Status:** `theoretical` — the vulnerability is confirmed through static code-path analysis. Active exploitation requires physical or file-system access to the device.

### Attack Vectors

#### 1. Rooted / Jailbroken Device
An attacker with root access on the device reads the SharedPreferences XML directly:

```bash
# On a rooted device:
adb shell
su
cat /data/data/com.zephyr.reader/shared_prefs/FlutterSharedPreferences.xml
```

#### 2. ADB Backup Extraction
If `android:allowBackup` is left at its default (`true`), an attacker with USB access can extract app data via:

```bash
# Create backup (no APK needed):
adb backup -f app-backup.ab -noapk com.zephyr.reader

# Convert AB to tar and extract:
( printf "\x1f\x8b\x08\x00\x00\x00\x00\x00" ; \
  dd if=app-backup.ab bs=1 skip=24 2>/dev/null ) | tar -xzvf -

# Read the extracted preferences:
cat apps/com.zephyr.reader/sp/FlutterSharedPreferences.xml
```

#### 3. File-Read Vulnerability Chaining
Any path traversal, local file inclusion, or directory traversal bug elsewhere in the application that reaches the app's private data directory would expose the API key.

### PoC Script

A demonstration script is available at [`piolium/findings/M1-translation-api-key-plaintext/poc.sh`](poc.sh). It performs static code-path analysis, simulates the extracted SharedPreferences XML, and documents the ADB backup and rooted-device attack sequences. The script does not require a live device because the code-path evidence is independently verifiable.

Key evidence from the code-path analysis:

**Insecure path (translation API key):**
- `bilingual_config.dart:44` — `apiKey = [REDACTED:secret], SettingsKeys.translationApiKey, '')`
- `persisted_signal.dart:138-152` — `persistedString()` factory uses `setString`/`getString`
- `shared_preferences_service.dart:17-20` — `setString` delegates to `_prefs.setString()` (plaintext XML)

**Secure path (WebDAV password):**
- `webdav_config_service.dart:16` — `final FlutterSecureStorage _secureStorage;`
- `webdav_config_service.dart:62` — `await _secureStorage.write(key: _keyPassword, value: config.password);`

The call chain is documented in detail at [`evidence/flow_verification.dart`](evidence/flow_verification.dart).

---

## Impact

An attacker who extracts the translation API key can:

1. **Financial abuse** — Make unauthorized translation API calls at the victim's expense. If the translation provider (OpenAI, DeepL, etc.) charges per-token or per-request, the victim incurs the cost. The default model is `gpt-4o-mini`, which has a non-zero per-token cost.

2. **LLM API access** — If the configured provider is OpenAI, the extracted `sk-*` key grants full access to OpenAI API endpoints (chat completions, embeddings, fine-tuning, etc.), enabling broader abuse beyond translation.

3. **No additional authentication barrier** — The key works immediately from any client without any second factor. Rate limits and spending caps (if any) depend solely on the API provider's plan settings.

The impact is limited by the requirement for device-level access (root, ADB backup, or a file-read primitive). The severity is rated MEDIUM because the translation API key does not protect the application's own user data — it is a service credential for a downstream API — but the financial and operational abuse potential is concrete.

---

## Remediation

### Short-term Fix

Route the translation API key through `FlutterSecureStorage` instead of `SharedPreferences`, matching the pattern already used for the WebDAV password:

```dart
// In lib/features/bilingual/application/bilingual_config.dart

// Replace:
apiKey = [REDACTED:secret], SettingsKeys.translationApiKey, ''),

// With a secure-storage-backed field:
final FlutterSecureStorage _secureStorage;
Future<String> getApiKey() =>
    _secureStorage.read(key: SettingsKeys.translationApiKey) ?? '';
Future<void> setApiKey(String value) =>
    _secureStorage.write(key: SettingsKeys.translationApiKey, value: value);
```

### Architectural Improvement

Introduce a `persistedSecureString()` factory in `persisted_signal.dart` that stores values via `FlutterSecureStorage` rather than `SharedPreferences`, making it as easy to use the secure path as the insecure one:

```dart
PersistedSignal<String> persistedSecureString(
  FlutterSecureStorage storage,
  String key,
  String defaultValue,
) {
  // Implementation that reads/writes via FlutterSecureStorage
  // while preserving the PersistedSignal auto-save contract.
}
```

### Audit

Scan all `PersistedSignal<String>` usages across the codebase for any other credentials or tokens that should be migrated to secure storage. Both `shared_preferences` and `flutter_secure_storage` are already declared in `pubspec.yaml`, so no dependency changes are needed.

---

## References

- [CWE-312: Cleartext Storage of Sensitive Information](https://cwe.mitre.org/data/definitions/312.html)
- OWASP Mobile Top 10: M1 (Improper Platform Usage) / M2 (Insecure Data Storage)
- [flutter_secure_storage package](https://pub.dev/packages/flutter_secure_storage)
