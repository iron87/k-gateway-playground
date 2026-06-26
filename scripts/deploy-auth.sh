#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# Use Case 2 — Keycloak + JWT Authentication
#
# Deploys:
#   - Namespace: keycloak
#   - Deployment + Service: keycloak (dev mode)
#   - Keycloak realm 'playground' + client 'product-client' + user 'test-user'
#   - GatewayExtension: keycloak-jwt (JWT provider)
#   - TrafficPolicy: product-jwt-auth (attaches JWT to product-gateway)
# ---------------------------------------------------------------------------

KEYCLOAK_NS="keycloak"
KEYCLOAK_SVC="keycloak"
KC_PORT="9080"   # local port-forward
REALM="playground"
CLIENT="product-client"
KC_ADMIN="admin"
KC_PASS="admin"

echo "==> Deploying Keycloak..."
kubectl apply -f k8s/auth/00-keycloak.yaml

echo "==> Waiting for Keycloak pod to be ready (this may take ~60s)..."
kubectl rollout status deployment/keycloak -n "${KEYCLOAK_NS}" --timeout=3m

echo "==> Port-forwarding Keycloak to localhost:${KC_PORT}..."
kubectl -n "${KEYCLOAK_NS}" port-forward svc/${KEYCLOAK_SVC} "${KC_PORT}":8080 &
PF_PID=$!
trap "kill ${PF_PID} 2>/dev/null || true" EXIT

# Wait for Keycloak HTTP to be ready
echo "==> Waiting for Keycloak HTTP to be responsive..."
for i in $(seq 1 30); do
  if curl -sf --max-time 3 "http://localhost:${KC_PORT}/realms/master" &>/dev/null; then
    echo "    Keycloak is ready."
    break
  fi
  echo "    Attempt ${i}/30 — waiting..."
  sleep 5
done

KC_BASE="http://localhost:${KC_PORT}"

echo "==> Getting admin token..."
ADMIN_TOKEN=$(curl -sf "${KC_BASE}/realms/master/protocol/openid-connect/token" \
  -d "client_id=admin-cli" \
  -d "username=${KC_ADMIN}" \
  -d "password=${KC_PASS}" \
  -d "grant_type=password" | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")

echo "==> Creating realm '${REALM}'..."
curl -sf -X POST "${KC_BASE}/admin/realms" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"realm\":\"${REALM}\",\"enabled\":true,\"displayName\":\"Playground Realm\"}" \
  2>/dev/null || echo "    Realm may already exist — continuing."

echo "==> Creating client '${CLIENT}'..."
curl -sf -X POST "${KC_BASE}/admin/realms/${REALM}/clients" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{
    \"clientId\": \"${CLIENT}\",
    \"enabled\": true,
    \"publicClient\": true,
    \"directAccessGrantsEnabled\": true,
    \"standardFlowEnabled\": true
  }" 2>/dev/null || echo "    Client may already exist — continuing."

echo "==> Creating user 'test-user'..."
curl -sf -X POST "${KC_BASE}/admin/realms/${REALM}/users" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{
    \"username\": \"test-user\",
    \"email\": \"test@playground.local\",
    \"enabled\": true,
    \"emailVerified\": true,
    \"credentials\": [{\"type\":\"password\",\"value\":\"password123\",\"temporary\":false}]
  }" 2>/dev/null || echo "    User may already exist — continuing."

kill "${PF_PID}" 2>/dev/null || true
trap - EXIT

echo "==> Applying JWT GatewayExtension and TrafficPolicy..."
kubectl apply -f k8s/auth/01-jwt-policy.yaml

echo "==> Waiting for TrafficPolicy to be accepted..."
sleep 5
kubectl get gatewayextension,trafficpolicy -n product

echo ""
echo "==> Use Case 2 deployed."
echo "    Keycloak Admin: http://localhost:9080  (admin/admin, after port-forward)"
echo "    Realm: ${REALM}  Client: ${CLIENT}  User: test-user / password123"
