#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# Use Case 1 — Product Proxy with Internal & External Endpoints
#
# Deploys:
#   - Namespace: product
#   - TLS Secret: gateway-tls (self-signed cert for gateway.local)
#   - Gateway: product-gateway (HTTP:8080 + HTTPS:8443 with TLS termination)
#   - Deployment + Service: product-api (internal mock service)
#   - HTTPRoute: /api/* → product-api (internal, HTTP)
#   - HTTPRoute: /httpbin/* → httpbun.com (external)
#   - NO authentication (Keycloak added in UC2)
# ---------------------------------------------------------------------------

NAMESPACE="product"

echo "==> Creating TLS Secret for HTTPS termination..."
bash scripts/create-tls-secret.sh

echo "==> Applying product namespace and manifests..."
kubectl apply -f k8s/product/

echo "==> Waiting for product-api deployment to be ready..."
kubectl rollout status deployment/product-api -n "${NAMESPACE}" --timeout=90s

echo "==> Waiting for product-gateway to be programmed..."
for i in $(seq 1 30); do
  STATUS=$(kubectl get gateway product-gateway -n "${NAMESPACE}" \
    -o jsonpath='{.status.conditions[?(@.type=="Programmed")].status}' 2>/dev/null || echo "")
  if [[ "${STATUS}" == "True" ]]; then
    echo "    Gateway is Programmed."
    break
  fi
  echo "    Waiting for gateway... (${i}/30)"
  sleep 5
done

echo "==> Use Case 1 deployed."
echo ""
echo "Access methods:"
echo "  HTTP:  http://localhost:8080/api/get"
echo "  HTTPS: https://gateway.local:8443/api/get (self-signed cert)"
echo ""
echo "For HTTPS: add to /etc/hosts: 127.0.0.1 gateway.local"
echo ""
kubectl get gateway,httproute,backend,deployment -n "${NAMESPACE}"
