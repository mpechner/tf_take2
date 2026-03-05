#!/bin/bash
# SecureGuard PT - Attack Vector Validation
# Tests common web attack mitigations

set -e

TARGET_URL="${TARGET_URL:-https://nginx.dev.foobar.support}"
TARGET_HOST=$(echo "$TARGET_URL" | sed -E 's|https?://||' | cut -d'/' -f1)

echo "=== Attack Vector Validation ==="
echo "Target: $TARGET_URL"
echo ""

# Test 1: XSS Protection (Reflected XSS attempt)
echo "[TEST] Testing XSS protection..."

xss_payloads=(
    "/?q=<script>alert(1)</script>"
    "/search?q=<img+src=x+onerror=alert(1)>"
    "/?test=javascript:alert(1)"
)

xss_protected=true
for payload in "${xss_payloads[@]}"; do
    url="${TARGET_URL}${payload}"
    response=$(curl -s --max-time 5 -k "$url" 2>/dev/null || true)
    
    # Check if payload is reflected without encoding
    if echo "$response" | grep -qiE "<script>alert|<img.*onerror=|javascript:alert"; then
        echo "[FAIL] XSS payload reflected without encoding: $payload"
        xss_protected=false
    fi
done

if [[ "$xss_protected" == true ]]; then
    echo "[PASS] XSS payloads properly handled (not reflected or encoded)"
fi

# Check for X-XSS-Protection header (deprecated but still informative)
headers=$(curl -sI --max-time 5 -k "$TARGET_URL" 2>/dev/null || true)
if echo "$headers" | grep -qi "X-XSS-Protection.*1"; then
    echo "[INFO] X-XSS-Protection header present (legacy browser protection)"
fi

# Test 2: Clickjacking Protection
echo ""
echo "[TEST] Testing clickjacking protection..."

xframe_header=$(echo "$headers" | grep -i "X-Frame-Options" || true)
if [[ -n "$xframe_header" ]]; then
    if echo "$xframe_header" | grep -qiE "DENY|SAMEORIGIN"; then
        echo "[PASS] Clickjacking protection enabled: $xframe_header"
    else
        echo "[WARN] X-Frame-Options set but may allow some framing: $xframe_header"
    fi
else
    echo "[FAIL] X-Frame-Options header missing (clickjacking vulnerability)"
fi

# Test CSP for frame-ancestors
csp_header=$(echo "$headers" | grep -i "Content-Security-Policy" || true)
if [[ -n "$csp_header" ]]; then
    if echo "$csp_header" | grep -qi "frame-ancestors"; then
        echo "[PASS] CSP frame-ancestors directive present for additional clickjacking protection"
    fi
fi

# Test 3: MIME Sniffing Protection
echo ""
echo "[TEST] Testing MIME sniffing protection..."

content_type=$(echo "$headers" | grep -i "Content-Type" | head -1 || true)
if echo "$content_type" | grep -qi "charset"; then
    echo "[PASS] Content-Type includes charset (reduces MIME confusion)"
fi

xcontent_type=$(echo "$headers" | grep -i "X-Content-Type-Options" || true)
if echo "$xcontent_type" | grep -qi "nosniff"; then
    echo "[PASS] X-Content-Type-Options: nosniff (prevents MIME sniffing)"
else
    echo "[FAIL] X-Content-Type-Options: nosniff missing (MIME sniffing possible)"
fi

# Test 4: Path Traversal
echo ""
echo "[TEST] Testing path traversal protection..."

traversal_paths=(
    "/../../../etc/passwd"
    "/..%2F..%2F..%2Fetc%2Fpasswd"
    "/.%00./etc/passwd"
    "/.../.../.../etc/passwd"
)

traversal_safe=true
for path in "${traversal_paths[@]}"; do
    url="${TARGET_URL}${path}"
    response=$(curl -s --max-time 5 -k "$url" 2>/dev/null || true)
    
    # Check for signs of successful traversal
    if echo "$response" | grep -qiE "root:x:0:0|bin:x|daemon:x|etc/passwd"; then
        echo "[FAIL] Path traversal may be possible: $path"
        echo "       Response contains system file indicators"
        traversal_safe=false
    fi
done

if [[ "$traversal_safe" == true ]]; then
    echo "[PASS] Path traversal attempts properly blocked"
fi

# Test 5: Host Header Injection
echo ""
echo "[TEST] Testing host header handling..."

host_response=$(curl -s -H "Host: evil.com" --max-time 5 -k "$TARGET_URL" 2>/dev/null || true)
# Check if the server respects the malicious host header for redirects
if echo "$host_response" | grep -qiE "Location:.*evil.com|href.*evil.com"; then
    echo "[FAIL] Host header injection possible (server uses provided Host for redirects)"
else
    echo "[PASS] Host header injection not detected"
fi

# Test 6: Open Redirect (via parameter)
echo ""
echo "[TEST] Testing for open redirect vulnerabilities..."

redirect_params=(
    "/?redirect=https://evil.com"
    "/?next=https://evil.com"
    "/?return=https://evil.com"
    "/?url=https://evil.com"
)

redirect_safe=true
for param in "${redirect_params[@]}"; do
    url="${TARGET_URL}${param}"
    response_headers=$(curl -sI --max-time 5 -k "$url" 2>/dev/null || true)
    
    if echo "$response_headers" | grep -qiE "Location:.*evil.com|location:.*evil.com"; then
        echo "[FAIL] Open redirect possible: $param"
        redirect_safe=false
    fi
done

if [[ "$redirect_safe" == true ]]; then
    echo "[PASS] No open redirect parameters detected"
fi

# Test 7: CSRF Token Check (if applicable)
echo ""
echo "[TEST] Checking for CSRF protection indicators..."

# Try to get a form page and check for CSRF tokens
form_response=$(curl -s --max-time 5 -k "$TARGET_URL" 2>/dev/null || true)
if echo "$form_response" | grep -qiE "csrf|_token|authenticity_token|__RequestVerificationToken"; then
    echo "[PASS] CSRF token indicators found in forms"
else
    echo "[INFO] No CSRF tokens detected (may not have forms or uses alternative protection)"
fi

# Test 8: SQL Injection (Safe check - timing based not performed)
echo ""
echo "[TEST] Testing for basic SQL injection indicators..."

# Note: This is a safe check that looks for error messages, not actual exploitation
sqli_payloads=(
    "/?id=1'"
    "/?id=1\""
    "/?search=test'--"
)

sqli_safe=true
for payload in "${sqli_payloads[@]}"; do
    url="${TARGET_URL}${payload}"
    response=$(curl -s --max-time 5 -k "$url" 2>/dev/null || true)
    
    # Check for SQL error messages
    if echo "$response" | grep -qiE "mysql.*error|sqlite.*error|oracle.*error|syntax.*error|unexpected.*end|pg_query|mssql"; then
        echo "[FAIL] SQL error message disclosed: $payload"
        echo "       Error indicator found in response"
        sqli_safe=false
    fi
done

if [[ "$sqli_safe" == true ]]; then
    echo "[PASS] No SQL error messages disclosed (input appears sanitized)"
fi

echo ""
echo "=== Attack Vector Validation Complete ==="
echo ""
