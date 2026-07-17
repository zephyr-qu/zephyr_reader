# Unauthenticated Surface — Reader Engine & Adjacent

## Scope

This document enumerates what an anonymous attacker (no session, token, or API key) can reach. The target is the `reader_engine` Dart library. Adjacent services that feed into the engine are also noted.

## Network Surface

The `reader_engine` library itself contains **no network-facing code** — it is strictly a client-side rendering library. However, the enclosing app `zephyr_reader` includes several network components outside the engine boundary that can reach it.

### WifiTransferService (`lib/core/network/wifi_transfer_service.dart`)

| Property | Value |
|----------|-------|
| Protocol | HTTP |
| Port | Configurable via settings (default unknown) |
| Auth | ❌ None |
| Type | File upload / web UI |
| Feeds into | Book import pipeline → reader_engine |
| Why pre-auth | by-design (intended for convenience, no security model) |

Entry: `POST <device-ip>:<port>/upload` with multipart file attachment.
Accepted extensions: `txt`, `epub`.
No CSRF, no session, no rate limit.

### Dio HTTP Client (`lib/core/network/network_module.dart`)

| Property | Value |
|----------|-------|
| Base URL | `https://api.example.com` (placeholder) |
| Auth | Not yet configured |
| Active calls | None currently — placeholder base URL |
| Why pre-auth | by-design placeholder, not functional |

The Dio client includes:
- `LogInterceptor` with `requestBody: true, responseBody: true` — would log all HTTP traffic bodies in production if activated
- Retry interceptor with exponential backoff
- Error logging interceptor

### Open AI Translator (`lib/features/bilingual/data/providers/openai_translator.dart`)

| Property | Value |
|----------|-------|
| Protocol | HTTPS |
| Auth | API key (user-provided) |
| Why pre-auth | by-design — requires API key configuration |

Not pre-auth because an API key must be configured. Included for completeness.

## Local Attack Surface (Physical Access)

Since this is a mobile/desktop app, a local attacker with access to the device filesystem can reach:

### SQLite Database
- Location: Application data directory (platform-specific)
- Contents: Books, notes, reading progress, bookmarks, search index
- No encryption at rest

### Log Files
- The `Logging` system writes structured logs containing file paths, book IDs, timing data
- Log output destination depends on `Logging` backend configuration
- See finding q2-001 for paths logged

## Attack Chains

### Chain 1: LAN → Import → Reader Engine
```
[Attacker on LAN]
  → POST to WifiTransferService:80/upload (no auth)
  → File saved to app storage
  → User opens book
  → ReaderEngine loads EPUB
  → Rust API processes file (validate_file_path, canonicalize)
  → Rust IR extraction runs on attacker-controlled file
  → Dart paginator processes attacker-controlled text & images
```

### Chain 2: Physical Access → Database Tampering → Path Traversal
```
[Attacker with device access]
  → Modify SQLite Book.file_path
  → User opens book
  → ReaderEngine calls getBook(bookId) → returns tampered path
  → Dart passes filePath to Rust reader API
  → Rust reads attacker-specified file path
```

## Coverage Gaps

| Area | Status |
|------|--------|
| Route enumeration | `<coverage gap>` — No HTTP router exists in reader_engine |
| WifiTransferService: full request handler analysis | `<coverage gap>` — Only partial read of wifi_transfer_service.dart performed. Full HTTP handler logic not reviewed. |
| Dio: actual call sites | `<coverage gap>` — The placeholder URL may be replaced at runtime with a configured URL. Call sites that trigger Dio requests haven't been fully mapped. |
| Authentication guard implementation | `<coverage gap>` — No auth middleware exists to analyze. |

## Summary

The reader_engine itself is not network-addressable. Its pre-auth exposure is entirely via:
1. **WifiTransferService** (cross-boundary, pre-auth file upload)
2. **Physical device access** (database tampering)

Both can feed attacker-controlled data into the reader_engine and Rust file-processing pipeline.
