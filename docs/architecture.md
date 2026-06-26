                                                                                        # Architecture — kgateway Playground

## Use Cases 1, 2 & 3 — Product Proxy + Keycloak JWT Auth + Local Rate Limiting

```mermaid
graph TD
    subgraph kind["kind Cluster — kgateway-playground"]
        subgraph kgsys["Namespace: kgateway-system"]
            ctrl["Deployment: kgateway\n(control plane)"]
            gc["GatewayClass: kgateway"]
        end

        subgraph keycloak_ns["Namespace: keycloak"]
            kc["Deployment: keycloak\n(dev mode, port 8080)"]
            kc_svc["Service: keycloak"]
        end

        subgraph ratelimit_ns["Namespace: ratelimit"]
            note_rl["(Empty — for future use)\nWould hold: Envoy RateLimit + Redis"]
        end

        subgraph product["Namespace: product"]
            gw["Gateway: product-gateway\n(dedicated, non-shared)\nallowedRoutes: Same namespace"]
            tp_jwt["TrafficPolicy: product-jwt-auth\n(JWT Strict mode)"]
            ge_jwt["GatewayExtension: keycloak-jwt\n(JWKS from Keycloak)"]
            tp_rl["TrafficPolicy: product-rate-limit\n(Local token bucket)"]
            rg_kc["ReferenceGrant\nproduct → keycloak svc"]
            r1["HTTPRoute: product-api-route\n/api/* → product-api"]
            r2["HTTPRoute: httpbin-route\n/httpbin/* → httpbun.com"]
            svc1["Service: product-api\n(ClusterIP :80)"]
            dep1["Deployment: product-api\n(httpbin image)"]
            back1["Backend: httpbin-backend\n(Static → httpbun.com:80)"]
        end
    end

    internet["httpbun.com\n(external)"]
    client["HTTP Client\nlocalhost:8080\n(JWT required, rate limited)"]
    kc_client["Token client\nlocalhost:9080"]

    ctrl --> gc
    gc --> gw
    gw --> tp_jwt
    gw --> tp_rl
    tp_jwt --> ge_jwt
    ge_jwt -->|JWKS fetch| kc_svc
    kc_svc --> kc
    rg_kc -->|grants access| kc_svc
    gw --> r1
    gw --> r2
    r1 --> svc1
    svc1 --> dep1
    r2 --> back1
    back1 --> internet
    client -->|Authorization: Bearer JWT| gw
    kc_client -->|port-forward: get token| kc_svc
```

## Component Summary

| Component | Kind | Namespace | Purpose |
|-----------|------|-----------|---------|
| kgateway | Deployment | kgateway-system | Control plane — manages Envoy data planes |
| kgateway | GatewayClass | cluster-scoped | Marks gateways managed by kgateway |
| keycloak | Deployment+Service | keycloak | OIDC Identity Provider (dev mode, realm: playground) |
| product-gateway | Gateway | product | Dedicated gateway for the product domain |
| product-jwt-auth | TrafficPolicy | product | Enforces JWT (Keycloak) on all product-gateway routes |
| keycloak-jwt | GatewayExtension | product | JWT provider config — fetches JWKS from Keycloak |
| allow-product-to-keycloak | ReferenceGrant | keycloak | Allows cross-namespace JWKS backend reference |
| product-rate-limit | TrafficPolicy | product | Local token bucket rate limiting (10 req/sec) |
| product-api-route | HTTPRoute | product | Routes `/api/*` to internal product-api |
| httpbin-route | HTTPRoute | product | Routes `/httpbin/*` to external httpbun.com |
| product-api | Deployment+Service | product | Mock internal REST API |
| httpbin-backend | Backend (Static) | product | Static route to httpbun.com:80 (httpbin-compatible) |

---

## Rate Limiting Implementation

**Current:** Local token bucket (simple, no external service)
- Token bucket: 10 max tokens, 10 tokens/second
- Applied globally to all requests on product-gateway

**Future Option:** Global rate limit service (per-user, distributed state)
- Namespace: `ratelimit` (created but service disabled)
- Would use: Envoy RateLimit gRPC service + Redis backend
- Supports: per-user limits, cross-cluster state, descriptor-based rules
