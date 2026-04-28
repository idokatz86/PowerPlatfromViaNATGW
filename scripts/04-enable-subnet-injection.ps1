param(
    [Parameter(Mandatory = $true)]
    [string]$EnvironmentId,

    [string]$EnterprisePolicyPath = ".azure/enterprise-policy.json"
)

$ErrorActionPreference = "Stop"

if (-not (Get-Module -ListAvailable -Name Microsoft.PowerPlatform.EnterprisePolicies)) {
    Install-Module Microsoft.PowerPlatform.EnterprisePolicies -Scope CurrentUser -Force
}

Import-Module Microsoft.PowerPlatform.EnterprisePolicies

$policy = Get-Content $EnterprisePolicyPath -Raw | ConvertFrom-Json

Enable-SubnetInjection `
    -EnvironmentId $EnvironmentId `
    -PolicyArmId $policy.policyArmId `
    -ForceAuth

@{
    environmentId = $EnvironmentId
    policyArmId = $policy.policyArmId
    enabledAt = (Get-Date).ToString("o")
} | ConvertTo-Json | Set-Content .azure/subnet-injection-enabled.json

Write-Host "Subnet injection enabled for environment $EnvironmentId"
