# Architecture Design

## Logical Architecture

```mermaid
flowchart LR
    Maker[Power Platform maker/tester]
    Env[Power Platform Environment\nf021725d-8eeb-e31b-9427-7334c58a3a5b]
    Connector[NAT Proof Inspector\nCustom Connector]
    Policy[Power Platform Enterprise Policy\nppnatgw-europe-policy]

    subgraph AzureSub[Azure subscription 3cce1c0d-4798-48da-92cd-daaf643e932c]
        subgraph WEU[West Europe]
            VNetWEU[ppnatgw-vnet-weu]
            SubnetWEU[snet-powerplatform-delegated\nMicrosoft.PowerPlatform/enterprisePolicies]
            NatWEU[ppnatgw-nat-weu]
            PipWEU[Public IP\n51.124.38.135]
            VNetWEU --> SubnetWEU --> NatWEU --> PipWEU
        end

        subgraph NEU[North Europe]
            VNetNEU[ppnatgw-vnet-neu]
            SubnetNEU[snet-powerplatform-delegated\nMicrosoft.PowerPlatform/enterprisePolicies]
            NatNEU[ppnatgw-nat-neu]
            PipNEU[Public IP\n20.166.89.8]
            VNetNEU --> SubnetNEU --> NatNEU --> PipNEU
        end

        Inspect[Inspection Web App\nFrance Central\nppnatgw-inspect-frc-06311682]
    end

    AwsMcp[AWS-hosted MCP endpoint\nCustomer workload]

    Maker --> Env --> Connector
    Env --> Policy
    Policy --> SubnetWEU
    Policy --> SubnetNEU
    PipWEU -. outbound allowlist .-> AwsMcp
    PipNEU -. outbound allowlist .-> AwsMcp
    PipNEU --> Inspect
```

## Key Design Choices

| Decision | Reason |
| --- | --- |
| Two delegated subnets | Power Platform Europe maps to paired Azure regions. The enterprise policy references both subnets. |
| NAT Gateway per delegated subnet | Keeps egress deterministic for either regional runtime path. |
| Standard static public IPs | Provides stable IPs that downstream services, including AWS, can allowlist. |
| External inspection endpoint | Proves the source IP from the destination side rather than relying on Azure configuration alone. |
| Custom connector proof path | VNet-supported connector execution is the relevant path; built-in HTTP actions are ambiguous. |

## Proven Path

The current proven call executed from the North Europe Power Platform runtime path:

```text
Power Platform custom connector
  -> North Europe delegated subnet
  -> ppnatgw-nat-neu
  -> 20.166.89.8
  -> France Central inspection endpoint
```

The destination observed `20.166.89.8` and the request included `x-ms-subnet-delegation-enabled: true`.

## Pending Path

The West Europe NAT Gateway is deployed and bound by the enterprise policy, but it has not yet been observed by the destination endpoint:

```text
Expected West Europe destination-observed IP: 51.124.38.135
```

That proof requires a Power Platform execution path that runs from the West Europe paired runtime.