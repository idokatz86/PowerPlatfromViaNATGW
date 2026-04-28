# Power Platform Connector Gateway Behavior

This project uses destination-observed IP tests to avoid guessing how a Power Platform connector request was routed.

## What Microsoft Documents

Microsoft documents that Azure Virtual Network support for Power Platform uses subnet delegation for Power Platform runtime workloads. The delegated subnet is reserved for Power Platform, and Power Platform containers execute requests from virtual network-supported services.

Microsoft also documents that attaching Azure NAT Gateway to the delegated subnet is the recommended way to restrict and control outbound internet traffic from Power Platform containers. If no NAT Gateway or custom route is configured, internet-bound traffic can still egress from Power Platform-owned IP addresses.

At the same time, Microsoft documents that managed connectors, custom connectors, Power Automate, and Logic Apps have connector service outbound IP behavior. Built-in HTTP actions and managed connector paths can use Microsoft-managed connector infrastructure IPs rather than a customer NAT Gateway.

## Why The Results Can Look Different

There are multiple possible execution paths:

| Path | What controls outbound IP | Expected proof behavior |
| --- | --- | --- |
| VNet-supported custom connector or plug-in running through delegated subnet | Customer VNet controls, including NAT Gateway | Destination should see the NAT Gateway public IP |
| Built-in Power Automate HTTP action | Power Automate / Logic Apps service infrastructure | Destination can see Microsoft-managed service IPs |
| Managed connector not using the delegated subnet path | Connector service infrastructure | Destination can see Microsoft-managed connector IPs |
| Browser, local shell, or admin portal call | User's client network or browser session path | Invalid Power Platform NAT proof |
| Customer-controlled Azure proxy in VNet | Customer VNet controls, including NAT Gateway | Destination sees the proxy subnet NAT Gateway public IP |

The test must therefore answer two separate questions:

1. Did the call succeed?
2. Did the destination observe one of the expected NAT Gateway public IPs?

A successful HTTP `200` only answers the first question. It does not prove NAT Gateway egress unless the destination-observed IP matches the NAT Gateway public IP.

## How To Explain The Public IP Echo Results

Both public IP echo tests returned `20.86.93.37`:

| Test destination | Result | Classification |
| --- | --- | --- |
| `api.ipify.org` | `20.86.93.37` | Not a valid NAT Gateway proof |
| `checkip.amazonaws.com` | `20.86.93.37` | Not a valid NAT Gateway proof |

That proves the connector reached the public internet, but it does not prove the customer NAT Gateway path because the expected NAT Gateway IPs are:

- `20.166.89.8`
- `51.124.38.135`

So the correct customer explanation is:

```text
The public IP echo call succeeded, but it did not prove NAT Gateway egress.
For deterministic NAT proof, the destination must show one of the NAT Gateway public IPs.
```

This also means that for the final AWS MCP target, AWS-side validation is mandatory. In this demo, AWS checkip saw `20.86.93.37`, not the NAT Gateway IP.

## Validated Proxy Contrast

The customer-controlled Azure proxy pattern changes which service makes the AWS-facing call. Power Platform or Logic Apps calls the proxy, and the proxy calls AWS from a customer VNet subnet associated with NAT Gateway.

| Path | `api.ipify.org` observed | `checkip.amazonaws.com` observed | Classification |
| --- | --- | --- | --- |
| Direct public connector path | `20.86.93.37` | `20.86.93.37` | Not a NAT Gateway proof |
| North Europe Container Apps proxy path | `20.166.89.8` | `20.166.89.8` | Valid NAT Gateway proof |
| West Europe Container Apps proxy path | `51.124.38.135` | `51.124.38.135` | Valid NAT Gateway proof |

This is the main customer explanation: the proxy is not a transparent network intercept. It is a customer-owned egress point that the app or workflow must call explicitly.

## Recommended Proof Standard

Use a destination endpoint that the customer controls, or an AWS-side diagnostic endpoint for the MCP scenario. The proof is valid when the destination logs show the expected NAT Gateway public IP.

Best proof sources:

- AWS ALB access logs
- AWS API Gateway access logs
- AWS WAF logs
- AWS-side MCP ingress probe
- This repo's Azure inspection endpoint
- The validated regional Container Apps proxy endpoints

Simple public IP echo services such as `api.ipify.org` and `checkip.amazonaws.com` are useful smoke tests, but only count as proof if they return one of the NAT Gateway IPs. In this demo, both returned `20.86.93.37`, so they are documented as non-proof paths.