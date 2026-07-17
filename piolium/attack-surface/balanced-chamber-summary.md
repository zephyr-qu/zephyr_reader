# Balanced Chamber Summary — Phase L5

Generated: 2026-07-17T12:00:00Z
Mode: balanced (single-team, single-pass inline review)

## Chamber Review Process

Each draft finding (p4-*, l4-*, q2-*) was reviewed through a three-role inline process:

1. **Ideator**: Challenged each finding's validity, attack realism, and exploitation path
2. **Devil's-Advocate**: Attempted to reject each finding with counterarguments (platform sandboxing, user precondition requirements, current code disabled, theoretical vs practical risk)
3. **Synthesizer**: Issued final verdict with severity normalized per calibration framework

## Verdict Summary

| Finding | Verdict | Severity | P8 Draft | Notes |
|---------|---------|----------|----------|-------|
| p4-001 Custom Translator SSRF | VALID | HIGH | p8-001 | Merged with p4-020, l4-001 |
| p4-002 validate_file_path no confinement | VALID | MEDIUM | p8-002 | Merged with q2-002 |
| p4-003 WiFi Upload No Auth | VALID | MEDIUM | p8-003 | Disabled-by-default code risk |
| p4-004 API Key Plaintext (SharedPrefs) | VALID | MEDIUM | p8-004 | Merged with q2-001 |
| p4-005 Export Database Path Traversal | VALID | MEDIUM | p8-005 | Merged with l4-003 |
| p4-006 Restore Database Path Traversal | VALID | MEDIUM | p8-006 | Merged with l4-002 |
| p4-007 Cover Output Path Traversal | VALID | MEDIUM | p8-007 | Merged with q2-003 |
| p4-009 Bincode Unmaintained Crate | VALID | MEDIUM | p8-008 | Merged with l4-005 |
| p4-008 Temp File Race Window | DROP | LOW | — | Per policy: Low severity dropped |
| p4-010 Deep Link No Param Validation | DROP | LOW | — | Per policy: Low severity dropped |
| p4-011 WiFi Code Left Enabled | DROP | LOW | — | Not exploitable; code quality only |
| p4-012 Response Injection | DUPLICATE | — | — | Downstream of p4-001 SSRF |
| p4-013 EPUB Metadata No Sanitization | DROP | LOW | — | Per policy: Low severity dropped |
| p4-014 SQLx String Concat Risk | FP | — | — | Whitelist + binary choice prevents injection |
| p4-015 WebDAV Heap Lifetime | DROP | LOW | — | Per policy: Low severity dropped |
| p4-016 EPUB Zip Slip | DROP | LOW | — | Per policy: Low severity dropped |
| p4-017 Snapshot Symlink Attack | DROP | LOW | — | Per policy: Low severity dropped |
| p4-018 WiFi HTML Misleading Formats | DROP | INFO | — | Per policy: Info severity dropped |
| p4-019 CI Benchmark No Sandbox | DROP | INFO | — | Per policy: Info severity dropped |
| p4-020 OpenAI Translator SSRF | DUPLICATE | — | — | Merged into p8-001 |
| l4-001 SSRF Translation API URL | DUPLICATE | — | — | Merged into p8-001 |
| l4-002 Backup Restore DB Overwrite | DUPLICATE | — | — | Merged into p8-006 |
| l4-003 Backup Export Unvalidated Dest | DUPLICATE | — | — | Merged into p8-005 |
| l4-004 Retry Amp SSRF | DROP | LOW | — | Per policy: Low severity dropped |
| l4-005 Bincode Unmaintained | DUPLICATE | — | — | Merged into p8-008 |
| q2-001 API Key Plaintext | VALID | MEDIUM | p8-004 | Merged into p8-004 |
| q2-002 validate_file_path no confinement | VALID | MEDIUM | p8-002 | Merged into p8-002 |
| q2-003 Cover Output Path Traversal | VALID | MEDIUM | p8-007 | Merged into p8-007 |
| q2-004 Multipart Parser Fragile | DROP | LOW | — | Handler disabled; per policy dropped |
| q2-005 Wrong Addr Advertised | DROP | LOW | — | Security-positive bug; per policy dropped |

