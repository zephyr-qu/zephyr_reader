---
id: q2-006
phase: Q2
slug: file-path-validation-lacks-symlink-boundary-check
severity: low
---

# File Path Validation Lacks Directory Boundary Symlink Check

## Location

- `src/common/security.rs` (lines 13-28) — `validate_file_path`

## Description

The `validate_file_path` function canonicalizes the path (resolving symlinks) but performs **no check** that the resolved path falls within an expected application directory. This means a symlink at the user-controlled path could redirect file operations outside the intended sandbox:

```rust
pub fn validate_file_path(path_str: &str) -> Result<String, AppError> {
    let path = Path::new(path_str);
    if !path.exists() {
        return Err(AppError::FileNotFound { path: path_str.into() });
    }
    if !path.is_file() {
        return Err(AppError::FileReadError { ... });
    }
    let canonical = path.canonicalize().map_err(...)?;
    Ok(canonical.to_string_lossy().to_string())   // ✅ canonicalized but ❌ not bounded
}
```

## Impact

In a scenario where an attacker can control a symlink (e.g., via a malicious EPUB that extracts a symlink during import), the validated path could resolve outside the expected books directory. This would allow reading files outside the intended scope. In practice, this is low severity for a local app since:
- EPUB imports don't create symlinks
- The app doesn't have a chroot/sandbox

## Attacker Control

The file_path parameter comes from the Flutter UI layer.

## Runtime

Local application process.

## Trust Boundary

Path validation should ensure the file is within expected bounds.

## Reachability

**reachable** — used by many public API functions.

## Recommendation

Add a boundary check after canonicalization to ensure the resolved path is within the application's data directory:

```rust
pub fn validate_file_path(path_str: &str, allowed_base: Option<&Path>) -> Result<String, AppError> {
    // ... existing checks ...
    let canonical = path.canonicalize()?;
    if let Some(base) = allowed_base {
        let base_canonical = base.canonicalize()?;
        if !canonical.starts_with(&base_canonical) {
            return Err(AppError::SecurityError {
                reason: "path outside allowed directory".into(),
                path: path_str.into(),
            });
        }
    }
    Ok(canonical.to_string_lossy().to_string())
}
```

Note: This would require updating all call sites to provide the allowed base directory.
