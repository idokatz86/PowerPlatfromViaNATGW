# Power Automate Regional Proxy Example

This example shows how to make a Power Automate flow use only the customer-controlled regional proxy endpoints for the outbound proof call.

## Created Custom Connectors

| Region | Display name | Connector ID | Internal name | Proxy host |
| --- | --- | --- | --- | --- |
| North Europe | `NEU NAT Proxy` | `738e979f-4a43-f111-88b5-7ced8d76efb6` | `new_neu-20nat-20proxy` | `ppnatgw-proxy.yellowmeadow-5cf2ecd6.northeurope.azurecontainerapps.io` |
| West Europe | `WEU NAT Proxy` | `411718a6-4a43-f111-88b5-7ced8d76efb6` | `new_weu-20nat-20proxy` | `ppnatgw-proxy-weu.orangesea-6ab30ac0.westeurope.azurecontainerapps.io` |

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
  -> Validate ipify.observedIp == 20.166.89.8
  -> Validate awsCheckIp.observedIp == 20.166.89.8
```

West Europe branch:

```text
Manual trigger
  -> WEU NAT Proxy / Run both NAT proof checks
  -> Parse or store response
  -> Validate ipify.observedIp == 51.124.38.135
  -> Validate awsCheckIp.observedIp == 51.124.38.135
```

The flow must not call `api.ipify.org`, `checkip.amazonaws.com`, or the AWS MCP endpoint directly. It calls the regional proxy connector only.

## Enforcement Controls

Use Power Platform DLP and environment governance so makers can only use the approved proxy connectors for this scenario:

| Control | Customer action |
| --- | --- |
| Approved connectors | Put `NEU NAT Proxy` and `WEU NAT Proxy` in the Business connector group. |
| Direct HTTP bypass | Block or isolate the built-in HTTP connector and any generic direct outbound connectors for this environment. |
| Unapproved custom connectors | Require admin approval for new custom connectors and keep this solution in a controlled environment. |
| AWS allowlist | Allow only `20.166.89.8` and `51.124.38.135` at AWS WAF/API Gateway/ALB/security controls. |
| Proxy authentication | Add APIM, OAuth, mTLS, or API-key protection before production use. The demo proxy is intentionally simple for proof. |

## Customer Message

This does not transparently intercept every possible Power Automate outbound call. It enforces the approved architecture by making the flow call only the regional proxy connector and by blocking direct alternatives with governance. The AWS side completes enforcement by rejecting requests that do not originate from the proxy NAT IPs.
