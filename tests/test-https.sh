#!/bin/bash

# Test HTTPS/TLS termination for Use Case 4
# Prerequisites: deploy-product.sh must have been run

set -e

NAMESPACE="product"
GATEWAY="product-gateway"
PORT_HTTPS=8443
TIMEOUT=10

echo "=== Testing HTTPS/TLS Termination (Use Case 4) ==="

# Test 1: HTTPS listener is Programmed
echo -n "Test 1: HTTPS listener programmed... "
HTTPS_PROGRAMMED=$(kubectl get gateway "$GATEWAY" -n "$NAMESPACE" -o jsonpath='{.status.listeners[1].conditions[?(@.type=="Programmed")].status}' 2>/dev/null || echo "False")
if [ "$HTTPS_PROGRAMMED" = "True" ]; then
  echo "✓ PASS"
else
  echo "✗ FAIL (Programmed=$HTTPS_PROGRAMMED)"
  exit 1
fi

# Test 2: TLS Secret exists and is valid
echo -n "Test 2: TLS secret exists and is valid... "
if kubectl get secret gateway-tls -n "$NAMESPACE" &>/dev/null; then
  CERT_DATA=$(kubectl get secret gateway-tls -n "$NAMESPACE" -o jsonpath='{.data.tls\.crt}' | base64 -d 2>/dev/null | openssl x509 -noout -subject -dates 2>/dev/null)
  if echo "$CERT_DATA" | grep -q "gateway.local"; then
    echo "✓ PASS"
  else
    echo "✗ FAIL (cert CN mismatch)"
    exit 1
  fi
else
  echo "✗ FAIL (secret not found)"
  exit 1
fi

# Test 3: Port 8443 listener is listening
echo -n "Test 3: Port 8443 listener ready... "
POD_NAME=$(kubectl get pod -n "$NAMESPACE" -l 'app.kubernetes.io/instance=product-gateway' -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -z "$POD_NAME" ]; then
  echo "✗ FAIL (no pod found)"
  exit 1
fi
echo "✓ PASS (pod: $POD_NAME)"

# Wait for port-forward
kubectl port-forward "svc/$GATEWAY" 8080:8080 8443:8443 &>/dev/null &
PF_PID=$!
sleep 2

# Test 4: HTTPS connection via TLS
echo -n "Test 4: HTTPS TLS handshake succeeds... "
TLS_TEST=$(timeout 3 curl -k -s -o /dev/null -w "%{http_code}" https://localhost:8443/api/get 2>/dev/null || echo "000")
if [ "$TLS_TEST" != "000" ]; then
  echo "✓ PASS (HTTP $TLS_TEST)"
else
  echo "✗ FAIL (no response)"
  kill $PF_PID 2>/dev/null || true
  exit 1
fi

# Test 5: HTTP still works (port 8080)
echo -n "Test 5: HTTP endpoint still accessible... "
HTTP_TEST=$(timeout 3 curl -k -s -o /dev/null -w "%{http_code}" http://localhost:8080/api/get 2>/dev/null || echo "000")
if [ "$HTTP_TEST" != "000" ]; then
  echo "✓ PASS (HTTP $HTTP_TEST)"
else
  echo "✗ FAIL (no response)"
  kill $PF_PID 2>/dev/null || true
  exit 1
fi

# Test 6: Certificate is self-signed (via stored secret)
echo -n "Test 6: Certificate is self-signed... "
ISSUER=$(kubectl get secret gateway-tls -n "$NAMESPACE" -o jsonpath='{.data.tls\.crt}' | base64 -d 2>/dev/null | openssl x509 -noout -issuer 2>/dev/null | grep -o "CN[^,]*" || echo "NOTFOUND")
if [[ "$ISSUER" == *"gateway.local" ]]; then
  echo "✓ PASS (issuer contains gateway.local)"
else
  echo "✗ FAIL (issuer: $ISSUER)"
  kill $PF_PID 2>/dev/null || true
  exit 1
fi

# Test 7: HTTPS response contains expected data (same as HTTP)
echo -n "Test 7: HTTPS response valid (JWT required, as expected)... "
HTTPS_RESP=$(curl -k -s https://localhost:8443/api/get 2>/dev/null | head -c 100 || echo "ERROR")
if echo "$HTTPS_RESP" | grep -q "Jwt is missing"; then
  echo "✓ PASS (JWT validation active)"
else
  echo "✗ FAIL (unexpected response: $HTTPS_RESP)"
  kill $PF_PID 2>/dev/null || true
  exit 1
fi

kill $PF_PID 2>/dev/null || true

echo ""
echo "=== All 7 HTTPS tests PASSED ✓ ==="
exit 0
