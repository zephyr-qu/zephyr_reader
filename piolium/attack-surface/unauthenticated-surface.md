# Unauthenticated Attack Surface

Reachable by an anonymous attacker — no valid session, token, or API key.

**Coverage**: 5 entry points | 4 by-design public | 1 missing-guard / middleware-gap
**Auth model**: None — this is a local-first mobile app with no authentication system. No login, no session, no API key gating, no user identity concept.
**Coverage gaps**: None identified — all routes and HTTP endpoints are statically declared.

---

## Pre-Auth HTTP / API Routes

The only HTTP server is the WiFi Transfer Service (dart:io HttpServer). It is **disabled by default** and bound to **loopback only** (127.0.0.1).

| # | Method | Path | Handler (file:line) | Why pre-auth | Notable inputs / sinks | Blast radius |
|---|--------|------|---------------------|--------------|------------------------|--------------|
| 1 | GET | / | WifiTransferService._servePage (wifi_transfer_service.dart:~120) | missing-guard | Serves static HTML upload page | Information disclosure (device name, LAN IP) |
| 2 | POST | /upload | WifiTransferService._handleUpload (wifi_transfer_service.dart:~125) | missing-guard | Multipart file upload: filename, file bytes. Written to temp dir, parsed by Rust EPUB/TXT parser | File write to temp dir, parser attack surface, temp file race window |
| 3 | GET | /api/status | WifiTransferService._serveJson (wifi_transfer_service.dart:~130) | missing-guard | None | Minimal status disclosure |

**Classification note**: All three endpoints are classified as **missing-guard** because they lack any form of authentication despite handling file uploads. They are currently protected only by the loopback bind address. If the bind is ever changed to 0.0.0.0, these become LAN-wide unauthenticated critical attack surface.

---

## Other Unauthenticated Entry Points

| Kind | Entry point (file:line) | Why pre-auth | Notes |
|------|-------------------------|--------------|-------|
| Deep link handler | app_router.dart:_resolveDeepLink (app_router.dart:17-28) | by-design | zephyr:// URI scheme and zephyr.app host redirect to internal routes. Any app on device can trigger navigation to reader, bookshelf, vocabulary, search pages. No auth because no auth system exists. |
| Splash / home route | go_router initialLocation = AppRoute.splash.path (app_router.dart:36) | by-design | App start navigation; no sensitive data exposed |
| Static assets | assets/html/wifi_upload_page.html, assets/dictionary.mdx, assets/fonts/ | by-design | Accessible locally. Static assets bundled with app. |
| Local file system (via file picker) | BookImportService.importBook, scanFolder | by-design | User-selected files via OS file picker. OS controls which files the app can access. |

---

## Assessment

This is a **local-first Flutter mobile app** with no user authentication system. There is no login page, no session management, no API key gating, and no user identity concept. All data is stored locally in SQLite/redb databases and on the filesystem.

### No Remote Pre-Auth Surface

The app exposes **no network services** in normal operation. The WiFi Transfer HTTP server is:

- **Disabled by default** (the start() method is a no-op, per code comment)
- **Bound to loopback** (127.0.0.1) even when active
- **Without authentication, CSRF protection, or rate limiting** — making it a critical risk if the bind address were ever changed to anyIPv4

### Local-Layer Risks

| Risk | Detail |
|------|--------|
| Temp file exposure | Uploaded files written to Directory.systemTemp (world-readable on desktop) |
| API key in SharedPreferences | Translation API key stored in plaintext XML (device-root required to read) |
| WebDAV password in FlutterSecureStorage | Properly encrypted but still accessible on rooted device |
| Deep link handling | zephyr:// scheme can be triggered by any app on device |
| SSRF via translation settings | User-configurable API URL allows arbitrary HTTPS POST requests |

### Configuration Weakness

The WiFi transfer HTML page (`assets/html/wifi_upload_page.html`) advertises support for `.pdf`, `.md`, `.markdown` formats in its file input `accept` attribute, but the server-side handler only accepts `.txt` and `.epub`. This inconsistency could confuse users who attempt to upload unsupported formats and receive an opaque rejection.

