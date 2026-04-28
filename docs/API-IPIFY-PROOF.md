# api.ipify.org NAT Proof

This proof uses a second custom connector named **IPify NAT Proof** that calls `https://api.ipify.org/?format=json`.

The expected response shape is:

```json
{
  "ip": "<north-region-nat-ip>"
}
```

## How To Interpret The Result

| Result from `api.ipify.org` | Meaning | Scenario classification |
| --- | --- | --- |
| `<north-region-nat-ip>` | The request used the North Europe NAT Gateway public IP from this demo | Working scenario |
| `<west-region-nat-ip>` | The request used the West Europe NAT Gateway public IP from this demo | Working scenario |
| Any other Microsoft-owned public IP | The request did not prove the configured NAT Gateway path | Not working or not guaranteed |
| Customer office, VPN, or local machine IP | The call was not made by the Power Platform connector runtime | Invalid proof path |
| No response, DNS failure, 403, or timeout | The destination could not be reached or the connector runtime failed | Troubleshoot before classifying |

## Why This Is Useful

`api.ipify.org` is a simple external IP echo service. It cannot show Power Platform headers, environment IDs, or forwarding chains, but it is useful for a quick customer-friendly check because the only important value is the destination-observed public source IP.

For deeper troubleshooting, use [NAT-PROOF-RESULTS.md](NAT-PROOF-RESULTS.md) and the Azure inspection endpoint because that endpoint captures headers such as `x-ms-subnet-delegation-enabled` and `x-ms-environment-id`.

## Captured Demo Result

The live Power Platform custom connector test completed successfully with HTTP `200`, but `api.ipify.org` returned this body:

```json
{
  "ip": "<microsoft-managed-egress-ip>"
}
```

That IP is **not** one of the configured NAT Gateway public IPs for this demo:

- North Europe NAT Gateway: `<north-region-nat-ip>`
- West Europe NAT Gateway: `<west-region-nat-ip>`

Classification: **not a valid NAT Gateway proof** for this flow.

Evidence:

- [evidence/api-ipify-nat-proof-2026-04-28.json](evidence/api-ipify-nat-proof-2026-04-28.json)
- [screenshots/api-ipify-nat-proof-2026-04-28.png](screenshots/api-ipify-nat-proof-2026-04-28.png)

This does not change the earlier Azure inspection endpoint proof, where the destination observed the North Europe NAT Gateway IP `<north-region-nat-ip>`. It means `api.ipify.org` is useful as a customer-friendly smoke test only if its returned `ip` equals one of the expected NAT Gateway public IPs.