# Regional Proxy Enforcement Model

The customer-controlled proxy pattern is the recommended architecture when the customer needs AWS to see a deterministic Azure-owned public source IP.

## Enforced Path

```text
Power App / Power Automate / Logic App
  -> approved regional proxy connector or proxy URL
  -> Azure Container Apps proxy in the matching regional VNet
  -> NAT Gateway on the Container Apps environment subnet
  -> AWS MCP endpoint or public proof endpoint
```

## What Is Enforced

| Layer | Enforcement |
| --- | --- |
| Application design | Apps and flows call only the regional proxy connector or proxy URL. |
| Power Platform governance | DLP policies allow the approved proxy custom connectors and block generic direct HTTP or unapproved connectors. |
| Azure egress | The proxy runs in a customer VNet subnet associated with NAT Gateway. |
| AWS ingress | AWS allowlists only the regional NAT public IPs. Direct bypass traffic from Microsoft-managed connector or Logic Apps IPs is rejected. |
| Operations | Proxy logs, Container Apps revisions, and AWS access logs provide an auditable trail. |

## What Is Not Enforced

| Limitation | Explanation |
| --- | --- |
| Transparent interception | The proxy does not intercept arbitrary Power Platform or Logic Apps traffic. The app or workflow must call it explicitly. |
| Tenant-wide outbound control | This repo does not force every connector in every environment through NAT Gateway. Use DLP, environment strategy, and AWS deny-by-default. |
| Direct connector paths | Direct calls to `api.ipify.org` and `checkip.amazonaws.com` already proved they can show `20.86.93.37`, not the NAT IPs. |
| Private AWS targets | NAT Gateway is public outbound SNAT. Private AWS connectivity needs VPN, ExpressRoute/Direct Connect, or private endpoint architecture. |
| Production security | The demo Container Apps proxy has no production auth layer. Use APIM, OAuth, mTLS, private ingress, or equivalent controls for customer use. |

## Pros

- AWS sees stable customer-controlled source IPs: `20.166.89.8` and `51.124.38.135` in this demo.
- The architecture is easy to prove from destination-observed logs.
- The proxy can add centralized logging, request validation, authentication, header normalization, and retry behavior.
- It works for both Power Platform and Logic Apps because both can call HTTPS proxy endpoints.

## Cons And Tradeoffs

- Adds another hop, which means more latency, cost, and operational ownership.
- Requires two regional proxies for the paired Europe architecture if the customer wants symmetric regional proof and failover readiness.
- Requires customer governance discipline. If direct connectors remain allowed and AWS allowlists broad Microsoft IP ranges, makers can bypass the proxy.
- Container Apps is suitable for proof and lightweight proxying. For stricter enterprise governance, put Azure API Management or Azure Firewall in the path.

## Customer Acceptance Criteria

A customer-ready rollout should satisfy all of these checks:

| Check | Required result |
| --- | --- |
| North Europe proxy proof | `api.ipify.org` and `checkip.amazonaws.com` observe `20.166.89.8`. |
| West Europe proxy proof | `api.ipify.org` and `checkip.amazonaws.com` observe `51.124.38.135`. |
| Power Automate connector path | Flow uses `NEU NAT Proxy` or `WEU NAT Proxy`, not direct HTTP. |
| Logic App path | Workflow HTTP action targets only the proxy URL or APIM front door. |
| AWS allowlist | AWS allows only `20.166.89.8` and `51.124.38.135` for this integration path. |
| Bypass test | Direct calls from unapproved paths fail at AWS or are blocked by DLP/governance. |
