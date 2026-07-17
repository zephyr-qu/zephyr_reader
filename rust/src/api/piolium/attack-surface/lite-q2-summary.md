# Q2 Lite SAST Summary

**Phase**: Q2 — Lite-Mode Static Analysis  
**Generated**: 2026-07-17  
**Mode**: lite (grep + manual review, no CodeQL/Semgrep databases)  
**Target**: `F:/App/zephyr_reader/rust/src/api` (and supporting domain layer)

## Methodology

- **Tooling**: grep + manual source code review (no CodeQL/Semgrep databases built)
- **Scope**: All 17 API modules + 20+ domain/repository files (total ~42KB Rust source)
- **Patterns**: Path traversal, injection, hardcoded credentials, authentication gaps, command injection, SSRF, unsafe file operations
- **Budget**: Under 5 minutes wall-clock (lite mode)

## Architecture Context

This is a **local-only Flutter-to-Rust application** using `flutter_rust_bridge` (FRB) for IPC. There is no network service, HTTP endpoint, or authentication layer. The Rust library runs embedded in the Flutter app process. All "attackers" are local: compromised Flutter/dart code, untrusted file inputs, or malicious EPUB content.

## Findings Summary

| ID | Slug | Severity | Category |
|----|------|----------|----------|
| q2-001 | cover-extraction-output-dir-path-traversal | **medium** | Path Traversal / Arbitrary Write |
| q2-002 | delete-book-cover-path-traversal | **medium** | Path Traversal / Arbitrary Delete |
| q2-003 | note-search-like-wildcard-injection | low | SQL Injection / Information Leak |
| q2-004 | dictionary-engine-unvalidated-file-path | low | Unvalidated File Path |
| q2-005 | export-destination-path-validation | low | UX / Design Issue |
| q2-006 | file-path-validation-lacks-symlink-check | low | Path Validation Gap |
| q2-007 | create-web-book-cover-path-unvalidated | low | Unvalidated Input → DB |
| q2-008 | no-authentication-authorization-frb-api | low | Architecture / Defense-in-depth |

## Top Risks

1. **q2-001** (Medium): Unvalidated `output_dir` in cover extraction allows writing cover image files to arbitrary directories on the filesystem.
2. **q2-002** (Medium): Unvalidated `covers_dir` + stored `cover_path` in `delete_book` allows deleting arbitrary files.
3. **q2-003** (Low): Missing `%`/`_` escaping in note search LIKE query allows unintended record matching.

## Coverage Analysis

### Not Applicable (Checked and Found Absent)
- **Command injection**: No `std::process::Command`, `tokio::process`, or shell execution found.
- **SSRF**: No HTTP client libraries (`reqwest`, `hyper`) in dependencies.
- **Hardcoded secrets**: No API keys, passwords, tokens, or JWT secrets found.
- **Cryptographic weaknesses**: No custom crypto; only `md5` used for file hashing (acceptable for non-security use).

### Defensive Patterns Observed
- `validate_file_path()` consistently used for input file paths (import, EPUB metadata, chapter reading)
- SQL parameterized queries used throughout (no raw string interpolation)
- FTS5 search queries properly escaped with phrase-wrapping
- LIKE wildcards escaped in `BookRepository::search` and `VocabRepository::search`
- Cover filename sanitized (alphanumeric only) in `EpubCoverExtractor`

### Gaps
- No output path validation function (only `validate_file_path` for existing files)
- `NoteRepository::search` missing LIKE wildcard escaping (inconsistent with sibling repos)
- Dictionary engine bypasses all path validation
- No symlink boundary check in `validate_file_path`

## Batching / Throttling Notes

- Lite mode: single-pass grep + review, no parallel tool orchestration needed.
- CodeQL/Semgrep databases were not built per lite mode constraints.
- Trust boundaries identified: FRB IPC bridge, filesystem write paths, SQLite LIKE queries.
