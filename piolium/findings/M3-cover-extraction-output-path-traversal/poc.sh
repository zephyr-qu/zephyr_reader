#!/bin/bash
# PoC Runner: Cover Extraction Path Traversal (M3)
#
# Demonstrates that extract_book_cover writes cover image files to an
# unvalidated output_dir, allowing arbitrary directory writes.
#
# Usage:
#   bash poc.sh
#
# Structured output (LAST stdout line):
#   {"status":"confirmed|failed|inconclusive","evidence":"...","notes":"..."}

set -o errexit
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
EVIDENCE_DIR="$SCRIPT_DIR/evidence"
POC_TEST_SRC="$SCRIPT_DIR/poc.rs"

# Paths relative to project root (F:/App/zephyr_reader)
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
RUST_DIR="$PROJECT_ROOT/rust"
POC_TEST_DST="$RUST_DIR/tests/poc_cover_traversal.rs"

mkdir -p "$EVIDENCE_DIR"

# Step 1: Copy poc.rs to Rust integration test dir
echo "[1/4] Installing PoC test to Rust test suite..."
cp "$POC_TEST_SRC" "$POC_TEST_DST"
echo "  -> $POC_TEST_DST"

# Step 2: Build
echo "[2/4] Building test..."
cd "$RUST_DIR"
cargo test --test poc_cover_traversal --no-run \
    > "$EVIDENCE_DIR/build.log" 2>&1 \
    || { echo "BUILD FAILED" >> "$EVIDENCE_DIR/build.log";
         rm -f "$POC_TEST_DST";
         echo '{"status":"failed","evidence":"build failed — see evidence/build.log","notes":"Rust compilation error"}';
         exit 1; }
echo "  Build OK"

# Step 3: Run exploit
echo "[3/4] Running exploit..."
cargo test --test poc_cover_traversal test_cover_traversal_poc -- --nocapture \
    > "$EVIDENCE_DIR/exploit.log" 2>&1
TEST_EXIT=$?
echo "  Test exit code: $TEST_EXIT"

# Step 4: Cleanup
rm -f "$POC_TEST_DST"
echo "[4/4] Cleanup done"

# Step 5: Parse result and output JSON as LAST line
LOG="$EVIDENCE_DIR/exploit.log"

if [ $TEST_EXIT -eq 0 ] && grep -q '"status":"confirmed"' "$LOG" 2>/dev/null; then
    EVIDENCE_MARKER=$(grep -o '"evidence":"[^"]*"' "$LOG" | head -1 | sed 's/"evidence":"//;s/"$//')
    # Print the JSON as the last stdout line
    echo '{"status":"confirmed","evidence":"'"$EVIDENCE_MARKER"'","notes":"output_dir parameter accepted arbitrary path without validation — cover file written to attacker-chosen directory"}'
else
    echo '{"status":"failed","evidence":"test did not confirm — see exploit.log","notes":"Check evidence/exploit.log for test output"}'
    exit 1
fi