## Surviving Findings (P8)

| # | Slug | Severity | Draft |
|---|------|----------|-------|
| 1 | SSRF via Translation API URL | HIGH | p8-001-ssrf-translation-api-url.md |
| 2 | validate_file_path No Confinement | MEDIUM | p8-002-validate-file-path-no-confinement.md |
| 3 | WiFi Upload No Authentication | MEDIUM | p8-003-wifi-upload-no-auth.md |
| 4 | API Key Plaintext in SharedPreferences | MEDIUM | p8-004-api-key-plaintext-sharedpreferences.md |
| 5 | Database Export Path Traversal | MEDIUM | p8-005-export-database-path-traversal.md |
| 6 | Database Restore Path Traversal | MEDIUM | p8-006-restore-database-path-traversal.md |
| 7 | Cover Extraction Output Path Traversal | MEDIUM | p8-007-cover-output-path-traversal.md |
| 8 | Bincode Unmaintained Crate | MEDIUM | p8-008-bincode-unmaintained-crate.md |

## Severity Normalization Rationale

| Finding | Original Severity | Normalized | Rationale |
|---------|------------------|------------|-----------|
| p4-001 SSRF | CRITICAL | HIGH | Requires user to configure URL (social engineering precondition); downgraded from CRITICAL. HIGH retained because credential forwarding is active and automatic after setup. |
| p4-002 Path Validation | HIGH | MEDIUM | Mobile OS sandbox limits blast radius; requires user file selection on desktop. Non-destructive read access only. |
| p4-003 WiFi No Auth | CRITICAL | MEDIUM | Currently disabled (intentional no-op); not remotely exploitable. MEDIUM as dormant code risk/time-bomb pattern. |
| p4-004 API Key Plaintext | HIGH | MEDIUM | Requires root/ADB access to exploit. Not remotely triggerable. |
| p4-005 Export Path | HIGH | MEDIUM | Requires internal API access (FRB). Not directly externally callable. |
| p4-006 Restore Path | HIGH | MEDIUM | Same as p4-005; requires internal API access. |
| p4-007 Cover Path | MEDIUM | MEDIUM | Currently mitigated by correct Dart caller. Defense-in-depth. |
| p4-009 Bincode | MEDIUM | MEDIUM | Future risk; no current exploit. Correct error handling. |

## Key Patterns

1. **SSRF + Credential Forwarding (HIGH)**: Translation API URL accepts any HTTPS endpoint; credentials sent automatically. Most impactful finding.
2. **Missing Base-Directory Confinement (MEDIUM)**: Systemic pattern across `validate_file_path` affecting 8+ FRB callers. Write variants (export/restore) are higher risk than read variants.
3. **Inconsistent Credential Storage (MEDIUM)**: API key in plaintext SharedPreferences while WebDAV password uses FlutterSecureStorage.
4. **Dormant Code Risk (MEDIUM)**: WiFi upload server code exists, registered, UI present, but disabled by intent. One-line re-enablement creates CRITICAL risk.
5. **Unmaintained Dependency (MEDIUM)**: bincode 2.0.1 unmaintained; graceful error handling reduces but doesn't eliminate future risk.

## Variant Candidates

- `validate_file_path` pattern (p8-002) should be checked in any Rust code path that accepts `file_path` or `dest_path` from FFI
- SSRF pattern (p8-001) should be checked in any Dart code that sends HTTP requests with user-configurable URLs
- Plaintext credential storage pattern (p8-004) should be checked for any new `PersistedSignal<String>` that stores sensitive data

## Counts

- Original drafts reviewed: 29 (20 p4 + 5 l4 + 4 q2)
- Surviving findings (p8): 8
- Rejected (LOW/INFO): 12
- Duplicates: 6
- False Positives: 1
- Patterns added to registry: 5
