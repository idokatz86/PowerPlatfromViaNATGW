# NAT Proof Results

## Confirmed Result

Yes: the Power Platform custom connector test exited through the North Europe NAT Gateway public IP.

| Field | Value |
| --- | --- |
| Test run | `powerplatform-test-009` |
| Timestamp | `2026-04-28T20:20:21.854Z` |
| Power Platform environment | `f021725d-8eeb-e31b-9427-7334c58a3a5b` |
| Inspection endpoint | `https://ppnatgw-inspect-frc-06311682.azurewebsites.net/inspect` |
| Destination-observed source IP | `20.166.89.8` |
| Matching NAT Gateway | `ppnatgw-nat-neu` |
| NAT Gateway region | `northeurope` |
| Subnet delegation header | `x-ms-subnet-delegation-enabled: true` |
| Power Platform forwarded host | `sbx.neu-il109.gateway.prod.island.powerapps.com` |

Evidence files:

- [powerplatform-test-009-nat-proof.json](evidence/powerplatform-test-009-nat-proof.json)
- [powerplatform-test-009-nat-proof.png](screenshots/powerplatform-test-009-nat-proof.png)

## Response Excerpt

```json
{
  "timestamp": "2026-04-28T20:20:21.854Z",
  "run": "powerplatform-test-009",
  "observedClientIp": "20.166.89.8",
  "rawObservedClientIp": "20.166.89.8:50750",
  "appServiceClientIp": "20.166.89.8:50750",
  "xForwardedFor": "::ffff:20.86.93.37, 20.166.89.8:50750",
  "xMsSubnetDelegationEnabled": "true",
  "xForwardedHost": "sbx.neu-il109.gateway.prod.island.powerapps.com"
}
```

## Remaining Paired-Region Proof

The West Europe NAT Gateway public IP is `51.124.38.135`. It has not yet been observed by the destination endpoint. The test runs executed so far stayed on the North Europe Power Platform runtime path, so only the North Europe NAT Gateway is proven by destination-observed traffic.
