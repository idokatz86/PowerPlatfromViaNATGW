# AWS checkip NAT Proof

This proof uses a custom connector named **AWS CheckIP Proof** that calls `https://checkip.amazonaws.com/`.

This is useful because the destination is AWS-hosted, which is closer to the final AWS MCP scenario than a generic public IP service.

## Captured Demo Result

The live Power Platform custom connector test completed successfully with HTTP `200`, but AWS checkip returned:

```text
::ffff:20.86.93.37
```

Normalized IPv4 value:

```text
20.86.93.37
```

That IP is **not** one of the configured NAT Gateway public IPs for this demo:

- North Europe NAT Gateway: `20.166.89.8`
- West Europe NAT Gateway: `51.124.38.135`

Classification: **not a valid NAT Gateway proof** for this run.

Evidence:

- [evidence/aws-checkip-proof-2026-04-28.json](evidence/aws-checkip-proof-2026-04-28.json)
- [screenshots/aws-checkip-proof-2026-04-28.png](screenshots/aws-checkip-proof-2026-04-28.png)

## Customer Impact

For the AWS MCP scenario, this result matters more than the `api.ipify.org` result because the destination is AWS-hosted. It means customers should not assume AWS will see the Azure NAT Gateway public IP just because the Power Platform environment has VNet support and NAT Gateway attached.

Before using AWS WAF, API Gateway, ALB, or application allowlists, the customer should deploy an AWS-side diagnostic endpoint and verify what AWS actually observes.

If AWS observes `20.86.93.37`, then allowlisting only `20.166.89.8` and `51.124.38.135` will block the call.