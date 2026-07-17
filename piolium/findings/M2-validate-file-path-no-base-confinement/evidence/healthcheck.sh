#!/bin/bash
# healthcheck.sh - Verify the environment can run the PoC

set -e

cd "$(dirname "$0")/../../../../rust"

echo "=== Health Check ==="
echo "Checking Rust compilation..."
cargo check 2>&1 | tail -5

echo ""
echo "Checking existing tests pass..."
cargo test --test unit_utils_test test_validate_valid_file -- 2>&1 | tail -10

echo ""
echo "Health check complete."
