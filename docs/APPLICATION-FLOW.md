# Application Flow

## Runtime Flow

```mermaid
sequenceDiagram
    participant User as Maker / Flow Trigger
    participant PP as Power Platform Environment
    participant CC as Custom Connector
    participant EP as Enterprise Policy
    participant Subnet as Delegated Subnet
    participant NAT as Azure NAT Gateway
    participant MCP as AWS MCP Endpoint
    participant Probe as Inspection/Probe Tool

    User->>PP: Trigger app or flow action
    PP->>CC: Invoke custom connector operation
    CC->>EP: Resolve VNet support policy
    EP->>Subnet: Execute connector from delegated subnet
    Subnet->>NAT: Send internet-bound HTTPS traffic
    NAT->>MCP: Source NAT to static public IP
    MCP-->>CC: Return MCP response
    CC-->>PP: Return connector result
    PP-->>User: Display or process result

    CC->>Probe: Optional diagnostic request
    Probe-->>CC: Echo observed source IP and headers
```

## Regional Proxy Flow

```mermaid
sequenceDiagram
  participant User as Maker / Workflow Trigger
  participant App as Power Automate or Logic App
  participant Proxy as Regional Container Apps Proxy
  participant NAT as Regional Azure NAT Gateway
  participant Echo as ipify / AWS checkip / AWS MCP

  User->>App: Trigger app, flow, or workflow
  App->>Proxy: Call approved regional proxy endpoint
  Proxy->>NAT: Outbound HTTPS from proxy subnet
  NAT->>Echo: Source NAT to regional static public IP
  Echo-->>Proxy: Return observed source IP or MCP response
  Proxy-->>App: Return proxy proof / MCP result
  App-->>User: Display or store result
```

The proxy flow is the enforceable AWS-facing pattern. Power Automate and Logic Apps do not call AWS or public echo services directly; they call the regional proxy, and the proxy owns outbound egress.

## Proof Flow

```mermaid
flowchart TD
    Start[Open custom connector Test tab]
    Conn[Select or create connection]
    Run[Run InspectSourceIp operation]
    PP[Power Platform executes connector]
    VNet[Delegated subnet path]
    Nat[NAT Gateway SNAT]
    Endpoint[Inspection endpoint receives request]
    Check{Observed source IP equals NAT public IP?}
    Pass[Proof succeeded]
    Fail[Investigate connector path, subnet injection, or downstream allowlist]

    Start --> Conn --> Run --> PP --> VNet --> Nat --> Endpoint --> Check
    Check -->|Yes| Pass
    Check -->|No| Fail
```

## Failure Signals

| Symptom | Likely cause | What to check |
| --- | --- | --- |
| 503 with `Container allocated` | Power Platform delegated connector container is warming up | Wait for the `retry-after` value and retry |
| No request in destination logs | Connector did not reach the endpoint | Check connector URL, connection, DLP policy, and Power Platform test response |
| Destination sees Power Automate service IP | Wrong workload path | Use VNet-supported custom connector or Dataverse plug-in instead of built-in HTTP |
| AWS returns 403 | AWS allowlist/auth blocked the call | Check AWS WAF/IP set/security group/API Gateway resource policy and connector authentication |
| AWS timeout | Network path or endpoint unreachable | Confirm public DNS, TLS certificate, route, listener, and inbound 443 rules |
| Proxy proof returns non-NAT IP | Proxy subnet or NAT association is wrong | Check Container Apps environment subnet delegation and NAT Gateway association |
| Direct flow still reaches AWS | Bypass path is still allowed | Block direct HTTP/unapproved connectors and enforce AWS allowlist for proxy NAT IPs only |

## Confirmed Demo Flow

```text
NAT Proof Inspector custom connector
  -> Power Platform environment <power-platform-environment-id>
  -> North Europe delegated connector runtime
  -> NAT Gateway public IP <north-region-nat-ip>
  -> France Central inspection endpoint
```

```text
North Europe Logic App example
  -> North Europe Container Apps proxy
  -> NAT Gateway public IP <north-region-nat-ip>
  -> api.ipify.org and checkip.amazonaws.com
```

```text
West Europe Logic App example
  -> West Europe Container Apps proxy
  -> NAT Gateway public IP <west-region-nat-ip>
  -> api.ipify.org and checkip.amazonaws.com
```