# kgateway Playground

A local Kubernetes playground for exploring **[kgateway](https://github.com/kgateway-dev/kgateway)** — a powerful Gateway API implementation. Build realistic use cases with authentication, routing, rate limiting, and more.

## 🎯 Overview

This playground provisions a **kind cluster** with:
- **kgateway** v2.3.5 — Envoy-based Gateway API controller
- **Gateway API CRDs** — standard K8s gateway resources (Gateway, HTTPRoute, Backend)
- **kgateway-specific CRDs** — TrafficPolicy, GatewayExtension, Backend (static/AWS/GCP)
- **Automated deployments** for each use case via shell scripts & Makefile

## 📋 Use Cases

### ✅ Use Case 1: Product Proxy with Internal & External Endpoints

**What:** Dedicated, non-shared Gateway routing to both internal and external APIs, with HTTPS support to upstream.

**Components:**
- `Gateway: product-gateway` (namespace: `product`, port 8080)
- `Deployment + Service: product-api` — internal mock service (httpbin image)
- `HTTPRoute /api/*` → product-api (internal, HTTP)
- `HTTPRoute /httpbin/*` → httpbun.com (external, HTTPS — port 443)
- `Backend: httpbin-backend` — static backend demonstrating TLS to upstream
- Full test suite: 8/8 tests passing

**Key Features:**
- Gateway routes to internal cluster service and external APIs
- Handles both HTTP (internal) and HTTPS (external) upstream
- URL rewriting (path and hostname transformation)
- Standalone — no authentication policy (UC1-only workflow)

**Deploy & Test:**
```bash
make deploy-product     # Deploys gateway + internal service + external routes
make test-product       # Verify routing (8 checks)
```

**Routes:**
- `GET http://localhost:8080/api/get` → product-api (internal, HTTP)
- `GET http://localhost:8080/httpbin/get` → httpbun.com (external, HTTPS)

### ✅ Use Case 2: Keycloak OIDC + JWT Authentication

**What:** Secure gateway routes with OpenID Connect tokens from Keycloak.

**Components:**
- `Deployment: keycloak` (namespace: `keycloak`, dev mode)
  - Realm: `playground`
  - Client: `product-client` (public)
  - User: `test-user` / `password123`
- `GatewayExtension: keycloak-jwt` (JWT provider with remote JWKS)
- `TrafficPolicy: product-jwt-auth` (Strict mode — all requests require valid JWT)
- `ReferenceGrant` — cross-namespace JWKS backend reference
- Claims extraction: `preferred_username` → `x-user` header, `email` → `x-email` header
- Full test suite: 8/8 tests passing

**Deploy & Test:**
```bash
make deploy-auth        # Deploys Keycloak + JWT policy
bash tests/test-auth.sh # Verify auth (requires port-forwards)
```

**Token Flow:**
```bash
# 1. Get JWT from Keycloak
TOKEN=$(curl -s http://localhost:9080/realms/playground/protocol/openid-connect/token \
  -d "client_id=product-client" \
  -d "username=test-user" \
  -d "password=password123" \
  -d "grant_type=password" | jq -r .access_token)

# 2. Use JWT
curl -H "Authorization: Bearer $TOKEN" http://localhost:8080/api/get  # 200 OK
curl http://localhost:8080/api/get                                    # 401 Unauthorized
```

### ✅ Use Case 3: Local Rate Limiting

**What:** Protect the gateway with global rate limiting using token bucket algorithm.

**Components:**
- `TrafficPolicy: product-rate-limit` — applies local rate limiting to product-gateway
- Token bucket configuration:
  - Max tokens: 10
  - Fill rate: 10 tokens/second
  - Effective limit: ~10 requests/second (global, all users combined)
- Returns HTTP 429 when limit exceeded
- Automatic token recovery based on fill interval

**Deploy & Test:**
```bash
make deploy-ratelimit       # Deploy rate limiting policy
bash tests/test-ratelimit.sh # Verify rate limiting works (requires port-forwards)
```

**Rate Limit Flow:**
```
Request → Check token bucket
       → Within limit: consume token, forward request (200 OK)
       → Out of limit: return 429 Too Many Requests
       → Tokens refill based on fill interval (10 tokens every 1 second)
```

**Future Enhancement:**
For per-user rate limiting, kgateway can be extended to use a global rate limit service with gRPC (Envoy's ratelimit) supporting:
- Descriptor-based rules per user/API key
- Cross-cluster distributed state via Redis

### ✅ Use Case 4: HTTPS/TLS Termination

**What:** Secure gateway with self-signed TLS certificate, terminating HTTPS connections and proxying to backends over HTTP.

**Components:**
- `Gateway: product-gateway` — dual listeners
  - HTTP listener: port 8080 (unencrypted)
  - HTTPS listener: port 8443 (TLS Terminate mode)
- `Secret: gateway-tls` — self-signed certificate (CN=gateway.local, RSA 2048-bit)
- Same routes and policies (JWT, rate limiting) apply to both listeners
- Full test suite: 7/7 tests passing

**Certificate Details:**
- **Type:** Self-signed (CN=gateway.local)
- **Validity:** 365 days from generation
- **Files:** `certs/gateway.crt` (public) + `certs/gateway.key` (private)
- **Kind Port Mapping:** 8443:443 (native HTTPS on localhost:8443)
- **Usage:** curl -k https://localhost:8443/api/get (use -k to skip cert verification)

**Deploy & Test:**
```bash
make deploy-product     # Creates HTTPS listener + loads TLS secret
make test-https         # Verify TLS termination (7 checks)
```

**Access Both Protocols:**
```bash
# HTTP (port 8080)
curl http://localhost:8080/api/get

# HTTPS (port 8443, requires JWT)
TOKEN=$(...)  # Get token from Keycloak
curl -k -H "Authorization: Bearer $TOKEN" https://localhost:8443/api/get

# Check certificate
openssl s_client -connect localhost:8443 -showcerts
```

**Security Note:**
This is a **self-signed certificate for testing only**. Production deployments should use:
- Certificates from a trusted CA (e.g., Let's Encrypt)
- Automated cert rotation (cert-manager integration)
- Proper secret management (sealed secrets, external vaults)

---

## 🚀 Quick Start

### Prerequisites
- `kind` v0.22.0+
- `kubectl` v1.30.0+
- `helm` v3.14.0+
- 4+ GB free memory (kind cluster + Keycloak)

### 1. Setup Cluster

```bash
make cluster-up          # Create kind cluster 'kgateway-playground'
kubectl get nodes        # Verify cluster ready
```

### 2. Install kgateway

```bash
make kgateway           # Install Gateway API CRDs + kgateway control plane
kubectl get pods -n kgateway-system  # Verify deployment
```

### 3. Deploy Use Cases

```bash
# Use Case 1: Routing
make deploy-product

# Use Case 2: Authentication
make deploy-auth

# Both together
make deploy-product && make deploy-auth
```

### 4. Port-Forward Gateway + Keycloak

```bash
# Terminal 1: Gateway
kubectl -n product port-forward svc/product-gateway 8080:8080

# Terminal 2: Keycloak admin
kubectl -n keycloak port-forward svc/keycloak 9080:8080
```

### 5. Test

```bash
# Test kgateway control plane
bash tests/test-kgateway.sh

# Test routing (gateway port-forward required)
bash tests/test-product.sh

# Test auth (gateway + keycloak port-forwards required)
bash tests/test-auth.sh

# Test rate limiting (gateway + keycloak port-forwards required)
bash tests/test-ratelimit.sh

# Test HTTPS/TLS (gateway port-forward required)
bash tests/test-https.sh

# Or use Makefile targets
make test-kgateway
make test-product
make test-auth
make test-ratelimit
make test-https
```

---

## 📁 Directory Structure

```
k-gateway-playground/
├── kind-config.yaml              # kind cluster definition
├── Makefile                       # Build targets
├── .github/agents/
│   └── k8s-playground.agent.md   # Custom agent for Kubernetes work
├── k8s/                          # Kubernetes manifests organized by use case
│   ├── product/                  # Use Case 1: routing
│   │   ├── 00-namespace.yaml
│   │   ├── 01-gateway.yaml
│   │   ├── 02-product-api.yaml
│   │   └── 03-routes.yaml
│   ├── auth/                     # Use Case 2: authentication
│   │   ├── 00-keycloak.yaml
│   │   ├── 01-jwt-policy.yaml
│   │   └── 02-reference-grant.yaml
│   └── ratelimit/                # Use Case 3: rate limiting
│       ├── 00-namespace.yaml
│       └── 03-rate-limit-policy.yaml
├── scripts/
│   ├── cluster-up.sh             # Create/verify kind cluster
│   ├── deploy-kgateway.sh        # Install kgateway + Gateway API CRDs
│   ├── deploy-product.sh         # Deploy Use Case 1
│   ├── deploy-auth.sh            # Deploy Use Case 2
│   └── deploy-ratelimit.sh       # Deploy Use Case 3
├── tests/
│   ├── test-kgateway.sh          # Test kgateway control plane
│   ├── test-product.sh           # Test routing
│   ├── test-auth.sh              # Test JWT authentication
│   └── test-ratelimit.sh         # Test per-user rate limiting
├── docs/
│   └── architecture.md           # Mermaid diagram (kept up-to-date)
└── README.md                     # This file
```

---

## 🏗️ Architecture

See [docs/architecture.md](docs/architecture.md) for a detailed Mermaid diagram showing:
- kind cluster topology
- kgateway control plane
- Keycloak OIDC provider
- Gateway + HTTPRoutes + Backends
- Cross-namespace references

---

## 📝 Makefile Targets

| Target | Purpose |
|--------|---------|
| `make help` | Show all targets |
| `make cluster-up` | Create kind cluster |
| `make cluster-down` | Delete kind cluster |
| `make kgateway` | Install kgateway + Gateway API CRDs + kgateway-crds |
| `make deploy-product` | Deploy Use Case 1 (routing + external backends) |
| `make deploy-auth` | Deploy Use Case 2 (Keycloak + JWT auth) |
| `make deploy-ratelimit` | Deploy Use Case 3 (local rate limiting) |
| `make test-kgateway` | Test control plane |
| `make test-product` | Test Use Case 1 routing |
| `make test-auth` | Test Use Case 2 authentication |
| `make test-ratelimit` | Test Use Case 3 rate limiting |
| `make test-https` | Test Use Case 4 HTTPS/TLS termination |

---

## 🧪 Testing Strategy

Each use case has independent tests that verify:
- **Resource existence** (namespaces, deployments, policies)
- **Resource health** (pods ready, gateways programmed)
- **HTTP behavior** (routes work, auth enforced, rate limits enforced)

Tests use `bash` + `kubectl` + `curl` — no external frameworks required.

**Test Dependencies:**
- `test-kgateway` — always runs first (no dependencies)
- `test-product` — requires: `make deploy-product`
- `test-auth` — requires: `make deploy-product` + `make deploy-auth`
- `test-ratelimit` — requires: `make deploy-product` + `make deploy-auth` + `make deploy-ratelimit`
- `test-https` — requires: `make deploy-product` (uses same gateway as UC1)

**Run individually:**
```bash
make test-kgateway   # Test control plane (5 checks)
make test-product    # Test routing (8 checks) — requires deploy-product
make test-auth       # Test JWT auth (8 checks) — requires deploy-auth
make test-ratelimit  # Test rate limiting (4 checks) — requires deploy-ratelimit
```

Or run directly:
```bash
bash tests/test-kgateway.sh
bash tests/test-product.sh
bash tests/test-auth.sh
bash tests/test-ratelimit.sh
```

All tests must pass with `HTTP 200` or expected status codes.

---

## 🔐 Authentication Details

### Keycloak Setup (Automated)

| Component | Value |
|-----------|-------|
| Admin Console | http://localhost:9080 (after port-forward) |
| Admin User | `admin` / `admin` |
| Realm | `playground` |
| Client | `product-client` (public, direct-access enabled) |
| User | `test-user` / `password123` |
| JWKS Endpoint | http://keycloak.keycloak.svc.cluster.local:8080/realms/playground/protocol/openid-connect/certs |

### JWT Validation

- **Provider:** Keycloak OIDC
- **Validation Mode:** Strict (JWT required, signature verified via remote JWKS)
- **Claims to Headers:** `preferred_username` → `x-user`, `email` → `x-email`
- **Forward Token:** Disabled (token stripped from upstream requests)

---

## 📚 Key Concepts

### Gateway API

Standard Kubernetes API for **GatewayClass**, **Gateway**, **HTTPRoute**, **ReferenceGrant**. See [gateway-api.sigs.k8s.io](https://gateway-api.sigs.k8s.io).

### kgateway-Specific Resources

| CRD | Purpose |
|-----|---------|
| **Backend** | Define upstream backends (static IP/DNS, AWS, GCP) |
| **TrafficPolicy** | Configure auth, rate-limiting, CORS, transformations |
| **GatewayExtension** | Attach providers (JWT, OAuth2, ExtAuth, RateLimit) |
| **GatewayParameters** | Cluster-level kgateway configuration |

### Non-Shared Gateways

Each team/domain owns a dedicated `Gateway` resource:
- **Namespace isolation:** `allowedRoutes: Same` prevents cross-namespace attachment
- **Independent lifecycle:** Deploy/scale/troubleshoot independently
- **No contention:** No shared ingress resource bottleneck

---

## 🛠️ Troubleshooting

### Gateway not Programmed

```bash
kubectl -n product get gateway product-gateway -o yaml
# Check status.conditions[?(@.type=="Programmed")].status
```

### JWT validation failing

```bash
# Verify JWKS endpoint is reachable
kubectl -n product exec <proxy-pod> -- wget -qO- \
  http://keycloak.keycloak.svc.cluster.local:8080/realms/playground/protocol/openid-connect/certs

# Check TrafficPolicy attachment
kubectl -n product get trafficpolicy product-jwt-auth -o yaml
```

### Port-forward issues

```bash
# List active port-forwards
lsof -i :8080 -i :9080

# Kill stale processes
pkill -f "port-forward"
```

---

## 🔄 Workflow: Adding a New Use Case

1. **Create manifests** in `k8s/<use-case>/`
   - 00-namespace.yaml
   - 01-gateway.yaml (or extend existing)
   - 02-resource.yaml
   - etc.

2. **Create deploy script** in `scripts/deploy-<use-case>.sh`
   - Read existing scripts for patterns
   - Use `kubectl apply -f k8s/<use-case>/`
   - Add wait/rollout logic

3. **Create test file** in `tests/test-<use-case>.sh`
   - Use `check()` and `check_http()` helper functions
   - Verify both K8s resources and HTTP behavior
   - Print `[PASS]` or `[FAIL]`

4. **Update Makefile**
   - Add `deploy-<use-case>` target
   - Add to `test-all` target

5. **Update architecture diagram** in `docs/architecture.md`
   - Add components to Mermaid graph
   - Update component summary table

6. **Update this README**
   - Add use case description
   - Document deploy & test commands
   - Include workflow diagram if needed

---

## 📖 Further Reading

- [kgateway documentation](https://kgateway.dev/docs)
- [Gateway API spec](https://gateway-api.sigs.k8s.io)
- [Envoy proxy docs](https://www.envoyproxy.io/docs)
- [Keycloak documentation](https://www.keycloak.org/documentation.html)

---

## 📄 License

This playground is provided as-is for educational and testing purposes.

---

## 🤝 Contributing

To add a new use case:
1. Follow the workflow above
2. Ensure all tests pass: `make test-all`
3. Update docs
4. Test with a fresh cluster: `make cluster-down && make cluster-up`

---

**Last Updated:** 2026-06-26  
**Status:** Use Cases 1–3 complete & tested ✅
