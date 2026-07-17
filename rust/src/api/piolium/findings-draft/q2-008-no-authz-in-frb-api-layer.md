---
id: q2-008
phase: Q2
slug: no-authentication-authorization-frb-api
severity: low
---

# Zero Authentication/Authorization in FRB API Layer

## Location

- All `src/api/*.rs` files — all public `#[frb]` functions

## Description

The entire Rust API surface (17 modules, ~100+ public functions) is exposed through `flutter_rust_bridge` (FRB) with **zero authentication, authorization, or access control**. Any Flutter code running in the same process can call any function without restriction.

While this is by design for a local e-reader application (FRB is an IPC bridge, not a network service), the lack of any access control means any compromise of the Flutter layer (XSS via WebView, untrusted plugin, or supply chain attack) gains full access to all data and operations:

| Operation | Impact |
|-----------|--------|
| `delete_book` | Delete any book + cover file |
| `export_database` / `restore_database` | Access all reading data |
| `delete_note` / `delete_bookmark` | Destructive data manipulation |
| `list_books` / `get_book_detail` | Read all book metadata |

## Impact

- No privilege separation between different parts of the application
- Any code execution in the Flutter layer (e.g., via a compromised dependency) has full access to all reading data
- No audit trail for destructive operations

## Attacker Control

Not applicable — this is an architectural observation.

## Runtime

Flutter/Dart process connected via FRB IPC.

## Trust Boundary

The FRB boundary is treated as trusted, but there's no defense-in-depth.

## Reachability

All functions are reachable from Flutter.

## Recommendation

For a local-only app, formal auth is unnecessary. However, consider:
1. **Function-level capability checks**: Wrapper functions that require user confirmation before destructive operations
2. **Audit logging**: Log all destructive operations (delete, export, restore) to a separate audit log
3. **Confirmation dialogs**: Ensure the Flutter side shows confirmation for sensitive operations before calling the Rust layer
