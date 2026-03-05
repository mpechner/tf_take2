#!/bin/bash
# SecureGuard PT - Security Headers Assessment
# Tests HTTP security headers configuration

set -e

TARGET_URL="${TARGET_URL:-https://nginx.dev.foobar.support}"
TMP_HEADERS=$(mktemp)

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

test_header() {
    local header_name="$1"
    local expected_value="$2"
    local severity="${3:-FAIL}"
    
    echo "[TEST] Checking header: $header_name"
    
    if grep -i "^$header_name:" "$TMP_HEADERS" > /dev/null 2>&1; then
        actual_value=$(grep -i "^$header_name:" "$TMP_HEADERS" | head -1 | cut -d':' -f2- | sed 's/^ *//')
        if [[ -n "$expected_value" ]] && [[ "$actual_value" == *"$expected_value"* ]]; then
            echo "[PASS] $header_name: $actual_value"
        else
            echo "[PASS] $header_name present: $actual_value"
        fi
    else
        if [[ "$severity" == "FAIL" ]]; then
            echo "[FAIL] $header_name: Not present (Security Risk)"
        else
            echo "[WARN] $header_name: Not present (Recommended)"
        fi
    fi
}

# Fetch headers
echo "[*] Fetching HTTP headers from $TARGET_URL..."
if ! curl -sI -k --max-time 10 "$TARGET_URL" 2>/dev/null > "$TMP_HEADERS"; then
    echo "[FAIL] Unable to connect to target: $TARGET_URL"
    rm -f "$TMP_HEADERS"
    exit 1
fi

echo ""
echo "=== Security Headers Assessment ==="
echo ""

# Critical security headers
test_header "X-Frame-Options" "SAMEORIGIN\|DENY" "FAIL"
test_header "X-Content-Type-Options" "nosniff" "FAIL"
test_header "Strict-Transport-Security" "max-age" "FAIL"

# Recommended security headers
test_header "X-XSS-Protection" "1" "WARN"
test_header "Content-Security-Policy" "" "WARN"
test_header "Referrer-Policy" "" "WARN"
test_header "Permissions-Policy" "" "INFO"

# Check for information disclosure headers
echo ""
echo "=== Information Disclosure Check ==="
echo ""

if grep -i "^Server:" "$TMP_HEADERS" > /dev/null 2>&1; then
    server_header=$(grep -i "^Server:" "$TMP_HEADERS" | head -1)
    if echo "$server_header" | grep -qi "nginx"; then
        if echo "$server_header" | grep -qE "[0-9]+\.[0-9]+"; then
            echo "[WARN] Server header discloses version: $server_header"
        else
            echo "[PASS] Server header present without version: $server_header"
        fi
    else
        echo "[INFO] Server header: $server_header"
    fi
else
    echo "[PASS] Server header not present (information hiding)"
fi

if grep -i "^X-Powered-By:" "$TMP_HEADERS" > /dev/null 2>&1; then
    echo "[FAIL] X-Powered-By header present (information disclosure):"
    grep -i "^X-Powered-By:" "$TMP_HEADERS"
else
    echo "[PASS] X-Powered-By header not present"
fi

echo ""
echo "=== Raw Headers ==="
echo ""
cat "$TMP_HEADERS"
echo ""

# Cleanup
rm -f "$TMP_HEADERS"
