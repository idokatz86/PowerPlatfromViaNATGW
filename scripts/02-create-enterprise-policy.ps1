param(
    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $true)]
    [string]$TenantId,

    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [string]$PolicyName,

    [Parameter(Mandatory = $true)]
    [string]$PolicyLocation,

    [string]$NetworkOutputsPath = ".azure/network-outputs.json"
)

$ErrorActionPreference = "Stop"

if (-not (Get-Module -ListAvailable -Name Microsoft.PowerPlatform.EnterprisePolicies)) {
    Install-Module Microsoft.PowerPlatform.EnterprisePolicies -Scope CurrentUser -Force
}

Import-Module Microsoft.PowerPlatform.EnterprisePolicies

$outputs = Get-Content $NetworkOutputsPath -Raw | ConvertFrom-Json
$primaryVnetId = $outputs.primaryVnetId.value
$secondaryVnetId = $outputs.secondaryVnetId.value
$subnetName = $outputs.delegatedSubnetName.value

$policy = New-SubnetInjectionEnterprisePolicy `
    -SubscriptionId $SubscriptionId `
    -ResourceGroupName $ResourceGroupName `
    -PolicyName $PolicyName `
    -PolicyLocation $PolicyLocation `
    -VirtualNetworkId $primaryVnetId `
    -SubnetName $subnetName `
    -VirtualNetworkId2 $secondaryVnetId `
    -SubnetName2 $subnetName `
    -TenantId $TenantId `
    -AzureEnvironment AzureCloud `
    -ForceAuth

$policyArmId = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.PowerPlatform/enterprisePolicies/$PolicyName"
@{
    policyArmId = $policyArmId
    policyName = $PolicyName
    policyLocation = $PolicyLocation
    primaryVnetId = $primaryVnetId
    secondaryVnetId = $secondaryVnetId
    subnetName = $subnetName
    createdAt = (Get-Date).ToString("o")
} | ConvertTo-Json | Set-Content .azure/enterprise-policy.json

$policy
Write-Host "Enterprise policy ARM ID: $policyArmId"
