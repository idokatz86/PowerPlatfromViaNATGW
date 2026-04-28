# Power Platform Admin Handoff

The Azure networking, Power Platform enterprise policy, and subnet injection binding for this proof are already deployed in the M365x06311682 tenant.

## Request For Tenant Admin

The active Power Platform environment is:

| Setting | Value |
| --- | --- |
| Environment ID | `f021725d-8eeb-e31b-9427-7334c58a3a5b` |
| Environment URL | `https://orgdb8a7af5.crm4.dynamics.com/` |
| Type | `Sandbox` |
| Environment group | `Fnx-mng` |

If this environment must be recreated, use these settings:

| Setting | Value |
| --- | --- |
| Environment name | `PowerPlatformViaNATGW` |
| Type | `Sandbox` |
| Geography / region | `Europe` |
| Dataverse database | `Yes` |
| Currency | `EUR` |
| Language | `English` |
| Security group | Blank / unrestricted for proof |
| Dynamics 365 apps | `No` |
| Sample apps and data | `No` |
| Managed Environment | Enabled |
| Protection / governance level | `Standard` |

Subnet injection has already been enabled for the active environment.

## Existing Azure Resources

Subscription:

```text
3cce1c0d-4798-48da-92cd-daaf643e932c
```

Resource group:

```text
rg-ppnatgw-demo
```

Enterprise policy ARM ID:

```text
/subscriptions/3cce1c0d-4798-48da-92cd-daaf643e932c/resourceGroups/rg-ppnatgw-demo/providers/Microsoft.PowerPlatform/enterprisePolicies/ppnatgw-europe-policy
```

NAT Gateway public IPs:

| Region | Public IP |
| --- | --- |
| West Europe | `51.124.38.135` |
| North Europe | `20.166.89.8` |

## Resume Command

The subnet injection binding has already succeeded. If it needs to be rerun, use:

```powershell
./scripts/04-enable-subnet-injection.ps1 -EnvironmentId 'f021725d-8eeb-e31b-9427-7334c58a3a5b'
```

Then continue with the proof workload and screenshot guide in [PROOF-GUIDE.md](PROOF-GUIDE.md).