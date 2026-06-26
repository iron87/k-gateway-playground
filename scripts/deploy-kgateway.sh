#!/usr/bin/env bash
set -euo pipefail

KGATEWAY_VERSION="2.3.5"
GATEWAY_API_VERSION="v1.2.0"
NAMESPACE="kgateway-system"

echo "==> Installing Gateway API CRDs (${GATEWAY_API_VERSION})..."
kubectl apply -f "https://github.com/kubernetes-sigs/gateway-api/releases/download/${GATEWAY_API_VERSION}/standard-install.yaml"

echo "==> Waiting for Gateway API CRDs to be established..."
kubectl wait --for=condition=Established crd/gateways.gateway.networking.k8s.io --timeout=60s
kubectl wait --for=condition=Established crd/httproutes.gateway.networking.k8s.io --timeout=60s

echo "==> Installing kgateway ${KGATEWAY_VERSION} via Helm..."
helm upgrade --install kgateway \
  oci://ghcr.io/kgateway-dev/charts/kgateway \
  --version "${KGATEWAY_VERSION}" \
  --namespace "${NAMESPACE}" \
  --create-namespace \
  --wait \
  --timeout 5m

echo "==> Waiting for kgateway control plane to be ready..."
kubectl rollout status deployment/kgateway -n "${NAMESPACE}" --timeout=120s

echo "==> Installing kgateway CRDs (Backend, TrafficPolicy, etc.)..."
helm upgrade --install kgateway-crds \
  oci://ghcr.io/kgateway-dev/charts/kgateway-crds \
  --version "${KGATEWAY_VERSION}" \
  --namespace "${NAMESPACE}" \
  --wait

echo "==> kgateway ${KGATEWAY_VERSION} installed successfully."
kubectl get pods -n "${NAMESPACE}"
