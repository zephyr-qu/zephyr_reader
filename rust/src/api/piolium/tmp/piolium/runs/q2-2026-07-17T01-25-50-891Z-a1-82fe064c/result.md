All deliverables are in place. Here's the Q2 completion summary:

## Q2 Lite SAST — Complete

### Outputs Written

| Path | Description |
|------|-------------|
| `piolium/findings-draft/q2-001-*.md` | Medium — Cover extraction arbitrary file write |
| `piolium/findings-draft/q2-002-*.md` | Medium — delete_book arbitrary file deletion |
| `piolium/findings-draft/q2-003-*.md` | Low — Note search LIKE wildcard injection |
| `piolium/findings-draft/q2-004-*.md` | Low — Dictionary unvalidated file path |
| `piolium/findings-draft/q2-005-*.md` | Low — Export destination path UX issue |
| `piolium/findings-draft/q2-006-*.md` | Low — File path validation lacks symlink boundary |
| `piolium/findings-draft/q2-007-*.md` | Low — create_web_book unvalidated cover_path stored |
| `piolium/findings-draft/q2-008-*.md` | Low — No authz in FRB API layer |
| `piolium/attack-surface/lite-q2-summary.md` | Phase summary with findings table |
| `piolium/attack-surface/unauthenticated-surface.md` | Pre-auth entry point enumeration |

### Key Findings

1. **q2-001 (Medium)**: `extract_book_cover` writes files to unvalidated `output_dir` — directory traversal in cover extraction pipeline
2. **q2-002 (Medium)**: `delete_book` uses caller-supplied `covers_dir` + DB-stored `cover_path` to construct file deletion paths without validation
3. **q2-003 (Low)**: `NoteRepository::search` missing `%`/`_` escaping inconsistent with sibling repos

### Security Posture

This is a local-only Flutter+Rust e-reader with no network surface. The most impactful issues are filesystem path traversals in cover extraction and deletion. No command injection, SSRF, hardcoded credentials, or crypto weaknesses were found. Defensive patterns (parameterized SQL, FTS5 query escaping, file path validation on inputs) are used inconsistently across the codebase.

### Coverage Note

Running in lite mode — CodeQL/Semgrep databases were not built. Analysis used grep + manual review across all 37 source files (~42KB Rust).
