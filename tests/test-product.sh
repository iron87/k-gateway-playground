#!/usr/bin/env bash
# tests/test-product.sh — verifies Use Case 1: product proxy + endpoints
set -euo pipefail

PASS=0
FAIL=0
NAMESPACE="product"
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

check_http() {
  local desc="$1"
  local url="$2"
  local expected_status="${3:-200}"
  local extra_args="${4:-}"
  local status
  status=$(eval "curl -s -o /dev/null -w \"%{http_code}\" --max-time 10 ${extra_args} \"${url}\"" || echo "000")
  if [[ "$status" == "$expected_status" ]]; then
    echo "  [PASS] $desc (HTTP $status)"
    PASS=$((PASS + 1))
  else
    echo "  [FAIL] $desc (expected HTTP $expected_status, got HTTP $status)"
    FAIL=$((FAIL + 1))
  fi
}

echo ""
echo "=== Use Case 1 — Product Proxy tests ==="

check "product namespace exists" \
  "kubectl get namespace ${NAMESPACE}"

check "product-gateway exists and is Programmed" \
  "kubectl get gateway product-gateway -n ${NAMESPACE} -o jsonpath='{.status.conditions[?(@.type==\"Programmed\")].status}' | grep -q True"

check "product-api deployment is available" \
  "kubectl get deployment product-api -n ${NAMESPACE} -o jsonpath='{.status.availableReplicas}' | grep -E '^[1-9]'"

check "HTTPRoute product-api-route is accepted" \
  "kubectl get httproute product-api-route -n ${NAMESPACE} -o jsonpath='{.status.parents[0].conditions[?(@.type==\"Accepted\")].status}' | grep -q True"

check "HTTPRoute httpbin-route is accepted" \
  "kubectl get httproute httpbin-route -n ${NAMESPACE} -o jsonpath='{.status.parents[0].conditions[?(@.type==\"Accepted\")].status}' | grep -q True"

echo ""
echo "--- HTTP routing tests (requires cluster port-forward active) ---"

# Get JWT token from Keycloak (required for UC2 auth)
echo "  Getting JWT from Keycloak..."
TOKEN=$(curl -sf --max-time 10 \
  "http://localhost:${KC_PORT}/realms/${REALM}/protocol/openid-connect/token" \
  -d "client_id=${CLIENT}" \
  -d "username=test-user" \
  -d "password=password123" \
  -d "grant_type=password" \
  2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])" 2>/dev/null || echo "")

if [[ -z "$TOKEN" ]]; then
  echo "  [SKIP] Could not obtain JWT (port-forward :${KC_PORT} may not be active)"
  # Still try requests without token to verify routing works
  check_http "GET /api/get -> product-api (internal)" \
    "${BASE_URL}/api/get" "401"
  check_http "GET /httpbin/get -> httpbun.com (external)" \
    "${BASE_URL}/httpbin/get" "401"
else
  echo "  ✓ JWT obtained (${#TOKEN} chars)"
  
  check_http "GET /api/get -> product-api (internal)" \
    "${BASE_URL}/api/get" "200" "-H 'Authorization: Bearer ${TOKEN}'"
  
  check_http "GET /httpbin/get -> httpbun.com (external)" \
    "${BASE_URL}/httpbin/get" "200" "-H 'Authorization: Bearer ${TOKEN}'"
fi

check_http "GET /nonexistent -> 404 from gateway" \
  "${BASE_URL}/nonexistent" "404"

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
[[ $FAIL -eq 0 ]]
