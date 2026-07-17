# Balanced Probe Summary — Phase L4

**Generated**: 2026-07-17T11:30:00Z  
**Mode**: balanced (single-team, single-pass)  
**Target**: zephyr_reader (commit 23e2192cd8c9f64996dc344a8c2b7bb3067cddb6)  
**Audit ID**: 2026-07-17T03:02:30.215Z  

---

## Probe Execution

| Step | Status | Notes |
|------|--------|-------|
| KB Report Analysis | ✅ | Read `knowledge-base-report.md`, `candidates-summary.md` |
| Attack Surface Mapping | ✅ | Written: `manual-attack-surface-inventory.md` |
| Hypothesis Generation | ✅ | 12 hypotheses generated (7 for Slice A SSRF, 5 for Slice B Backup) |
| Hypothesis Verification | ✅ | Verified via `read`/`grep` on all key files |
| Findings Drafts | ✅ | 5 drafts written to `piolium/findings-draft/` (capped at 10) |

---

## Attack Surface Slices Selected

| # | Slice | Category | Files Scanned |
|---|-------|----------|---------------|
| A | SSRF via Translation API | HIGH — Credential forwarding + internal network scan | 4 Dart files, 1 Rust config file |
| B | Backup Restore/Export Path Traversal | HIGH — Destructive write + data exfiltration | 4 Rust files |

---

## Findings Summary

| ID | Title | Severity | Slice | Type |
|----|-------|:--------:|:-----:|------|
| l4-001 | SSRF via Translation API URL | **HIGH** | A | SSRF + credential theft |
| l4-002 | Database Overwrite via Unconfined Backup Restore Path | **HIGH** | B | Path traversal (write) |
| l4-003 | Database Exfiltration via Unvalidated Export Destination | **HIGH** | B | Path traversal (write) |
| l4-004 | SSRF Amplification via Dio Retry Interceptor | LOW | A | Amplification |
| l4-005 | Unmaintained bincode v2.0.1 Dependency (RUSTSEC-2025-0141) | MEDIUM | Both | Supply chain |

---

## Coverage Against Existing Findings

| Existing Q2 Finding | Overlap | L4 Coverage |
|---------------------|:-------:|-------------|
| q2-001: Translation API key plaintext | Partial | L4-001 covers the SSRF aspect (same affected file, different vulnerability class: SSRF vs plaintext) |
| q2-002: validate_file_path no base confinement | Partial | L4-002, L4-003 leverage the same root cause but focus on backup-specific destructive operations |
| q2-003: Cover output path traversal | None | Not re-examined; already well-documented |
| q2-004: WiFi multipart parser weak | None | Not re-examined |
| q2-005: WiFi server LAN IP mismatch | None | Not re-examined |

---

## Key Code Paths

### Slice A: SSRF via Translation API

```
User Settings (bilingual_settings_sections.dart:72-76)
  → BilingualConfig.apiUrl (bilingual_config.dart:39-41)
    → PersistedSignal (SharedPreferences — plaintext)
      → CustomBilingualTranslator.translate() (custom_translator.dart:27-45)
        → dio.post(url, headers: {Authorization: Bearer <apiKey>}, data: {text, ...})
```

### Slice B: Backup Path Traversal

```
Dart → FRB → api/backup.rs:restore_database(backup_path)
  → domain/backup/service.rs:restore_database()
    → security::validate_file_path() — only checks exists+is_file
    → storage.restore_from_backup() — overwrites reader.db

Dart → FRB → api/backup.rs:export_database(dest_path)
  → domain/backup/service.rs:export_database()
    → Path::new(dest_path).parent().exists() — bare minimum
    → std::fs::copy(reader.db, dest) — full database copy
```

---

## Coverage Gaps (Unaddressed in This Probe)

| Gap | Reason |
|-----|--------|
| EPUB Zip Slip (archive path traversal) | Requires analysis of the `epub` crate's internal ZIP handling via the `zip` crate; the codebase uses the `epub` crate API which abstracts the ZIP layer — would need to trace `epub::doc::EpubDoc` behavior with crafted ZIP entries |
| Image bomb / decompression bomb in EPUB images | `processed_image.rs` uses the `image` crate without explicit max dimension limits; the `image` crate applies built-in safety limits but these should be verified |
| Dio TLS certificate validation bypass | No `badCertificateCallback` was found, but this should be confirmed in release builds |
| WebDAV sync path traversal | Not examined in this pass — the WebDAV sync uploads books to a remote server; server-side path handling not in scope |
| Insecure defaults in Rust engine | Minor concern: `panic = 'abort'` in release profile means any panic kills the process; not exploitable for data theft |

---

## Recommendations

### Immediate (HIGH severity)

1. **L4-001**: Validate and restrict the Translation API URL — block internal/reserved IPs, enforce HTTPS, validate at ingress
2. **L4-002**: Add base-directory confinement to `restore_database` — only accept backup files from app-managed directory
3. **L4-003**: Add base-directory confinement to `export_database` — only write to app-managed backups directory

### Short-term (MEDIUM severity)

4. **L4-005**: Migrate from bincode 2.0.1 to a maintained alternative (postcard, serde_bare, or manual serialization)

### Defense-in-depth (LOW severity)

5. **L4-004**: Remove or limit retry for user-configured URLs to prevent SSRF amplification

---

## Files Written During This Probe

| File | Purpose |
|------|---------|
| `attack-surface/manual-attack-surface-inventory.md` | Detailed attack surface mapping |
| `tmp/piolium/balanced-probe/hypotheses-generated.md` | All generated hypotheses (12 total) |
| `findings-draft/l4-001-ssrf-translation-api-url.md` | SSRF via Translation API URL (HIGH) |
| `findings-draft/l4-002-backup-restore-database-overwrite.md` | Database overwrite via backup restore (HIGH) |
| `findings-draft/l4-003-backup-export-unvalidated-dest.md` | Database exfiltration via export (HIGH) |
| `findings-draft/l4-004-retry-amp-ssrf.md` | SSRF amplification via retry (LOW) |
| `findings-draft/l4-005-bincode-unmaintained-rustsec.md` | Unmaintained bincode dependency (MEDIUM) |
| `attack-surface/balanced-probe-summary.md` | This summary |

---

**Probe complete.** 5 findings (3 HIGH, 1 MEDIUM, 1 LOW). Ready for Phase L5.
