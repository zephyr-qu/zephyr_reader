# [M2] `validate_file_path` Lacks Directory-Base Confinement

## Summary

The `validate_file_path` function in [`common/security.rs`](https://github.com/2084035767/zephyr_reader/blob/23e2192cd8c9f64996dc344a8c2b7bb3067cddb6/rust/src/common/security.rs#L18-L36) verifies that a path exists and is a regular file, then returns its canonicalized form — but never checks whether the canonical path stays within an expected base directory (e.g., the application's data directory). Every critical file-read API in the crate delegates path validation to this function, so any caller that trusts it for scope enforcement will accept attacker-chosen file paths outside the intended sandbox. On desktop builds where the process has broad filesystem access, this enables arbitrary file read via EPUB parsing endpoints and database overwrite via `restore_database`.

## Details

### The Vulnerable Validation Function

All file-access paths in the application flow through a single gate in [`rust/src/common/security.rs`](https://github.com/2084035767/zephyr_reader/blob/23e2192cd8c9f64996dc344a8c2b7bb3067cddb6/rust/src/common/security.rs#L18-L36):

```rust
pub fn validate_file_path(path_str: &str) -> Result<String, AppError> {
    let path = Path::new(path_str);
    if !path.exists() {
        return Err(AppError::FileNotFound { path: path_str.into() });
    }
    if !path.is_file() {
        return Err(AppError::FileReadError {
            path: path_str.into(),
            details: "path is not a file".into(),
        });
    }
    let canonical = path.canonicalize().map_err(|e| AppError::FileReadError {
        path: path_str.into(),
        details: e.to_string(),
    })?;
    Ok(canonical.to_string_lossy().to_string())
}
```

The function performs only two checks — existence and file-type — then returns a canonical path. There is **no comparison against an allowed base directory**. A path like `C:\Windows\win.ini` or `/etc/passwd` passes if the file exists and is readable.

### Call Sites That Trust This Function

Every endpoint below calls `validate_file_path` and uses the returned path for a file operation without additional scope checking:

| API / Function | File | What It Does With the Path |
|---|---|---|
| `get_epub_metadata` | [`rust/src/api/book.rs`](https://github.com/2084035767/zephyr_reader/blob/23e2192cd8c9f64996dc344a8c2b7bb3067cddb6/rust/src/api/book.rs#L215-L241) | Opens and parses EPUB metadata |
| `get_processed_epub_image_bytes` | Same file | Reads + decodes an EPUB image |
| `get_processed_epub_image` | Same file | Reads + decodes + caches an EPUB image |
| `import_book` | [`rust/src/domain/book/service.rs`](https://github.com/2084035767/zephyr_reader/blob/23e2192cd8c9f64996dc344a8c2b7bb3067cddb6/rust/src/domain/book/service.rs#L177) | Validates → parses → stores book |
| `extract_book_cover` | [`rust/src/domain/cover/service.rs`](https://github.com/2084035767/zephyr_reader/blob/23e2192cd8c9f64996dc344a8c2b7bb3067cddb6/rust/src/domain/cover/service.rs#L16) | Extracts cover art from the file |
| `export_database` | [`rust/src/domain/backup/service.rs`](https://github.com/2084035767/zephyr_reader/blob/23e2192cd8c9f64996dc344a8c2b7bb3067cddb6/rust/src/domain/backup/service.rs#L146-L198) | Copies reader.db to destination |
| `restore_database` | Same file | Overwrites reader.db with backup file |
| `inspect_backup` | Same file | Reads backup manifest from file |

### The Most Severe Attack Surface: `restore_database`

The backup restore function in [`rust/src/domain/backup/service.rs`](https://github.com/2084035767/zephyr_reader/blob/23e2192cd8c9f64996dc344a8c2b7bb3067cddb6/rust/src/domain/backup/service.rs#L208-L227) is the most dangerous exploitation path:

```rust
pub async fn restore_database(backup_path: String) -> Result<BackupManifest, AppError> {
    let validated = validate_file_path(&backup_path)?;   // no scope check
    let storage = ensure_storage()?;
    // ... validates manifest, then:
    storage.restore_from_backup(&validated).await?;      // overwrites reader.db
}
```

An attacker who controls the `backup_path` argument can point it at any SQLite file on the filesystem. If that file passes the manifest inspection (containing a `_backup_meta` table), the function **overwrites the live `reader.db`** with the attacker-supplied content.

### Vulnerability Classification

- **CWE-22**: Improper Limitation of a Pathname to a Restricted Directory ("Path Traversal")
- **CWE-23**: Relative Path Traversal
- **Attack vector**: Network-based (if the API is exposed via FFI/bridge) or local (file picker, CLI argument)

## Root Cause

The design of `validate_file_path` conflates "the path is a real file" with "the path is authorised." The function canonicalises the path (which does prevent simple `../` traversal against the current directory) but stops there — it never enforces that the canonical path begins with an allowed base directory such as the application's data directory, the user's document directory, or a caller-supplied root.

This is a validation-scope mismatch: every caller that needs scope confinement must re-implement the base-directory check independently. Most call sites do not.

## Proof of Concept (PoC)

Five Rust integration tests in [`rust/tests/poc_path_escape.rs`](https://github.com/2084035767/zephyr_reader/blob/23e2192cd8c9f64996dc344a8c2b7bb3067cddb6/rust/tests/poc_path_escape.rs) demonstrate the vulnerability. They were executed under the PoC runner at `piolium/findings/M2-validate-file-path-no-base-confinement/poc.sh` and **all five pass**, confirming the issue.

### PoC Setup and Execution

A standalone bash script orchestrates the tests:

```
cd rust
cargo test --test poc_path_escape -- --show-output
```

### Test Results (excerpts from evidence)

**Test 1 — Basic Escape (`test_poc_escape_basic`):**
A file created in `outside_dir` (outside the sandbox `TempDir`) is accepted by `validate_file_path` and canonicalised successfully. The sandbox boundary is never checked.

```
[PoC-EVIDENCE] validate_file_path ESCAPE CONFIRMED
  Sandbox dir:         /tmp/.../sandbox/
  Attacker target:     /tmp/.../outside/secret_config.ini
  Canonicalized path:  /tmp/.../outside/secret_config.ini (ACCEPTED — no base check!)
  Is outside sandbox?  YES
```

**Test 2 — Windows System File (`test_poc_path_traversal`):**
On Windows, `C:\Windows\win.ini` passes `validate_file_path` without restriction:

```
[PoC-EVIDENCE] WINDOWS SYSTEM FILE READ CONFIRMED
  Input:  C:\Windows\win.ini
  Output: C:\Windows\win.ini (accepted, no base check!)
  Impact: Arbitrary system file read via validate_file_path
```

**Test 4 — Database Restore Escape (`test_poc_restore_database_scope_escape`):**
A minimal SQLite database created outside the sandbox is accepted by `validate_file_path`. This confirms that an attacker-supplied path reaches `restore_from_backup()` and can overwrite the live database:

```
[PoC-EVIDENCE] restore_database SCOPE ESCAPE CONFIRMED
  Malicious backup:     /tmp/.../outside/evil_backup.db
  Validated path:       /tmp/.../outside/evil_backup.db (accepted, no base check)
  Is outside sandbox?   YES
  Attack chain:
    1. Attacker controls backup_path argument to restore_database()
    2. validate_file_path(backup_path) accepts ANY file path
    3. restore_from_backup() overwrites reader.db with attacker file
```

### Running the PoC

```bash
# From the repository root, execute the PoC script:
./piolium/findings/M2-validate-file-path-no-base-confinement/poc.sh

# Or run the tests directly:
cd rust && cargo test --test poc_path_escape -- --show-output
```

Expected outcome: All five tests pass, each printing `[PoC-EVIDENCE]` lines confirming that `validate_file_path` accepts paths outside any intended sandbox.

## Impact

**Desktop builds (high risk):** On Windows, macOS, or Linux where the process has the same filesystem privileges as the user, an attacker who controls a `file_path` argument can:

- **Read arbitrary files** through `get_epub_metadata`, `get_processed_epub_image_bytes`, or `get_processed_epub_image` — the EPUB parser acts as an oracle, returning parsed content from any file the process can read.
- **Overwrite the live database** via `restore_database` by pointing it at a crafted SQLite backup file, causing data corruption or denial of service.
- **Access system configuration files** (e.g., `C:\Windows\win.ini`, `/etc/passwd`) through any of the validated-path endpoints.

**All platforms (confusion vector):** Even on mobile platforms where the OS sandbox limits the blast radius to the app's own container, a confused user or a compromised file picker could trigger the parser on a non-book file, wasting I/O or causing a crash.

**Preconditions:**
- The attacker must be able to supply a `file_path` argument to one of the vulnerable APIs (via FFI bridge, CLI argument, file picker, or another injection vector).
- On desktop platforms, no additional sandbox escape is needed — the process already has the user's filesystem permissions.
- Authentication is **not required**; the APIs are exposed to anonymous callers.

## Remediation

Add a base-directory check to `validate_file_path` (or introduce a scoped variant) so that the function enforces path confinement at the single validation gate rather than relying on every caller to do so:

```rust
pub fn validate_file_path_in(
    path_str: &str,
    allowed_base: &Path,
) -> Result<String, AppError> {
    let path = Path::new(path_str);
    if !path.exists() {
        return Err(AppError::FileNotFound { path: path_str.into() });
    }
    if !path.is_file() {
        return Err(AppError::FileReadError {
            path: path_str.into(),
            details: "path is not a file".into(),
        });
    }
    let canonical = path.canonicalize().map_err(|e| AppError::FileReadError {
        path: path_str.into(),
        details: e.to_string(),
    })?;
    if !canonical.starts_with(allowed_base) {
        return Err(AppError::SecurityError {
            reason: "path escapes allowed directory".into(),
            path: path_str.into(),
        });
    }
    Ok(canonical.to_string_lossy().to_string())
}
```

Each call site should then pass the appropriate base directory — typically the application's data directory or the user's document import directory — as `allowed_base`. For `export_database` and `restore_database`, the allowed base should be the application's designated backup directory, and write-target paths should be validated separately against that same base.
