# Custom Connector NAT Proof

Use this proof path to avoid the built-in Power Automate HTTP action. The custom connector is a VNet-supported connector type, so calls from the VNet-enabled environment should use the delegated subnet path.

## Target Environment

| Item | Value |
| --- | --- |
| Environment ID | `f021725d-8eeb-e31b-9427-7334c58a3a5b` |
| Environment URL | `https://orgdb8a7af5.crm4.dynamics.com/` |
| Enterprise policy | `ppnatgw-europe-policy` |
| Subnet injection | Enabled |

## Inspection Endpoint

| Item | Value |
| --- | --- |
| Resource group | `rg-ppnatgw-inspection` |
| Region | `francecentral` |
| Web App | `ppnatgw-inspect-frc-06311682` |
| URL | `https://ppnatgw-inspect-frc-06311682.azurewebsites.net/inspect` |

Smoke test from a local machine:

```bash
curl -sS 'https://ppnatgw-inspect-frc-06311682.azurewebsites.net/inspect?run=local-smoke' | jq
```

The local smoke test only proves the endpoint is working. It is not the NAT proof.

## Import The Custom Connector

1. Open the target Power Platform environment.
2. Go to **Custom connectors**.
3. Create a new connector by importing an OpenAPI file.
4. Import [connectors/nat-proof-connector.swagger.json](../connectors/nat-proof-connector.swagger.json).
5. Use **No authentication** for the connector.
6. Create the connector.
7. Test operation `InspectSourceIp` with a unique run ID.

Recommended run IDs:

```text
weu-001
neu-001
```

## Required Evidence

Capture the connector test response body and the inspection Web App logs for each run.

A valid West Europe proof must show:

```text
observedClientIp = 51.124.38.135
```

A valid North Europe proof must show:

```text
observedClientIp = 20.166.89.8
```

A single call only proves the regional runtime that served that call. To claim both NAT Gateways are proven, capture two separate evidence rows: one matching `51.124.38.135` and one matching `20.166.89.8`.

## View Destination Logs

From the repository root:

```bash
./scripts/06-tail-inspection-logs.sh
```

The log line is JSON and includes `timestamp`, `observedClientIp`, `rawObservedClientIp`, `xForwardedFor`, and the `run` query value in `path`.

## Important Limitation

Power Platform chooses the regional runtime path. The enterprise policy is configured with both Europe paired-region delegated subnets, but a normal connector test may only execute from one runtime region. If repeated tests only show one NAT IP, that is a truthful proof for that active runtime path, not proof for both regional NAT Gateways. Proving both requires a call that is actually executed from each regional Power Platform runtime path, such as a platform failover/paired-region execution event or a support-guided validation.
