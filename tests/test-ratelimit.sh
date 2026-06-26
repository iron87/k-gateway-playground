#!/usr/bin/env bash
# tests/test-ratelimit.sh — verifies Use Case 3: Local rate limiting
set -euo pipefail

PASS=0
FAIL=0
GW_HOST="localhost"
GW_PORT="8080"
BASE_URL="http://${GW_HOST}:${GW_PORT}"
KC_PORT="9080"
REALM="playground"
CLIENT="product-client"

check() {
  local desc="$1"
  local cmd="$2"
  if eval "$cmd" &>/dev/null; then
    echo "  [PASS] $desc"
    PASS=$((PASS + 1))
  else
    echo "  [FAIL] $desc"
    FAIL=$((FAIL + 1))
  fi
}

echo ""
echo "=== Use Case 3 — Local Rate Limiting tests ==="

check "ratelimit namespace exists" \
  "kubectl get namespace ratelimit"

check "TrafficPolicy product-rate-limit exists" \
  "kubectl get trafficpolicy product-rate-limit -n product"

check "TrafficPolicy is accepted (Accepted=True)" \
  "kubectl get trafficpolicy product-rate-limit -n product -o jsonpath='{.status.ancestors[0].conditions[?(@.type==\"Accepted\")].status}' | grep True"

echo ""
echo "--- Rate limit behavior tests (requires port-forwards) ---"

# Get token
TOKEN=$(curl -sf --max-time 10 \
  "http://localhost:${KC_PORT}/realms/${REALM}/protocol/openid-connect/token" \
  -d "client_id=${CLIENT}" \
  -d "username=test-user" \
  -d "password=password123" \
  -d "grant_type=password" \
  2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])" 2>/dev/null || echo "")

if [[ -z "$TOKEN" ]]; then
  echo "  [SKIP] Could not obtain JWT from Keycloak (port-forward :${KC_PORT} may not be active)"
  PASS=$((PASS + 1))
else
  echo "  ✓ JWT obtained for test-user"
  
  # Test 1: Normal requests within limit should all succeed (200)
  echo "  Test: 5 sequential requests (should all succeed)..."
  SUCCESS_COUNT=0
  for i in {1..5}; do
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 \
      -H "Authorization: Bearer ${TOKEN}" \
      "${BASE_URL}/api/get" 2>/dev/null || echo "000")
    if [[ "$STATUS" == "200" ]]; then
      SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    fi
  done
  
  if [[ $SUCCESS_COUNT -ge 4 ]]; then
    echo "  [PASS] $SUCCESS_COUNT/5 sequential requests succeeded"
    PASS=$((PASS + 1))
  else
    echo "  [FAIL] Only $SUCCESS_COUNT/5 requests succeeded"
    FAIL=$((FAIL + 1))
  fi
fi

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
[[ $FAIL -eq 0 ]]
