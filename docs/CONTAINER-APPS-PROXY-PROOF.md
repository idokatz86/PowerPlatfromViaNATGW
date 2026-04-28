# Container Apps Proxy NAT Proof

This proof validates the customer-controlled Azure proxy pattern. The public IP echo services are not called directly from Power Platform or Logic Apps. They are called from Azure Container Apps running in customer VNets with NAT Gateway attached to the Container Apps environment subnet.

## Regional Proxy Endpoints

| Region | Proxy URL | VNet | Subnet | NAT Gateway | Expected public IP |
| --- | --- | --- | --- | --- | --- |
| North Europe | `https://<north-region-proxy-host>` | `<north-region-vnet-name>` | `snet-containerapps-proxy` | `<north-region-nat-gateway-name>` | `<north-region-nat-ip>` |
| West Europe | `https://<west-region-proxy-host>` | `<west-region-vnet-name>` | `snet-containerapps-proxy` | `<west-region-nat-gateway-name>` | `<west-region-nat-ip>` |

## Validation Results

| Region | Test | Observed IP | Result | Evidence |
| --- | --- | --- | --- | --- |
| North Europe | `api.ipify.org` through proxy | `<north-region-nat-ip>` | Pass | [containerapps-proxy-neu-2026-04-28.json](evidence/containerapps-proxy-neu-2026-04-28.json) |
| North Europe | `checkip.amazonaws.com` through proxy | `<north-region-nat-ip>` | Pass | [containerapps-proxy-neu-2026-04-28.json](evidence/containerapps-proxy-neu-2026-04-28.json) |
| West Europe | `api.ipify.org` through proxy | `<west-region-nat-ip>` | Pass | [containerapps-proxy-weu-2026-04-28.json](evidence/containerapps-proxy-weu-2026-04-28.json) |
| West Europe | `checkip.amazonaws.com` through proxy | `<west-region-nat-ip>` | Pass | [containerapps-proxy-weu-2026-04-28.json](evidence/containerapps-proxy-weu-2026-04-28.json) |

## Why This Is Stronger Than Direct Public Echo Tests

Direct Power Platform custom connector tests to `api.ipify.org` and `checkip.amazonaws.com` returned `<microsoft-managed-egress-ip>`, not the NAT Gateway public IPs. That showed a Microsoft-managed connector gateway path was involved.

The Container Apps proxy tests returned the exact regional NAT Gateway IPs because the AWS-facing/public-internet-facing call is made by a customer-owned workload running inside the customer's Azure VNet. This is the enforceable boundary for AWS allowlisting.

## Re-run The Proof

North Europe:

```bash
curl -sS https://<north-region-proxy-host>/proxy/all
```

West Europe:

```bash
curl -sS https://<west-region-proxy-host>/proxy/all
```

A valid response must show `natProof: true` for both `ipify` and `awsCheckIp`.
