# Power Platform Admin Handoff

The Azure networking, Power Platform enterprise policy, and subnet injection binding for this proof are already deployed in the <tenant-display-name> tenant.

## Request For Tenant Admin

The active Power Platform environment is:

| Setting | Value |
| --- | --- |
| Environment ID | `<power-platform-environment-id>` |
| Environment URL | `https://<power-platform-environment-url>/` |
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
<azure-subscription-id>
```

Resource group:

```text
<resource-group-name>
```

Enterprise policy ARM ID:

```text
/subscriptions/<azure-subscription-id>/resourceGroups/<resource-group-name>/providers/Microsoft.PowerPlatform/enterprisePolicies/<enterprise-policy-name>
```

NAT Gateway public IPs:

| Region | Public IP |
| --- | --- |
| West Europe | `<west-region-nat-ip>` |
| North Europe | `<north-region-nat-ip>` |

## Resume Command

The subnet injection binding has already succeeded. If it needs to be rerun, use:

```powershell
./scripts/04-enable-subnet-injection.ps1 -EnvironmentId '<power-platform-environment-id>'
```

Then continue with the proof workload and screenshot guide in [PROOF-GUIDE.md](PROOF-GUIDE.md).