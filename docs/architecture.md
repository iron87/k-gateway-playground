# Architecture — kgateway Playground

## Use Case 1 — Product Proxy (dedicated, non-shared Gateway)

```mermaid
graph TD
    subgraph kind["kind Cluster — kgateway-playground"]
        subgraph kgsys["Namespace: kgateway-system"]
            ctrl["Deployment: kgateway\n(control plane)"]
            gc["GatewayClass: kgateway"]
        end

        subgraph product["Namespace: product"]
            gw["Gateway: product-gateway\n(dedicated — port 8080)\nallowedRoutes: Same namespace"]
            r1["HTTPRoute: product-api-route\n/api/* → product-api"]
            r2["HTTPRoute: httpbin-route\n/httpbin/* → httpbin.org"]
            svc1["Service: product-api\n(ClusterIP :80)"]
            dep1["Deployment: product-api\n(httpbin image)"]
            back1["Backend: httpbin-backend\n(Static → httpbun.com:80)"]
        end
    end

    internet["httpbin.org\n(external)"]
    client["HTTP Client\nlocalhost:8080"]

    ctrl --> gc
    gc --> gw
    gw --> r1
    gw --> r2
    r1 --> svc1
    svc1 --> dep1
    r2 --> back1
    back1 --> internet
    client --> gw
```

## Component Summary

| Component | Kind | Namespace | Purpose |
|-----------|------|-----------|---------|
| kgateway | Deployment | kgateway-system | Control plane — manages Envoy data planes |
| kgateway | GatewayClass | cluster-scoped | Marks gateways managed by kgateway |
| product-gateway | Gateway | product | Dedicated gateway for the product domain |
| product-api-route | HTTPRoute | product | Routes `/api/*` to internal product-api |
| httpbin-route | HTTPRoute | product | Routes `/httpbin/*` to external httpbin.org |
| product-api | Deployment+Service | product | Mock internal REST API |
| httpbin-backend | Backend (Static) | product | Static route to httpbun.com:80 (httpbin-compatible) |
