param(
    [string]$SubscriptionId = "152f2bd5-8f6b-48ba-a702-21a23172a224",
    [string]$TenantId = "16b3c013-d300-468d-ac64-7eda0820b6d3",
    [string]$ResourceGroupName = "rg-ppnatgw-demo",
    [string]$PolicyName = "ppnatgw-europe-policy",
    [string]$PolicyLocation = "europe",
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
