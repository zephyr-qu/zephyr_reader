# Attack Surface Inventory — Phase L4 Manual

Generated: 2026-07-17T11:20:00Z
Mode: balanced (single-team, single-pass)
Analyst: Probe Strategist (acting as backward + contradiction reasoner inline)

---

## Selected Attack Surface Slices

After reviewing `knowledge-base-report.md` and existing Q2 findings, the two highest-impact unaddressed slices are:

| # | Slice | Severity | Existing coverage |
|---|-------|----------|-------------------|
| **A** | SSRF via Translation API (user-configurable API URL) | HIGH | q2-001 covers plaintext key storage only; SSRF aspect unaddressed |
| **B** | Backup Restore / Export Path Traversal | HIGH | q2-002 covers validate_file_path generically; backup-specific destructive write unaddressed |

---

## Entry Points

### Slice A: SSRF via Translation API

| Entry Point | File | Function | Input | Classification |
|-------------|------|----------|-------|----------------|
| Translation API URL setting | `lib/features/bilingual/presentation/bilingual_settings_sections.dart` | `_ApiSection` widget | User-entered URL string | User-controlled HTTP endpoint |
| API key setting | Same file | `_InputTile` for apiKey | User-entered API key string | Auth credential |
| Custom translator translate() | `lib/features/bilingual/data/providers/custom_translator.dart:33-46` | `translate()` | Reads `_config.apiUrl.value` and `_config.apiKey.value` | HTTP POST to arbitrary URL |
| OpenAI translator translate() | `lib/features/bilingual/data/providers/openai_translator.dart:55-72` | `translate()` | Reads `_config.apiUrl.value` + appends `/v1/chat/completions` | HTTP POST to arbitrary URL |
| BilingualConfig storage | `lib/features/bilingual/application/bilingual_config.dart` | constructor | PersistedSignal from SharedPreferences | Persistent plaintext storage |

### Slice B: Backup Restore / Export Path Traversal

| Entry Point | File | Function | Input | Classification |
|-------------|------|----------|-------|----------------|
| restore_database | `rust/src/domain/backup/service.rs:107` | `restore_database(backup_path)` | String path from Dart FFI | File path (no base confinement) |
| export_database | `rust/src/domain/backup/service.rs:62` | `export_database(dest_path)` | String path from Dart FFI | File path (no base confinement) |
| inspect_backup | `rust/src/domain/backup/service.rs:97` | `inspect_backup(backup_path)` | Passes to validate_file_path then opens read-only | File path validation |
| validate_file_path | `rust/src/common/security.rs:18` | `validate_file_path(path_str)` | Any string path | Canonicalizes but does NOT confine to base dir |

---

## Trust Boundary Crossings

### Slice A

| From | To | Data | Crossing type |
|------|----|------|---------------|
| Flutter UI (settings) | SharedPreferences XML | apiUrl + apiKey | Plaintext write to shared_prefs XML |
| Flutter Dio client | External HTTPS server (user-specified) | POST body (text) + Authorization header (Bearer apiKey) | Outbound HTTP with credentials |
| SharedPreferences | `BilingualConfig` in-memory | apiUrl, apiKey read on app start | Normal read |

### Slice B

| From | To | Data | Crossing type |
|------|----|------|---------------|
| Dart FFI | Rust api/backup.rs | `backup_path` or `dest_path` string | FRB-typed call (no auth boundary) |
| Rust validate_file_path | Filesystem | Canonicalized path read | No base-directory confinement check |
| restore_from_backup | Current `reader.db` | Full database overwrite | Destructive write |

---

## Attacker Sources

| Source | Relevant to | Capability |
|--------|-------------|------------|
| Malicious app on same device | Slice A | Can craft deep link to settings page with pre-filled values; or wait for user to input attacker-provided URL |
| Rogue WebDAV server operator | Slice A (credential theft) | If user syncs WebDAV, but unrelated — direct social engineering to change API URL is simpler |
| Confused deputy (social engineering) | Both | Attacker convinces user to set API URL to attacker endpoint, or to select a malicious backup file |
| Malicious file supplier | Slice B | Supplies crafted backup database file that, when restored, injects data |

---

## Sinks

| Sink | Slice | What's affected |
|------|-------|-----------------|
| Attacker HTTPS server | A | Receives API key + translation text (credential theft, data leak) |
| Internal-network HTTPS server | A | SSRF: API key + text sent to internal services (e.g., 192.168.1.x, 169.254.x.x, internal cloud metadata endpoints) |
| Current `reader.db` | B | Overwritten with attacker-controlled backup data |
| External destination path | B | Database contents exfiltrated to attacker-writable location |

---

## Hidden Control Channels

| Channel | Location | Mechanism |
|---------|----------|-----------|
| Deep link routing | `app_router.dart:redirect` | `zephyr://` URI can navigate to any route — could direct user to settings page with malicious presets |
| PersistedSignal (SharedPreferences) | `lib/core/settings/persisted_signal.dart` | API URL stored as plaintext string; any code with SharedPreferences access can read/write it |
| Dio retry interceptor | `network_module.dart:35-57` | On network error, Dio retries with same request options to same URL — amplifies SSRF if URL is slow-but-valid |

---

## Middleware / Proxy Assumptions

| Item | Assumption | Validity |
|------|-----------|----------|
| Dio TLS verification | Uses platform default TLS | Valid — no `badCertificateCallback` found. But SSRF does not require bypassing TLS if target is an internal HTTP service |
| Dio baseUrl | Set to placeholder `https://api.example.com` | Overridden at call site; each translator uses `_config.apiUrl.value` directly |
| SharedPreferences | "Safe enough" for non-credential data | Violated — API key IS a credential stored here |
| validate_file_path | "Validates" file paths | Only checks existence + canonicalizes; no base-confinement |

---

## Key Files Summary

| File | Slice | Role |
|------|-------|------|
| `lib/features/bilingual/data/providers/custom_translator.dart` | A | SSRF: sends POST with API key to user-configured URL |
| `lib/features/bilingual/data/providers/openai_translator.dart` | A | SSRF: sends POST with API key to `${apiUrl}/v1/chat/completions` |
| `lib/features/bilingual/application/bilingual_config.dart` | A | Stores apiUrl + apiKey as PersistedSignal (plaintext) |
| `lib/features/bilingual/presentation/bilingual_settings_sections.dart` | A | UI for setting the API URL and key |
| `lib/core/network/network_module.dart` | A | Dio client configuration (no URL validation) |
| `rust/src/domain/backup/service.rs` | B | `restore_database()` and `export_database()` writable paths |
| `rust/src/common/security.rs` | B | `validate_file_path()` missing base-confinement check |
| `rust/src/infra/manager.rs` | B | `restore_from_backup` implementation |
| `rust/src/api/backup.rs` | B | FRB wrapper for backup operations |
