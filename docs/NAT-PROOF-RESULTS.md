# NAT Proof Results

## Confirmed Result

Yes: the Power Platform custom connector test exited through the North Europe NAT Gateway public IP.

| Field | Value |
| --- | --- |
| Test run | `powerplatform-test-009` |
| Timestamp | `2026-04-28T20:20:21.854Z` |
| Power Platform environment | `<power-platform-environment-id>` |
| Inspection endpoint | `https://<inspection-web-app-host>/inspect` |
| Destination-observed source IP | `<north-region-nat-ip>` |
| Matching NAT Gateway | `<north-region-nat-gateway-name>` |
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
  "observedClientIp": "<north-region-nat-ip>",
  "rawObservedClientIp": "<north-region-nat-ip>:50750",
  "appServiceClientIp": "<north-region-nat-ip>:50750",
  "xForwardedFor": "::ffff:<microsoft-managed-egress-ip>, <north-region-nat-ip>:50750",
  "xMsSubnetDelegationEnabled": "true",
  "xForwardedHost": "sbx.neu-il109.gateway.prod.island.powerapps.com"
}
```

## Remaining Paired-Region Proof

The West Europe NAT Gateway public IP is `<west-region-nat-ip>`. It has not yet been observed by the destination endpoint. The test runs executed so far stayed on the North Europe Power Platform runtime path, so only the North Europe NAT Gateway is proven by destination-observed traffic.
