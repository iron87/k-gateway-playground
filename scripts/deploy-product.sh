#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# Use Case 1 — Product Proxy (dedicated, non-shared Gateway)
#
# Deploys:
#   - Namespace: product
#   - GatewayClass: kgateway (cluster-scoped, already exists)
#   - Gateway: product-gateway  (dedicated, non-shared — owns its own LB)
#   - Deployment + Service: product-api  (mock internal service)
#   - HTTPRoute: /api  → product-api (internal)
#   - HTTPRoute: /httpbin → httpbin.org (external, via HTTPRoute backendRef URL)
# ---------------------------------------------------------------------------

NAMESPACE="product"

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
kubectl get gateway,httproute,svc -n "${NAMESPACE}"
