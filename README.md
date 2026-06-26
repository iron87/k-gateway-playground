# kgateway Playground

A local Kubernetes playground for exploring [kgateway](https://github.com/kgateway-dev/kgateway) — an Envoy-based Gateway API implementation.

## Use Cases

### Use Case 1: Product Proxy with Internal & External Endpoints

Gateway routing to both internal services and external APIs.

```bash
make deploy-product
make test-product
```

### Use Case 2: Keycloak OIDC + JWT Authentication

Secure gateway routes with OpenID Connect tokens from Keycloak.

```bash
make deploy-auth
make test-auth
```

Credentials: `test-user` / `password123`

### Use Case 3: Local Rate Limiting

Token bucket rate limiting on gateway (10 tokens/second).

```bash
make deploy-ratelimit
make test-ratelimit
```

### Use Case 4: HTTPS/TLS Termination

Gateway with self-signed TLS certificate (CN=gateway.local) on port 8443.

```bash
make deploy-product
make test-https
```

## Makefile Targets

| Target | Purpose |
|--------|---------|
| `make cluster-up` | Create kind cluster |
| `make cluster-down` | Delete kind cluster |
| `make kgateway` | Install kgateway + Gateway API CRDs |
| `make deploy-product` | Deploy routing (UC1) + HTTPS (UC4) |
| `make deploy-auth` | Deploy Keycloak + JWT (UC2) |
| `make deploy-ratelimit` | Deploy rate limiting (UC3) |
| `make test-kgateway` | Test control plane |
| `make test-product` | Test routing |
| `make test-auth` | Test JWT auth |
| `make test-ratelimit` | Test rate limiting |
| `make test-https` | Test HTTPS/TLS |

## Testing

Each use case has independent tests verifying resource health and HTTP behavior using bash, kubectl, and curl.

Test dependencies:
- `test-kgateway` — no dependencies
- `test-product` — requires `deploy-product`
- `test-auth` — requires `deploy-product` + `deploy-auth`
- `test-ratelimit` — requires `deploy-product` + `deploy-auth` + `deploy-ratelimit`
- `test-https` — requires `deploy-product`

## Architecture

See [docs/architecture.md](docs/architecture.md) for system architecture diagram.

## Further Reading

- [kgateway documentation](https://kgateway.dev/docs)
- [Gateway API spec](https://gateway-api.sigs.k8s.io)
- [Envoy proxy docs](https://www.envoyproxy.io/docs)
- [Keycloak documentation](https://www.keycloak.org/documentation.html)
