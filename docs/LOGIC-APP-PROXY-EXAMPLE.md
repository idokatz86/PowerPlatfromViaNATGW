# Logic App Regional Proxy Example

This example deploys two Logic App Consumption workflows. Each workflow calls only its regional Container Apps proxy endpoint.

## Deployed Workflows

| Region | Workflow | Proxy URL | Expected observed IP | Evidence |
| --- | --- | --- | --- | --- |
| North Europe | `<north-region-container-app-name>-proof-neu-la` | `https://<north-region-proxy-host>` | `<north-region-nat-ip>` | [logicapp-proxy-neu-2026-04-28.json](evidence/logicapp-proxy-neu-2026-04-28.json) |
| West Europe | `<north-region-container-app-name>-proof-weu-la` | `https://<west-region-proxy-host>` | `<west-region-nat-ip>` | [logicapp-proxy-weu-2026-04-28.json](evidence/logicapp-proxy-weu-2026-04-28.json) |

## Deploy And Test

```bash
./scripts/11-deploy-logicapp-proxy-example.sh
```

The script deploys [infra/logicapp-proxy-example.bicep](../infra/logicapp-proxy-example.bicep), retrieves the private request trigger URLs, invokes each workflow, and prints the proxy proof response. It does not store trigger URLs in the repository.

## Workflow Shape

```text
HTTP request trigger
  -> HTTP GET regional Container Apps proxy /proxy/all
  -> HTTP response with proxy result
```

The Logic App does not call `api.ipify.org`, `checkip.amazonaws.com`, or AWS directly. The only public outbound target in the example workflow definition is the regional Container Apps proxy endpoint.

## Enforcement Notes

Logic Apps is not governed by Power Platform VNet injection. To enforce this pattern for Logic Apps, use a separate Logic Apps governance model:

| Control | Customer action |
| --- | --- |
| Workflow review | Only approve workflow definitions whose outbound HTTP actions target the regional proxy or APIM endpoint. |
| Azure Policy | Use Azure Policy or deployment guardrails to audit/block workflows with non-approved HTTP action URIs where possible. |
| Network model | For Logic Apps Standard, use VNet integration and NAT/Firewall directly if the customer wants Logic Apps itself to own the egress path. |
| AWS allowlist | AWS must allow only the proxy NAT IPs so direct Logic Apps bypass attempts fail at the destination. |

For the proof in this repo, the Logic App examples validate that the regional proxy architecture works. They do not claim that every possible Logic Apps workflow in the tenant is automatically forced through the proxy.
