#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# Use Case 3 — Local Rate Limiting
#
# Deploys:
#   - Namespace: ratelimit
#   - TrafficPolicy: product-rate-limit (local token bucket on product-gateway)
#
# Local rate limiting config:
#   - Token bucket: 10 max tokens
#   - Fill rate: 10 tokens per second
#   - Effective limit: ~10 req/sec sustained
# ---------------------------------------------------------------------------

echo "==> Deploying RateLimit infrastructure..."
kubectl apply -f k8s/ratelimit/00-namespace.yaml

echo "==> Deploying local rate limiting policy..."
kubectl apply -f k8s/ratelimit/03-rate-limit-policy.yaml

echo "✅ RateLimit (UC3) deployment complete!"
echo "   Using local token bucket rate limiting (10 req/sec)"
