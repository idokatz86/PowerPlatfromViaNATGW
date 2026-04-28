# AWS MCP Integration Guidance

The target customer flow is:

```text
Power App / Power Automate
  -> VNet-supported custom connector
  -> delegated subnet
  -> Azure NAT Gateway public IP
  -> AWS-hosted MCP endpoint
```

## What AWS Must Allow

For a public AWS MCP endpoint, AWS must allow inbound HTTPS from the Azure NAT Gateway public IPs.

| Azure NAT Gateway | Region | Public IP | AWS action |
| --- | --- | --- | --- |
| `ppnatgw-nat-weu` | West Europe | `51.124.38.135` | Add to allowlist for high availability / paired-region path |
| `ppnatgw-nat-neu` | North Europe | `20.166.89.8` | Add to allowlist; this is the proven active path |

Depending on how the MCP endpoint is exposed, the customer may need to update one or more of these AWS controls:

- Security group inbound rule for TCP 443 if the endpoint is behind an ALB/NLB or EC2-based service.
- AWS WAF IP set allowlist if WAF protects CloudFront, ALB, or API Gateway.
- API Gateway resource policy if API Gateway is restricted by source IP.
- CloudFront/WAF rule if the MCP endpoint is fronted by CloudFront.
- Application-level allowlist if the MCP server checks source IP itself.

No AWS IAM role is required merely because the call originates from Power Platform through Azure NAT. IAM is needed only if the MCP endpoint uses AWS IAM/SigV4 authentication or if the deployment/operations pipeline changes AWS resources.

## Authentication

The source IP proof only proves network egress. The MCP endpoint should still require application authentication, such as:

- OAuth 2.0 / Entra ID federation if supported by the MCP gateway.
- API key stored securely in Power Platform connection references or Azure Key Vault-backed configuration.
- Mutual TLS if the MCP ingress layer supports it.
- AWS IAM SigV4 only if the connector or an intermediary can sign requests correctly.

Do not rely on IP allowlisting as the only security control.

## Public vs Private AWS Endpoint

This NAT Gateway design proves public internet egress with a stable Azure source IP. It does not by itself create private connectivity to an AWS VPC.

If the MCP endpoint is private-only inside AWS, the customer needs a private connectivity design, such as:

- Site-to-site VPN or ExpressRoute plus AWS Direct Connect through an approved network topology.
- A public AWS ingress endpoint protected by WAF, authentication, and NAT IP allowlisting.
- A customer-managed relay/API layer reachable from the delegated subnet path.

## Diagnostic Tooling

Use the included MCP ingress probe when AWS-side behavior is unclear. Deploy it beside or in front of the MCP endpoint and call it from the same Power Platform connector path.

Probe location in this repo:

```text
tools/mcp-ingress-probe
```

The probe exposes:

| Endpoint | Purpose |
| --- | --- |
| `GET /health` | Basic health check |
| `GET /inspect?run=<id>` | Echo source IP, forwarding headers, and request metadata |
| `POST /mcp` | Minimal JSON-RPC-style MCP diagnostic response with source IP metadata |

Use the probe to answer three questions:

1. Did the request reach AWS?
2. What source IP did AWS observe?
3. Did the request carry the expected Power Platform headers, correlation ID, and authentication headers?

## Why The Proof Endpoint Uses `client-ip`

Azure App Service adds a `client-ip` header that represents the client IP observed by the App Service front end. In this NAT proof, that value is the NAT Gateway public IP and port.

The `x-forwarded-for` header can contain multiple hops. In the successful run, it contained both an internal upstream hop and the NAT Gateway public IP:

```text
x-forwarded-for: ::ffff:20.86.93.37, 20.166.89.8:50750
client-ip: 20.166.89.8:50750
```

For the proof tool, `observedClientIp` is derived from `client-ip` first, then falls back to `x-forwarded-for` only when `client-ip` is unavailable.

AWS services may expose the equivalent source information differently:

- ALB: inspect `X-Forwarded-For` and ALB access logs.
- API Gateway: inspect `$context.identity.sourceIp` or access logs.
- CloudFront: inspect standard logs or real-time logs, often with WAF logs.
- Container/app server: inspect the remote address and trusted proxy headers from the ingress layer.