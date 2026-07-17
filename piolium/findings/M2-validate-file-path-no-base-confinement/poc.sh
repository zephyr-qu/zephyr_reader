#!/usr/bin/env bash
# PoC: M2-validate-file-path-no-base-confinement
#
# Demonstrates that validate_file_path() in common/security.rs
# does NOT confine paths to a base directory, allowing arbitrary
# file read within process permissions.
#
# Attack chain:
#   Attacker-controlled file_path → validate_file_path (no scope check)
#   → downstream: get_epub_metadata, import_book, extract_book_cover,
#     restore_database, inspect_backup, get_processed_epub_image_bytes
#
# Usage: ./poc.sh
#   Last stdout line is a JSON status object for automated parsing.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RUST_DIR="$(cd "$SCRIPT_DIR/../../../rust" && pwd)"
EVIDENCE_DIR="$SCRIPT_DIR/evidence"

echo "=== M2 PoC: validate_file_path No Base Confinement ==="
echo "Project dir: $RUST_DIR"
echo "Evidence dir: $EVIDENCE_DIR"
echo ""

# Run all PoC tests with output
cd "$RUST_DIR"
cargo test --test poc_path_escape -- --show-output 2>&1
EXIT_CODE=$?

echo ""
echo "=== PoC Summary ==="
if [ $EXIT_CODE -eq 0 ]; then
    echo "All 5 exploit tests PASSED — vulnerability confirmed."
    echo ""
    echo "Key findings:"
    echo "  1. Files outside sandbox accepted by validate_file_path"
    echo "  2. Windows system file (win.ini) accepted via validate_file_path"
    echo "  3. Relative path traversal resolves without scope check"
    echo "  4. restore_database scope escape confirmed (malicious backup DB accepted)"
    echo "  5. Cover extraction chain exploitable via path escape"
    echo "  6. Whitelist violation — any directory's file is valid"
    
    # JSON status line (LAST stdout line — for poc-executor parsing)
    echo '{"status":"confirmed","evidence":"Windows system file C:\\Windows\\win.ini accepted by validate_file_path; files outside sandbox validated without base confinement check","notes":"All 5 PoC tests pass. Arbitrary file read via get_epub_metadata/import_book/extract_book_cover; DB overwrite via restore_database."}'
else
    echo "ERROR: PoC tests failed!"
    echo '{"status":"failed","evidence":"","notes":"PoC tests did not complete successfully"}'
    exit 1
fi
