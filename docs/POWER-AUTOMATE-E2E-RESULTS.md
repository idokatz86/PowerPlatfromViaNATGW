# Power Automate End-To-End Results

Capture date: 2026-04-28 UTC

Environment: `Fnx-mng` (`<power-platform-environment-id>`)

Expected NAT Gateway public IPs:

| Region | Expected NAT IP |
| --- | --- |
| North Europe | `<north-region-nat-ip>` |
| West Europe | `<west-region-nat-ip>` |

## Result Summary

| Power Automate path | Status | Destination-observed result | NAT proof |
| --- | --- | --- | --- |
| Custom connector `NEU NAT Proxy` -> NEU Container Apps proxy -> AWS checkip | HTTP 200 | `<north-region-nat-ip>` | Pass |
| Custom connector `WEU NAT Proxy` -> WEU Container Apps proxy -> AWS checkip | HTTP 200 | `<west-region-nat-ip>` | Pass |
| Built-in HTTP action -> AWS checkip directly | Flow succeeded | `<built-in-http-direct-egress-ip>` | Fail |
| Built-in HTTP action -> NEU/WEU Container Apps proxies -> AWS checkip | Flow succeeded | `<north-region-nat-ip>` and `<west-region-nat-ip>` | Pass |

## What This Means

Power Automate works end to end for the approved proxy architecture.

The deterministic pattern is:

```text
Power Automate flow
  -> approved regional proxy custom connector, or built-in HTTP action restricted to the approved proxy URL
  -> Azure Container Apps proxy in the regional VNet
  -> NAT Gateway
  -> AWS MCP or public destination
```

The direct built-in HTTP action is not an enforced NAT path. It successfully called `https://checkip.amazonaws.com/`, but AWS observed `<built-in-http-direct-egress-ip>`, not `<north-region-nat-ip>` or `<west-region-nat-ip>`.

## Captured Evidence

Detailed machine-readable evidence is stored in [docs/evidence/powerautomate-e2e-2026-04-28.json](evidence/powerautomate-e2e-2026-04-28.json).

The browser session also captured screenshots of:

| Page | Result |
| --- | --- |
| `NEU NAT Proxy` custom connector test tab | `GetAllProxyProofs` succeeded with HTTP 200 |
| `WEU NAT Proxy` custom connector test tab | `GetAllProxyProofs` succeeded with HTTP 200 |
| `AWS CheckIP Proof` direct custom connector test tab | HTTP 200, but body showed `::ffff:<microsoft-managed-egress-ip>`, proving that a direct connector gateway path is not the NAT path |

## Customer Guidance

Use the custom connector proxy path for the preferred Power Automate implementation. If a built-in HTTP action is allowed, restrict it to the approved proxy hostnames only and block direct AWS/public internet targets through governance and review.

AWS should enforce the final boundary by allowing only:

| Region | Allowlisted source IP |
| --- | --- |
| North Europe | `<north-region-nat-ip>` |
| West Europe | `<west-region-nat-ip>` |

Requests from any other source IP, including `<built-in-http-direct-egress-ip>` or `<microsoft-managed-egress-ip>`, should be rejected by the AWS endpoint or upstream access control.