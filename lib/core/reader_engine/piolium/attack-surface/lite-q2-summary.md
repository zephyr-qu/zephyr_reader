# Q2 Static Analysis Summary — Lite Mode

Generated: 2026-07-17
Target: `F:/App/zephyr_reader/lib/core/reader_engine`
Backend: grep (file content pattern analysis + manual review)

## Findings Produced

| ID | Slug | Severity | Category |
|----|------|----------|----------|
| q2-001 | sensitive-file-path-logging | medium | Information Disclosure |
| q2-002 | file-path-revalidation-gap | medium | Path Traversal / Access Control |
| q2-003 | image-load-no-size-limits | low | Resource Exhaustion (DoS) |
| q2-004 | unauthenticated-network-surface | high | Pre-auth Attack Surface |

## Coverage

- **Command Injection**: Not detected — no `Process.run`, `exec`, or shell invocation in reader_engine Dart code.
- **Path Traversal**: Medium risk identified via file path re-validation gap (q2-002). Rust layer has `validate_file_path` but Dart passes `filePath` from Book model without re-validation.
- **SSRF**: Not detected — no HTTP client instantiation inside reader_engine.
- **Hardcoded Crypto/Secrets**: Not detected — no cryptographic material in reader_engine.
- **Broken Authn/z**: The app does not implement per-user authentication (single-device app). WifiTransferService (pre-auth, network-facing) provides an entry point into the import pipeline.

## SAST Tools

CodeQL and Semgrep were not executed (not installed in this environment). Pattern analysis used `grep` + manual source review of all 46 Dart files (100% coverage of reader_engine).

## Pre-auth Surface Classification

See `unauthenticated-surface.md` for full enumeration.

### By-design pre-auth
- None within reader_engine boundary — no network-facing code.

### Missing-guard pre-auth  
- WifiTransferService HTTP upload endpoint (outside reader_engine boundary, but listed because it feeds reader_engine)

### Middleware-gap
- None identified

## Rust Audit Cross-Reference

The Rust API layer (`rust/src/api/`) was separately audited in an earlier Q2 pass and produced 8 findings (q2-001 through q2-008). The reader_engine Dart layer adds 4 distinct findings. Together they cover:
- Path traversal in cover extraction and deletion (Rust)
- LIKE injection in note search (Rust)
- Missing authz in FRB API layer (Rust)
- Symlink bypass in validate_file_path (Rust)
- Sensitive file path logging (Dart, new)
- File path re-validation gap at Dart→Rust boundary (Dart, new)
- Image load without size limits (Dart, new)
- Pre-auth network surface via WiFi transfer (new, cross-boundary)

## Time Budget

~4 minutes wall-clock used. Lite mode constraints satisfied.
