# Working And Not Working Scenarios

This matrix helps customers choose the right pattern for deterministic outbound IP from Power Platform.

## Working Scenarios

These scenarios are expected to use the Azure NAT Gateway public IP when the Power Platform environment is correctly enabled for virtual network support and the workload uses a supported runtime path.

| Scenario | Expected result | Why it works | Proof method |
| --- | --- | --- | --- |
| Power App calls a VNet-supported custom connector, custom connector calls public AWS MCP endpoint | AWS sees the NAT Gateway public IP | The custom connector executes through the Power Platform delegated subnet path | AWS logs or MCP ingress probe show `20.166.89.8` or the paired-region NAT IP |
| Power Automate flow calls a VNet-supported custom connector, custom connector calls public AWS MCP endpoint | AWS sees the NAT Gateway public IP | The flow uses the custom connector runtime path, not the built-in HTTP action path | Destination logs show the NAT Gateway public IP |
| Custom connector calls this repo's Azure inspection endpoint | Inspection endpoint sees the NAT Gateway public IP | This is the proof path used in the demo | `powerplatform-test-009` observed `20.166.89.8` |
| Dataverse plug-in uses the VNet-supported path to call an external endpoint | External endpoint should see the NAT Gateway public IP | Supported Dataverse plug-ins can execute through virtual network support | Destination-side source IP log |
| Custom connector calls an Azure private endpoint-backed service reachable from the delegated network design | Traffic uses the virtual network-supported connector path | The target service is reachable through the configured network path | Service logs, private DNS, and connector test result |
| AWS MCP endpoint has WAF/API Gateway/ALB allowlist for both NAT IPs | Request is allowed when app authentication also succeeds | AWS permits the stable Azure NAT public source IPs | AWS access logs plus app response |

## Not Working Or Not Guaranteed Scenarios

These scenarios should not be presented as deterministic NAT Gateway egress from this Power Platform design.

| Scenario | Expected issue | Why it does not meet the requirement | Better pattern |
| --- | --- | --- | --- |
| Power Automate built-in HTTP action calls AWS MCP directly | AWS may see Microsoft-managed Power Automate or Logic Apps source IPs | Built-in HTTP actions do not prove the delegated subnet/NAT Gateway path | Use a VNet-supported custom connector |
| Built-in Logic Apps action calls AWS MCP directly | Source IP is controlled by Logic Apps networking, not this Power Platform VNet injection | Logic Apps has separate networking patterns | Use Power Platform custom connector, or design Logic Apps Standard with its own VNet/NAT pattern |
| Any random Power Platform connector is assumed to use NAT Gateway | Source IP may not be the NAT Gateway | Only supported connectors/runtime paths should be treated as VNet-supported | Validate the specific connector with destination-side logs |
| Power Platform custom connector is created in a non-managed environment | VNet support cannot be enabled | Managed Environment is required for Power Platform virtual network support | Convert/use a Managed Environment with required licensing |
| Customer uses built-in HTTP action for proof because it returns 200 | Functional success but invalid source-IP proof | The destination may see Microsoft shared service IPs | Use the included NAT Proof Inspector connector |
| AWS endpoint is private-only inside a VPC with no public ingress | NAT Gateway public egress alone cannot reach it | NAT Gateway is outbound internet SNAT, not private cross-cloud connectivity | Use VPN/ExpressRoute/Direct Connect pattern, or expose a secured public ingress |
| AWS only allowlists one NAT IP | Some paired-region/failover traffic can be blocked | Europe has West Europe and North Europe delegated paths | Allowlist both `51.124.38.135` and `20.166.89.8` |
| Destination trusts the first `X-Forwarded-For` hop without understanding proxies | Wrong IP may be interpreted as the source | Forwarding headers can contain multiple hops | Use trusted proxy rules and platform access logs |

## Current Demo Status

| Path | Status | Evidence |
| --- | --- | --- |
| North Europe custom connector egress through NAT `20.166.89.8` | Proven | [NAT-PROOF-RESULTS.md](NAT-PROOF-RESULTS.md) |
| West Europe custom connector egress through NAT `51.124.38.135` | Configured, not yet observed | Requires West Europe runtime execution, failover, or support-guided validation |
| Built-in Power Automate HTTP action through NAT Gateway | Not proven and not recommended | Use custom connector path instead |
| AWS MCP call through NAT Gateway | Prepared but not deployed/tested in AWS | Use [AWS-MCP-INTEGRATION.md](AWS-MCP-INTEGRATION.md) and [tools/mcp-ingress-probe](../tools/mcp-ingress-probe) |

## Customer Decision Rule

If the customer needs a stable outbound source IP for an external service, use this rule:

```text
Need deterministic Power Platform outbound IP?
  -> Use a VNet-supported custom connector or supported Dataverse plug-in.
  -> Prove from the destination logs.
  -> Do not use built-in HTTP action as the proof path.
```