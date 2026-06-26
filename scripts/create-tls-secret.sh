#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# Create TLS Secret from certificate files
# Reads certs/gateway.crt and certs/gateway.key, creates K8s Secret
# ---------------------------------------------------------------------------

NAMESPACE="product"
CERT_FILE="certs/gateway.crt"
KEY_FILE="certs/gateway.key"

if [[ ! -f "$CERT_FILE" || ! -f "$KEY_FILE" ]]; then
  echo "ERROR: Certificate files not found!"
  echo "Expected: $CERT_FILE and $KEY_FILE"
  exit 1
fi

echo "Creating TLS Secret from certificates..."

kubectl create secret tls gateway-tls \
  --cert="$CERT_FILE" \
  --key="$KEY_FILE" \
  -n "$NAMESPACE" \
  --dry-run=client \
  -o yaml | kubectl apply -f -

echo "✅ TLS Secret created/updated"
