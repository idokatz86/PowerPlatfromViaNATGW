targetScope = 'resourceGroup'

@description('Resource name prefix. Keep it short because several Azure resource names include it.')
param namePrefix string = 'ppnatgw'

@description('Primary Azure region for the Europe Power Platform geography.')
param primaryLocation string = 'westeurope'

@description('Secondary Azure region for the Europe Power Platform geography.')
param secondaryLocation string = 'northeurope'

@description('Address space for the primary virtual network.')
param primaryVnetAddressPrefix string = '10.42.0.0/16'

@description('Delegated subnet prefix in the primary virtual network.')
param primarySubnetPrefix string = '10.42.1.0/24'

@description('Address space for the secondary virtual network.')
param secondaryVnetAddressPrefix string = '10.43.0.0/16'

@description('Delegated subnet prefix in the secondary virtual network.')
param secondarySubnetPrefix string = '10.43.1.0/24'

@description('Subnet name used in both virtual networks.')
param delegatedSubnetName string = 'snet-powerplatform-delegated'

var primaryVnetName = '${namePrefix}-vnet-weu'
var secondaryVnetName = '${namePrefix}-vnet-neu'
var primaryNatName = '${namePrefix}-nat-weu'
var secondaryNatName = '${namePrefix}-nat-neu'
var primaryPipName = '${namePrefix}-pip-weu'
var secondaryPipName = '${namePrefix}-pip-neu'
var primaryNsgName = '${namePrefix}-nsg-weu'
var secondaryNsgName = '${namePrefix}-nsg-neu'

resource primaryPublicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: primaryPipName
  location: primaryLocation
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

resource secondaryPublicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: secondaryPipName
  location: secondaryLocation
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

resource primaryNat 'Microsoft.Network/natGateways@2024-05-01' = {
  name: primaryNatName
  location: primaryLocation
  sku: {
    name: 'Standard'
  }
  properties: {
    idleTimeoutInMinutes: 10
    publicIpAddresses: [
      {
        id: primaryPublicIp.id
      }
    ]
  }
}

resource secondaryNat 'Microsoft.Network/natGateways@2024-05-01' = {
  name: secondaryNatName
  location: secondaryLocation
  sku: {
    name: 'Standard'
  }
  properties: {
    idleTimeoutInMinutes: 10
    publicIpAddresses: [
      {
        id: secondaryPublicIp.id
      }
    ]
  }
}

resource primaryNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: primaryNsgName
  location: primaryLocation
  properties: {
    securityRules: [
      {
        name: 'AllowHttpsOutbound'
        properties: {
          priority: 100
          direction: 'Outbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'Internet'
        }
      }
    ]
  }
}

resource secondaryNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: secondaryNsgName
  location: secondaryLocation
  properties: {
    securityRules: [
      {
        name: 'AllowHttpsOutbound'
        properties: {
          priority: 100
          direction: 'Outbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'Internet'
        }
      }
    ]
  }
}

var powerPlatformDelegation = {
  name: 'Microsoft.PowerPlatform.enterprisePolicies'
  properties: {
    serviceName: 'Microsoft.PowerPlatform/enterprisePolicies'
  }
}

resource primaryVnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: primaryVnetName
  location: primaryLocation
  properties: {
    addressSpace: {
      addressPrefixes: [
        primaryVnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: delegatedSubnetName
        properties: {
          addressPrefix: primarySubnetPrefix
          delegations: [
            powerPlatformDelegation
          ]
          natGateway: {
            id: primaryNat.id
          }
          networkSecurityGroup: {
            id: primaryNsg.id
          }
        }
      }
    ]
  }
}

resource secondaryVnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: secondaryVnetName
  location: secondaryLocation
  properties: {
    addressSpace: {
      addressPrefixes: [
        secondaryVnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: delegatedSubnetName
        properties: {
          addressPrefix: secondarySubnetPrefix
          delegations: [
            powerPlatformDelegation
          ]
          natGateway: {
            id: secondaryNat.id
          }
          networkSecurityGroup: {
            id: secondaryNsg.id
          }
        }
      }
    ]
  }
}

resource primaryToSecondaryPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-05-01' = {
  parent: primaryVnet
  name: 'to-${secondaryVnet.name}'
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: secondaryVnet.id
    }
  }
}

resource secondaryToPrimaryPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-05-01' = {
  parent: secondaryVnet
  name: 'to-${primaryVnet.name}'
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: primaryVnet.id
    }
  }
}

output primaryVnetId string = primaryVnet.id
output secondaryVnetId string = secondaryVnet.id
output delegatedSubnetName string = delegatedSubnetName
output primaryNatGatewayId string = primaryNat.id
output secondaryNatGatewayId string = secondaryNat.id
output primaryNatPublicIp string = primaryPublicIp.properties.ipAddress
output secondaryNatPublicIp string = secondaryPublicIp.properties.ipAddress
