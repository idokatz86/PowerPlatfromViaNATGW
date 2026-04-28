# Limitations And Customer Expectations

This document is the customer-facing boundary statement for the NAT Gateway proof.

For concrete examples, see [SCENARIOS.md](SCENARIOS.md), which lists working scenarios versus not working or not guaranteed scenarios.

## What This Solution Proves

This solution proves that a **VNet-supported Power Platform custom connector** can egress to the internet through the Azure NAT Gateway public IP attached to the delegated subnet.

In this demo, the proven path is:

```text
Power Platform custom connector
  -> Power Platform delegated subnet
  -> Azure NAT Gateway
  -> public internet
  -> inspection endpoint
```

The destination observed:

```text
observedClientIp = <north-region-nat-ip>
x-ms-subnet-delegation-enabled = true
```

That proves the North Europe NAT Gateway path for this environment.

This repository also proves a customer-controlled proxy path in both Europe regions:

| Region | Proxy path observed IP | Evidence |
| --- | --- | --- |
| North Europe | `<north-region-nat-ip>` | [CONTAINER-APPS-PROXY-PROOF.md](CONTAINER-APPS-PROXY-PROOF.md) |
| West Europe | `<west-region-nat-ip>` | [CONTAINER-APPS-PROXY-PROOF.md](CONTAINER-APPS-PROXY-PROOF.md) |

## What This Solution Does Not Prove

This solution does not prove that every Power Platform or Azure workflow action will use the NAT Gateway.

| Item | Status | Explanation |
| --- | --- | --- |
| VNet-supported custom connector | Supported and proven | This is the path used in the successful test. |
| Dataverse plug-in on the VNet-supported path | Supported path, validate separately | Use the same destination-side proof method. |
| Built-in Power Automate HTTP action | Not guaranteed | It may egress from Microsoft-managed Power Automate or Logic Apps infrastructure. |
| Built-in Logic Apps action | Not covered by this design | Logic Apps has separate networking patterns. |
| All Power Platform connectors | Not guaranteed | Only VNet-supported connector/runtime paths should be treated as NAT-controlled. |
| Private AWS endpoint access | Not provided by NAT Gateway alone | NAT Gateway gives stable public egress, not private cross-cloud routing. |
| Transparent interception of all outbound calls | Not provided | The proxy must be called explicitly, and governance must block direct alternatives. |

## Power Automate And Logic Apps Limitation

Customers should not assume that a normal Power Automate HTTP action or Logic Apps action will use the NAT Gateway created here.

The correct design for deterministic egress is:

```text
Power App or Power Automate flow
  -> VNet-supported custom connector
  -> delegated subnet
  -> Azure NAT Gateway public IP
  -> external service
```

The design to avoid for deterministic NAT egress is:

```text
Power Automate built-in HTTP action
  -> external service
```

That second path may work functionally, but it does not provide this NAT Gateway source-IP guarantee.

For deterministic cross-service egress, use the regional proxy pattern:

```text
Power Automate or Logic App
  -> regional customer-controlled proxy endpoint
  -> proxy subnet with NAT Gateway
  -> external service
```

This pattern is proven in this repo, but it still relies on app design and governance. It does not automatically rewrite or intercept arbitrary outbound calls.

## Paired-Region Limitation

Power Platform geographies can use paired regional runtime paths. Europe maps to West Europe and North Europe.

This demo deployed both NAT Gateways:

| Region | NAT Gateway public IP | Proof status |
| --- | --- | --- |
| West Europe | `<west-region-nat-ip>` | Configured, not yet destination-observed |
| North Europe | `<north-region-nat-ip>` | Proven by `powerplatform-test-009` |

For the Container Apps proxy architecture, both regional NAT IPs are destination-observed and proven.

A single successful connector call proves only the regional runtime path that handled that call. During this test, Power Platform executed from the North Europe path. Proving the West Europe path requires a call that actually runs from the West Europe paired runtime path, a failover event, or support-guided validation.

## AWS MCP Limitation

For an AWS-hosted MCP endpoint, AWS must allow inbound traffic from the Azure NAT Gateway public IPs. This solution does not automatically configure AWS.

Customers may need to update:

- AWS security groups.
- AWS WAF IP sets.
- API Gateway resource policies.
- CloudFront/WAF rules.
- Application-level source IP allowlists.

No AWS IAM role is required solely for source-IP allowlisting. AWS IAM or SigV4 is required only if the MCP endpoint uses AWS IAM authentication.

## Proof Header Limitation

Different destination platforms expose the observed client IP differently.

In Azure App Service, this proof endpoint uses the `client-ip` header first because App Service sets that header to the client IP observed by the destination front end. The `x-forwarded-for` header can contain multiple hops and should be interpreted carefully.

For AWS:

- ALB commonly records client IP in `X-Forwarded-For` and ALB access logs.
- API Gateway can log `$context.identity.sourceIp`.
- CloudFront and WAF should be checked through their logs.
- Application servers should only trust forwarding headers from known ingress proxies.

## Operational Limitations

- NAT Gateway and static public IPs incur Azure cost while deployed.
- The Power Platform environment must be eligible for virtual network support.
- The Azure subscription and Power Platform environment must be in the appropriate tenant/geography alignment required by Power Platform virtual network support.
- DLP policies, connector policies, or tenant restrictions can still block connector creation or execution.
- Destination-side authentication is still required. IP allowlisting is not a replacement for OAuth, API keys, mTLS, or another application authentication control.