CLUSTER_NAME := kgateway-playground
KGATEWAY_VERSION := 2.3.5
GATEWAY_API_VERSION := v1.2.0

.PHONY: help cluster-up cluster-down kgateway deploy-product test-all

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

test-all: ## Run full test suite
	@bash tests/test-kgateway.sh
	@bash tests/test-product.sh
	@bash tests/test-auth.sh
