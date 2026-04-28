# Power Automate Regional Proxy Example

This example shows how to make a Power Automate flow use only the customer-controlled regional proxy endpoints for the outbound proof call.

The current end-to-end capture is in [POWER-AUTOMATE-E2E-RESULTS.md](POWER-AUTOMATE-E2E-RESULTS.md). It proves that the regional custom connectors work, that direct built-in HTTP does not use the customer NAT Gateway, and that built-in HTTP can be acceptable only when it calls the approved regional proxy endpoints.

## Created Custom Connectors

| Region | Display name | Connector ID | Internal name | Proxy host |
| --- | --- | --- | --- | --- |
| North Europe | `NEU NAT Proxy` | `738e979f-4a43-f111-88b5-7ced8d76efb6` | `new_neu-20nat-20proxy` | `<north-region-proxy-host>` |
| West Europe | `WEU NAT Proxy` | `411718a6-4a43-f111-88b5-7ced8d76efb6` | `new_weu-20nat-20proxy` | `<west-region-proxy-host>` |

Connector definitions are stored in:

- [connectors/containerapps-proxy-neu.swagger.json](../connectors/containerapps-proxy-neu.swagger.json)
- [connectors/containerapps-proxy-weu.swagger.json](../connectors/containerapps-proxy-weu.swagger.json)
- [connectors/containerapps-proxy.apiProperties.json](../connectors/containerapps-proxy.apiProperties.json)

## Flow Shape

Create one flow per region, or one flow with an explicit region selection branch.

North Europe branch:

```text
Manual trigger
  -> NEU NAT Proxy / Run both NAT proof checks
  -> Parse or store response
  -> Validate ipify.observedIp == <north-region-nat-ip>
  -> Validate awsCheckIp.observedIp == <north-region-nat-ip>
```

West Europe branch:

```text
Manual trigger
  -> WEU NAT Proxy / Run both NAT proof checks
  -> Parse or store response
  -> Validate ipify.observedIp == <west-region-nat-ip>
  -> Validate awsCheckIp.observedIp == <west-region-nat-ip>
```

The flow must not call `api.ipify.org`, `checkip.amazonaws.com`, or the AWS MCP endpoint directly. It calls the regional proxy connector only.

If the customer chooses to use the built-in HTTP action instead of the custom connector, restrict the URI to the approved proxy hostnames only. The built-in action direct to `checkip.amazonaws.com` succeeded in the demo but returned `<built-in-http-direct-egress-ip>`, so it is a functional path but not an enforced NAT path.

## Enforcement Controls

Use Power Platform DLP and environment governance so makers can only use the approved proxy connectors for this scenario:

| Control | Customer action |
| --- | --- |
| Approved connectors | Put `NEU NAT Proxy` and `WEU NAT Proxy` in the Business connector group. |
| Direct HTTP bypass | Block or isolate the built-in HTTP connector and any generic direct outbound connectors for this environment. |
| Unapproved custom connectors | Require admin approval for new custom connectors and keep this solution in a controlled environment. |
| AWS allowlist | Allow only `<north-region-nat-ip>` and `<west-region-nat-ip>` at AWS WAF/API Gateway/ALB/security controls. |
| Proxy authentication | Add APIM, OAuth, mTLS, or API-key protection before production use. The demo proxy is intentionally simple for proof. |

## Customer Message

This does not transparently intercept every possible Power Automate outbound call. It enforces the approved architecture by making the flow call only the regional proxy connector and by blocking direct alternatives with governance. The AWS side completes enforcement by rejecting requests that do not originate from the proxy NAT IPs.
