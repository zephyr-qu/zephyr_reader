---
id: H1
phase: Q2
slug: unauthenticated-network-surface
severity: high
original_id: q2-004
PoC-Status: executed
Protocol: http
Auth-Required: no
Auth-Roles-Required: anonymous
---

# Pre-Auth Network-Attackable Surface Through WifiTransferService

> **Note**: The `WifiTransferService` is defined outside the `reader_engine` target boundary (`lib/core/network/wifi_transfer_service.dart`), but it directly feeds data into the reader engine's import pipeline. It is enumerated here because it is the primary pre-auth entry point for the engine's data processing.

## Location

- `lib/core/network/wifi_transfer_service.dart` — HTTP server with file upload
- `lib/features/bookshelf/page/wifi_transfer_page.dart` — UI trigger
- `lib/core/network/network_module.dart` — Dio HTTP client (placeholder, not yet used)

## Description

The app includes an HTTP file upload server started via the WiFi Transfer feature. The service:

1. Binds to `HttpServer` on a configurable local port.
2. Serves an HTML upload page.
3. Accepts file uploads without authentication, CSRF protection, or rate limiting.
4. Accepts `txt` and `epub` file extensions.
5. Passes uploaded files into the book import pipeline.

The `network_module.dart` configures a `Dio` HTTP client with a placeholder `baseUrl` (`https://api.example.com`) which is not yet connected to a real backend but includes:
- Retry interceptor (exponential backoff, up to 3 retries)
- `LogInterceptor` logging request and response bodies
- Error logging interceptor

## Evidence

From `wifi_transfer_service.dart`:
```dart
class WifiTransferService {
  final PreferencesService _prefs;
  HttpServer? _server;
  bool _running = false;
  int _port = 0;
  String _localIp = '';
  final _supportedExtensions = {'txt', 'epub'};
  // ...
}
```

The `_supportedExtensions` set restricts uploads to `txt` and `epub`, but there is no:
- Authentication mechanism
- Session management  
- Upload rate limiting
- File content validation before storage

## Impact

An attacker on the same LAN segment can:
1. Upload arbitrarily crafted EPUB/TXT files to the device.
2. Trigger the app's full import pipeline — IR extraction, image decoding, pagination.
3. Exploit any bugs in the Rust EPUB parser or Dart paginator.
4. Potentially fill device storage with uploads (no rate limit or quota).

**Pre-auth reachability**: YES. This is a pre-authenticated, network-reachable entry point. No session, token, or API key required. The service is reachable on `http://<device-ip>:<port>` from any LAN client.

## Root Cause

The Wi-Fi transfer feature was designed for convenience, not with a threat model. It treats the LAN as a trusted network, which is not a valid security assumption.

## Recommendation

1. Add a one-time PIN or QR-code-based authorization for Wi-Fi transfer sessions.
2. Add upload rate limiting (max 1 file per 5 seconds, max 5 files per minute).
3. Add file size limits at the HTTP server level.
4. Sanitize filenames from upload requests before passing to the filesystem.
5. Validate file content against magic bytes before accepting.
