#!/usr/bin/env bash
# tests/test-kgateway.sh — verifies kgateway control plane is healthy
set -euo pipefail

PASS=0
FAIL=0

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
echo "=== kgateway control plane tests ==="

check "kgateway-system namespace exists" \
  "kubectl get namespace kgateway-system"

check "kgateway deployment is available" \
  "kubectl get deployment kgateway -n kgateway-system -o jsonpath='{.status.availableReplicas}' | grep -E '^[1-9]'"

check "kgateway pod is Running" \
  "kubectl get pods -n kgateway-system -l app.kubernetes.io/name=kgateway --field-selector=status.phase=Running | grep -q kgateway"

check "GatewayClass 'kgateway' is Accepted" \
  "kubectl get gatewayclass kgateway -o jsonpath='{.status.conditions[?(@.type==\"Accepted\")].status}' | grep -q True"

check "Gateway API CRD HTTPRoute is established" \
  "kubectl get crd httproutes.gateway.networking.k8s.io -o jsonpath='{.status.conditions[?(@.type==\"Established\")].status}' | grep -q True"

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
[[ $FAIL -eq 0 ]]
