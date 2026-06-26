CLUSTER_NAME := kgateway-playground
KGATEWAY_VERSION := 2.3.5
GATEWAY_API_VERSION := v1.2.0

.PHONY: help cluster-up cluster-down kgateway deploy-product deploy-auth deploy-ratelimit test-kgateway test-product test-auth test-ratelimit

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-25s\033[0m %s\n", $$1, $$2}'

cluster-up: ## Create the kind cluster
	@scripts/cluster-up.sh

cluster-down: ## Delete the kind cluster
	kind delete cluster --name $(CLUSTER_NAME)

kgateway: ## Install Gateway API CRDs + kgateway
	@scripts/deploy-kgateway.sh

deploy-product: ## Deploy Use Case 1 — product proxy + endpoints
	@scripts/deploy-product.sh

deploy-auth: ## Deploy Use Case 2 — Keycloak + JWT authentication
	@scripts/deploy-auth.sh

deploy-ratelimit: ## Deploy Use Case 3 — Per-user rate limiting
	@scripts/deploy-ratelimit.sh

test-kgateway: ## Test kgateway control plane
	@bash tests/test-kgateway.sh

test-product: ## Test Use Case 1 — routing
	@bash tests/test-product.sh

test-auth: ## Test Use Case 2 — JWT authentication
	@bash tests/test-auth.sh

test-ratelimit: ## Test Use Case 3 — rate limiting
	@bash tests/test-ratelimit.sh
