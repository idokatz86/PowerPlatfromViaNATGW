# Container Apps Proxy NAT Proof

This proof validates the customer-controlled Azure proxy pattern. The public IP echo services are not called directly from Power Platform or Logic Apps. They are called from Azure Container Apps running in customer VNets with NAT Gateway attached to the Container Apps environment subnet.

## Regional Proxy Endpoints

| Region | Proxy URL | VNet | Subnet | NAT Gateway | Expected public IP |
| --- | --- | --- | --- | --- | --- |
| North Europe | `https://ppnatgw-proxy.yellowmeadow-5cf2ecd6.northeurope.azurecontainerapps.io` | `ppnatgw-vnet-neu` | `snet-containerapps-proxy` | `ppnatgw-nat-neu` | `20.166.89.8` |
| West Europe | `https://ppnatgw-proxy-weu.orangesea-6ab30ac0.westeurope.azurecontainerapps.io` | `ppnatgw-vnet-weu` | `snet-containerapps-proxy` | `ppnatgw-nat-weu` | `51.124.38.135` |

## Validation Results

| Region | Test | Observed IP | Result | Evidence |
| --- | --- | --- | --- | --- |
| North Europe | `api.ipify.org` through proxy | `20.166.89.8` | Pass | [containerapps-proxy-neu-2026-04-28.json](evidence/containerapps-proxy-neu-2026-04-28.json) |
| North Europe | `checkip.amazonaws.com` through proxy | `20.166.89.8` | Pass | [containerapps-proxy-neu-2026-04-28.json](evidence/containerapps-proxy-neu-2026-04-28.json) |
| West Europe | `api.ipify.org` through proxy | `51.124.38.135` | Pass | [containerapps-proxy-weu-2026-04-28.json](evidence/containerapps-proxy-weu-2026-04-28.json) |
| West Europe | `checkip.amazonaws.com` through proxy | `51.124.38.135` | Pass | [containerapps-proxy-weu-2026-04-28.json](evidence/containerapps-proxy-weu-2026-04-28.json) |

## Why This Is Stronger Than Direct Public Echo Tests

Direct Power Platform custom connector tests to `api.ipify.org` and `checkip.amazonaws.com` returned `20.86.93.37`, not the NAT Gateway public IPs. That showed a Microsoft-managed connector gateway path was involved.

The Container Apps proxy tests returned the exact regional NAT Gateway IPs because the AWS-facing/public-internet-facing call is made by a customer-owned workload running inside the customer's Azure VNet. This is the enforceable boundary for AWS allowlisting.

## Re-run The Proof

North Europe:

```bash
curl -sS https://ppnatgw-proxy.yellowmeadow-5cf2ecd6.northeurope.azurecontainerapps.io/proxy/all
```

West Europe:

```bash
curl -sS https://ppnatgw-proxy-weu.orangesea-6ab30ac0.westeurope.azurecontainerapps.io/proxy/all
```

A valid response must show `natProof: true` for both `ipify` and `awsCheckIp`.
