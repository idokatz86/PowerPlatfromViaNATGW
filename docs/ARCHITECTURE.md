# Architecture Design

## Logical Architecture

```mermaid
flowchart LR
    Maker[Power Platform maker/tester]
    Env[Power Platform Environment\n<power-platform-environment-id>]
    Connector[NAT Proof Inspector\nCustom Connector]
    Policy[Power Platform Enterprise Policy\n<enterprise-policy-name>]

    subgraph AzureSub[Azure subscription <azure-subscription-id>]
        subgraph WEU[West Europe]
            VNetWEU[<west-region-vnet-name>]
            SubnetWEU[snet-powerplatform-delegated\nMicrosoft.PowerPlatform/enterprisePolicies]
            NatWEU[<west-region-nat-gateway-name>]
            PipWEU[Public IP\n<west-region-nat-ip>]
            VNetWEU --> SubnetWEU --> NatWEU --> PipWEU
        end

        subgraph NEU[North Europe]
            VNetNEU[<north-region-vnet-name>]
            SubnetNEU[snet-powerplatform-delegated\nMicrosoft.PowerPlatform/enterprisePolicies]
            NatNEU[<north-region-nat-gateway-name>]
            PipNEU[Public IP\n<north-region-nat-ip>]
            VNetNEU --> SubnetNEU --> NatNEU --> PipNEU
        end

        Inspect[Inspection Web App\nSeparate validation region\n<inspection-web-app-name>]
        ProxyNEU[Container Apps Proxy\nNorth Europe\n<north-region-nat-ip>]
        ProxyWEU[Container Apps Proxy\nWest Europe\n<west-region-nat-ip>]
    end

    AwsMcp[AWS-hosted MCP endpoint\nCustomer workload]

    Maker --> Env --> Connector
    Env --> Policy
    Policy --> SubnetWEU
    Policy --> SubnetNEU
    PipWEU -. outbound allowlist .-> AwsMcp
    PipNEU -. outbound allowlist .-> AwsMcp
    PipNEU --> Inspect
    Env -. approved proxy connector .-> ProxyNEU
    Env -. approved proxy connector .-> ProxyWEU
    ProxyNEU --> AwsMcp
    ProxyWEU --> AwsMcp
```

## Key Design Choices

| Decision | Reason |
| --- | --- |
| Two delegated subnets | Power Platform Europe maps to paired Azure regions. The enterprise policy references both subnets. |
| NAT Gateway per delegated subnet | Keeps egress deterministic for either regional runtime path. |
| Standard static public IPs | Provides stable IPs that downstream services, including AWS, can allowlist. |
| External inspection endpoint | Proves the source IP from the destination side rather than relying on Azure configuration alone. |
| Custom connector proof path | VNet-supported connector execution is the relevant path; built-in HTTP actions are ambiguous. |
| Customer-controlled proxy path | Provides an enforceable AWS-facing egress point for Power Platform and Logic Apps integrations. |

## Proven Path

The current proven call executed from the North Europe Power Platform runtime path:

```text
Power Platform custom connector
  -> North Europe delegated subnet
  -> <north-region-nat-gateway-name>
  -> <north-region-nat-ip>
  -> France Central inspection endpoint
```

The destination observed `<north-region-nat-ip>` and the request included `x-ms-subnet-delegation-enabled: true`.

## Validated Regional Proxy Path

The customer-controlled proxy pattern is proven in both regional VNets:

```text
Power Platform or Logic App
    -> regional proxy endpoint
    -> Container Apps subnet in regional VNet
    -> regional NAT Gateway public IP
    -> api.ipify.org / checkip.amazonaws.com / AWS MCP
```

| Region | Proxy endpoint | Destination-observed IP |
| --- | --- | --- |
| North Europe | `https://<north-region-proxy-host>` | `<north-region-nat-ip>` |
| West Europe | `https://<west-region-proxy-host>` | `<west-region-nat-ip>` |