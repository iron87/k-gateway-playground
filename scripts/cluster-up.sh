#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="kgateway-playground"

echo "==> Checking if cluster already exists..."
if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
  echo "    Cluster '${CLUSTER_NAME}' already exists — skipping creation."
else
  echo "==> Creating kind cluster '${CLUSTER_NAME}'..."
  kind create cluster --config kind-config.yaml
fi

echo "==> Waiting for cluster to be ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=120s

echo "==> Cluster '${CLUSTER_NAME}' is ready."
kubectl get nodes
